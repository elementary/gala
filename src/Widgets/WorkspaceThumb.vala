//
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Meta;
using Clutter;

namespace Gala
{
	public class WorkspaceThumb : Clutter.Actor
	{
		static const int INDICATOR_BORDER = 5;
		internal static const int APP_ICON_SIZE = 32;
		static const float THUMBNAIL_HEIGHT = 80.0f;
		static const uint CLOSE_BUTTON_DELAY = 500;

		static const int PLUS_SIZE = 8;
		static const int PLUS_WIDTH = 24;
		static const int PLUS_OFFSET = 8;

		public static const string DRAG_ID = "app-icon";
		const string DROP_ACTION = "drop";

		public signal void clicked ();
		public signal void closed ();
		public signal void window_on_last ();

		public unowned Workspace? workspace { get; set; }

		unowned Screen screen;

		static Actor? plus = null;
		static Plank.Drawing.DockSurface? buffer = null;

		Gtk.StyleContext selector_style;
		Gtk.EventBox selector_style_widget;

		internal Actor wallpaper;
		Actor wallpaper_manager;
		Clutter.Actor windows;
		internal Clutter.Actor icons;
		Actor indicator;
		GtkClutter.Texture close_button;

		uint hover_timer = 0;

		public WorkspaceThumb (Workspace _workspace, Meta.BackgroundGroup _wallpaper)
		{
			workspace = _workspace;
			screen = workspace.get_screen ();

			selector_style_widget = new Gtk.EventBox ();
			selector_style_widget.show ();
			selector_style = selector_style_widget.get_style_context ();
			selector_style.add_class ("gala-workspace-selected");
			selector_style.add_provider (Utils.get_default_style (), Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);

			screen.workspace_switched.connect (handle_workspace_switched);
			screen.workspace_added.connect (workspace_added);
			screen.monitors_changed.connect (resize);

			workspace.window_added.connect (handle_window_added);
			workspace.window_removed.connect (handle_window_removed);
			screen.window_left_monitor.connect (window_left_monitor);

			reactive = true;

			indicator = new Actor ();
			indicator.height = THUMBNAIL_HEIGHT + 2 * INDICATOR_BORDER;
			indicator.opacity = 0;
			indicator.content = new Canvas ();
			(indicator.content as Canvas).draw.connect (draw_indicator);

			handle_workspace_switched (-1, screen.get_active_workspace_index (), MotionDirection.LEFT);

			wallpaper_manager = new BackgroundManager (screen);
			//FIXME apparently there are issues with scaling and animating the opacity. The wallpaper will
			//      start flickering when the opacity changes. Wrapping it in a container solves this.
			wallpaper = new Clutter.Actor ();
			wallpaper.add_child (wallpaper_manager);
			wallpaper.x = INDICATOR_BORDER;
			wallpaper.y = INDICATOR_BORDER;
			wallpaper.height = THUMBNAIL_HEIGHT;

			close_button = new GtkClutter.Texture ();
			try {
				close_button.set_from_pixbuf (Granite.Widgets.Utils.get_close_pixbuf ());
			} catch (Error e) { warning (e.message); }
			close_button.y = -close_button.height * 0.25f;
			close_button.reactive = true;
			close_button.scale_gravity = Clutter.Gravity.CENTER;
			close_button.scale_x = 0;
			close_button.scale_y = 0;

			icons = new Actor ();
			icons.layout_manager = new BoxLayout ();
			(icons.layout_manager as Clutter.BoxLayout).spacing = 6;
			icons.height = APP_ICON_SIZE;

			windows = new Actor ();
			windows.x = INDICATOR_BORDER;
			windows.y = INDICATOR_BORDER;
			windows.height = THUMBNAIL_HEIGHT;
			windows.clip_to_allocation = true;

			add_child (indicator);
			add_child (wallpaper);
			add_child (windows);
			add_child (icons);
			add_child (close_button);

			var click = new ClickAction ();
			add_action (click);
			click.clicked.connect (pressed);

			//kill the workspace
			var close_click = new ClickAction ();
			close_button.add_action (close_click);
			close_click.clicked.connect (close_workspace);

			if (plus == null) {
				plus = new Actor ();
				var canvas = new Canvas ();
				plus.content = canvas;
				canvas.draw.connect ((cr) => {
					// putting the buffer inside here is not a problem performance-wise,
					// as the method will only be called once anyway
					var buffer = new Granite.Drawing.BufferSurface (canvas.width, canvas.height);

					buffer.context.rectangle (PLUS_WIDTH / 2 - PLUS_SIZE / 2 + 0.5 + PLUS_OFFSET, 0.5 + PLUS_OFFSET, PLUS_SIZE - 1, PLUS_WIDTH - 1);
					buffer.context.rectangle (0.5 + PLUS_OFFSET, PLUS_WIDTH / 2 - PLUS_SIZE / 2 + 0.5 + PLUS_OFFSET, PLUS_WIDTH - 1, PLUS_SIZE - 1);

					buffer.context.set_source_rgb (0, 0, 0);
					buffer.context.fill_preserve ();
					buffer.exponential_blur (5);

					buffer.context.set_source_rgb (1, 1, 1);
					buffer.context.set_line_width (1);
					buffer.context.stroke_preserve ();

					buffer.context.set_source_rgb (0.8, 0.8, 0.8);
					buffer.context.fill ();

					cr.set_operator (Cairo.Operator.CLEAR);
					cr.paint ();
					cr.set_operator (Cairo.Operator.SOURCE);

					cr.set_source_surface (buffer.surface, 0, 0);
					cr.paint ();

					return false;
				});

				plus.width = PLUS_WIDTH + 2 * PLUS_OFFSET;
				plus.height = PLUS_WIDTH + 2 * PLUS_OFFSET;
				canvas.set_size ((int)plus.width, (int)plus.height);
			}

			var drop_action = new DragDropAction (DragDropActionType.DESTINATION, DRAG_ID);
			add_action_with_name (DROP_ACTION, drop_action);
			drop_action.crossed.connect (crossed);

			check_last_workspace ();

			visible = false;

			var canvas = new Canvas ();
			canvas.draw.connect (draw_background);

			content = canvas;

			resize (screen);
		}

		// everything that depends on the screen size is set here
		void resize (Meta.Screen screen)
		{
			int swidth, sheight;
			screen.get_size (out swidth, out sheight);

			// make sure we redraw the buffer
			buffer = null;

			var width = Math.floorf ((THUMBNAIL_HEIGHT / sheight) * swidth);
			indicator.width = width + 2 * INDICATOR_BORDER;
			(indicator.content as Canvas).set_size ((int)indicator.width, (int)indicator.height);

			wallpaper_manager.scale_x = width / swidth;
			wallpaper_manager.scale_y = THUMBNAIL_HEIGHT / sheight;
			wallpaper.width = width;
			windows.width = width;

			Granite.CloseButtonPosition pos;
			Granite.Widgets.Utils.get_default_close_button_position (out pos);
			float close_button_offset = close_button.width * 0.25f;
			switch (pos) {
				case Granite.CloseButtonPosition.LEFT:
					close_button.x = -close_button_offset;
					break;
				case Granite.CloseButtonPosition.RIGHT:
					close_button.x = width - close_button_offset;
					break;
			}

			plus.x = wallpaper.x + wallpaper.width / 2 - plus.width / 2;
			plus.y = wallpaper.y + wallpaper.height / 2 - plus.height / 2;

			(content as Canvas).set_size ((int)width, (int)height);
		}

		public override void paint ()
		{
			// black border
			Cogl.Path.rectangle (INDICATOR_BORDER, INDICATOR_BORDER, wallpaper.width + INDICATOR_BORDER + 1, wallpaper.height + INDICATOR_BORDER + 1);
			Cogl.set_source_color4f (0, 0, 0, 1);
			Cogl.Path.stroke ();

			base.paint ();

			// top stroke
			Cogl.Path.move_to (INDICATOR_BORDER + 1, INDICATOR_BORDER + 1);
			Cogl.Path.line_to (wallpaper.width + INDICATOR_BORDER, INDICATOR_BORDER + 1);
			Cogl.set_source_color4f (1, 1, 1, 0.3f);
			Cogl.Path.stroke ();
		}

		void crossed (bool over)
		{
			// when draggin, the leave event isn't emitted
			if (close_button.visible)
				hide_close_button ();

			// if we're the active workspace, don't show any changes
			if (indicator.opacity == 255)
				return;

			indicator.animate (AnimationMode.LINEAR, 100, opacity: over ? 200 : 0);
		}

		~WorkspaceThumb ()
		{
			screen.workspace_switched.disconnect (handle_workspace_switched);
			screen.workspace_added.disconnect (workspace_added);
			screen.monitors_changed.disconnect (resize);
			screen.window_left_monitor.disconnect (window_left_monitor);
		}

		void close_workspace (Clutter.Actor actor)
		{
			if (workspace == null)
				return;

			foreach (var window in workspace.list_windows ()) {
				if (window.window_type != WindowType.DOCK)
					window.delete (screen.get_display ().get_current_time ());
			}

			Clutter.Threads.Timeout.add (250, () => {
				//wait for confirmation dialogs to popup
				if (Utils.get_n_windows (workspace) == 0) {
					workspace.window_added.disconnect (handle_window_added);
					workspace.window_removed.disconnect (handle_window_removed);

					animate (Clutter.AnimationMode.LINEAR, 250, width : 0.0f, opacity : 0);

					closed ();
				} else
					workspace.activate (workspace.get_screen ().get_display ().get_current_time ());

				return false;
			});
		}

		bool draw_indicator (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			selector_style.render_background (cr, 0, 0, indicator.width, indicator.height);
			selector_style.render_frame (cr, 0, 0, indicator.width, indicator.height);

			return false;
		}

		bool draw_background (Cairo.Context cr)
		{
			if (buffer == null) {
				buffer = new Plank.Drawing.DockSurface ((int)width, (int)height);
				// some weird calculations are necessary here, we have to
				// subtract the delta of the wallpaper and container size to make it fit
				buffer.Context.rectangle (wallpaper.x, wallpaper.y,
					wallpaper.width - (width - wallpaper.width),
					wallpaper.height - (height - wallpaper.height) - INDICATOR_BORDER);

				buffer.Context.set_source_rgba (0, 0, 0, 1);
				buffer.Context.fill ();
				buffer.exponential_blur (5);
			}

			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			cr.set_source_surface (buffer.Internal, 0, 0);
			cr.paint ();

			return false;
		}

		void workspace_added (int index)
		{
			check_last_workspace ();
		}

		void window_left_monitor (int num, Meta.Window window)
		{
			if (window.located_on_workspace (workspace))
				handle_window_removed (window);
		}

		void update_windows ()
		{
			windows.remove_all_children ();
			if (workspace == null)
				return;

			int swidth, sheight;
			screen.get_size (out swidth, out sheight);

			// add window thumbnails
			var aspect = windows.width / swidth;

			var unordered = workspace.list_windows ();
			var list = new SList<Window> ();
			foreach (var window in unordered) {
				if (!window.minimized &&
					(window.window_type == WindowType.NORMAL ||
					window.window_type == WindowType.DIALOG ||
					window.window_type == WindowType.MODAL_DIALOG))
					list.prepend (window);
			}

			var ordered = screen.get_display ().sort_windows_by_stacking (list);
			foreach (var window in ordered) {
				var actor = window.get_compositor_private () as WindowActor;
				if (actor == null)
					continue;

				var clone = new Clone (actor.get_texture ());
				clone.width = aspect * clone.width;
				clone.height = aspect * clone.height;
				clone.x = aspect * actor.x;
				clone.y = aspect * actor.y;

				windows.add_child (clone);
			}
		}

		void update_icons ()
		{
			icons.remove_all_children ();

			if (workspace == null)
				return;

			//show each icon only once, so log the ones added
			var shown_applications = new List<Bamf.Application> ();

			workspace.list_windows ().foreach ((w) => {
				if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
					return;

				var app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)w.get_xwindow ());
				if (shown_applications.index (app) != -1)
					return;

				if (app != null)
					shown_applications.append (app);

				var icon = new AppIcon (w, app);

				icons.add_child (icon);
			});

			icons.x = Math.floorf (wallpaper.x + wallpaper.width / 2 - icons.width / 2);
			icons.y = Math.floorf (wallpaper.y + wallpaper.height - 5);
		}

		void check_last_workspace ()
		{
			if (!Prefs.get_dynamic_workspaces ())
				return;

			//last workspace, show plus button and so on
			//give the last one a different style

			var index = screen.get_workspaces ().index (workspace);
			if (index < 0) {
				closed ();
				return;
			}

			if (index == screen.n_workspaces - 1) {
				wallpaper.opacity = 127;
				if (plus.get_parent () != null)
					plus.get_parent ().remove_child (plus);
				add_child (plus);
			} else {
				wallpaper.opacity = 255;
				if (contains (plus))
					remove_child (plus);
			}
		}

		void handle_workspace_switched (int index_old, int index_new, Meta.MotionDirection direction)
		{
			if (index_old == index_new)
				return;

			if (workspace == null)
				return;

			if (workspace.index () == index_old)
				indicator.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity : 0);
			else if (workspace.index () == index_new)
				indicator.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity : 255);
		}

		void handle_window_added (Meta.Window window)
		{
			// wait till the window is ready
			if (window.get_compositor_private () == null) {
				Idle.add (() => {
					if (window.get_compositor_private () != null)
						handle_window_added (window);
					return false;
				});
				return;
			}

			if (visible) {
				update_windows ();
				update_icons ();
			}

			if (!Prefs.get_dynamic_workspaces ())
				return;

			if (workspace != null && workspace.index () == screen.n_workspaces - 1 && Utils.get_n_windows (workspace) > 0)
				window_on_last ();
		}

		void handle_window_removed (Meta.Window window)
		{
			if (visible)
				update_windows ();

			if (!Prefs.get_dynamic_workspaces ()
				|| (window.window_type != WindowType.NORMAL
				&& window.window_type != WindowType.DIALOG
				&& window.window_type != WindowType.MODAL_DIALOG)
				|| workspace == null
				|| Utils.get_n_windows (workspace) > 0
				|| workspace.index () == workspace.get_screen ().get_n_workspaces () - 1)
				return;

			// we need to wait untill the animation ended, otherwise we get trouble with focus handling
			Clutter.Threads.Timeout.add (AnimationSettings.get_default ().workspace_switch_duration + 10, () => {
				// check again, maybe something opened
				if (workspace == null || Utils.get_n_windows (workspace) > 0)
					return false;

				workspace.window_added.disconnect (handle_window_added);
				workspace.window_removed.disconnect (handle_window_removed);

				closed ();
				return false;
			});
		}

		public override void hide ()
		{
			base.hide ();

			icons.remove_all_children ();
			windows.remove_all_children ();
		}

		public override void show ()
		{
			check_last_workspace ();

			update_icons ();
			update_windows ();

			base.show ();
		}

		public void pressed (Actor actor)
		{
			if (workspace == null)
				return;

			workspace.activate (screen.get_display ().get_current_time ());

			// wait for the animation to be finished before closing, for aesthetic reasons
			Clutter.Threads.Timeout.add (AnimationSettings.get_default ().workspace_switch_duration, () => {
				clicked ();
				return false;
			});
		}

		public override bool enter_event (CrossingEvent event)
		{
			if (workspace == null)
				return true;

			if (!Prefs.get_dynamic_workspaces ())
				return false;

			if (workspace.index () == screen.n_workspaces - 1) {
				wallpaper.animate (AnimationMode.EASE_OUT_QUAD, 300, opacity : 210);
				return true;
			}

			//dont allow closing the tab if it's the last one used
			if (workspace.index () == 0 && screen.n_workspaces == 2)
				return false;

			if (hover_timer > 0)
				GLib.Source.remove (hover_timer);

			hover_timer = Clutter.Threads.Timeout.add (CLOSE_BUTTON_DELAY, () => {
				close_button.visible = true;
				close_button.animate (AnimationMode.EASE_OUT_ELASTIC, 400, scale_x : 1.0f, scale_y : 1.0f);
				return false;
			});

			return true;
		}

		internal void hide_close_button ()
		{
			close_button.animate (AnimationMode.EASE_IN_QUAD, 400, scale_x : 0.0f, scale_y : 0.0f)
				.completed.connect (() => close_button.visible = false );
		}

		public override bool leave_event (CrossingEvent event)
		{
			if (contains (event.related))
				return false;

			if (hover_timer > 0) {
				GLib.Source.remove (hover_timer);
				hover_timer = 0;
			}

			if (workspace == null)
				return false;

			if (workspace.index () == screen.n_workspaces - 1)
				wallpaper.animate (AnimationMode.EASE_OUT_QUAD, 400, opacity : 127);
			else
				hide_close_button ();

			return false;
		}
	}
}
