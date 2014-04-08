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

namespace Gala
{
	public class WorkspaceView : Clutter.Actor
	{
		static const float VIEW_HEIGHT = 140.0f;
		static const float SCROLL_SPEED = 30.0f;

		Gala.WindowManager wm;
		Screen screen;

		Clutter.Actor thumbnails;
		Clutter.Actor scroll;

		bool animating; // delay closing the popup

		bool wait_one_key_release; //called by shortcut, don't close it on first keyrelease
		uint last_switch_time = 0;

		Gtk.StyleContext background_style;
		Gtk.EventBox background_style_widget;

		public WorkspaceView (Gala.WindowManager _wm)
		{
			wm = _wm;
			screen = wm.get_screen ();

			height = VIEW_HEIGHT;
			reactive = true;
			clip_to_allocation = true;

			background_style_widget = new Gtk.EventBox ();
			background_style_widget.show ();
			background_style = background_style_widget.get_style_context ();
			background_style.add_class ("gala-workspaces-background");
			background_style.add_provider (Utils.get_default_style (), Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);

			thumbnails = new Clutter.Actor ();
			thumbnails.layout_manager = new Clutter.BoxLayout ();
			(thumbnails.layout_manager as Clutter.BoxLayout).spacing = 12;
			(thumbnails.layout_manager as Clutter.BoxLayout).homogeneous = true;

			content = new Clutter.Canvas ();
			(content as Clutter.Canvas).draw.connect (draw_background);

			scroll = new Clutter.Actor ();
			scroll.height = 12;
			scroll.content = new Clutter.Canvas ();
			(scroll.content as Clutter.Canvas).draw.connect (draw_scroll);

			add_child (thumbnails);
			add_child (scroll);

			//place it somewhere low, so it won't slide down on first open
			int swidth, sheight;
			screen.get_size (out swidth, out sheight);
			y = sheight;

			screen.workspace_added.connect ((index) => {
				create_workspace_thumb (screen.get_workspace_by_index (index));
			});

			Prefs.add_listener ((pref) => {
				if (pref == Preference.DYNAMIC_WORKSPACES && Prefs.get_dynamic_workspaces ()) {
					// if the last workspace has a window, we need to append a new workspace
					if (Utils.get_n_windows (screen.get_workspaces ().nth_data (screen.get_n_workspaces () - 1)) > 0)
						add_workspace ();

				} else if ((pref == Preference.DYNAMIC_WORKSPACES ||
					pref == Preference.NUM_WORKSPACES) &&
					!Prefs.get_dynamic_workspaces ()) {

					// only need to listen for the case when workspaces were removed.
					// Any other case will be caught by the workspace_added signal.
					// For some reason workspace_removed is not emitted, when changing the workspace number
					if (Prefs.get_num_workspaces () < thumbnails.get_n_children ()) {
						for (int i = Prefs.get_num_workspaces () - 1; i < thumbnails.get_n_children (); i++) {
							(thumbnails.get_child_at_index (i) as WorkspaceThumb).closed ();
						}
					}
				}
			});

			init_thumbnails ();
		}

		void init_thumbnails ()
		{
			foreach (var workspace in screen.get_workspaces ()) {
				var thumb = new WorkspaceThumb (workspace, wm.background_group);
				thumb.clicked.connect (hide);
				thumb.closed.connect (remove_workspace);
				thumb.window_on_last.connect (add_workspace);

				thumbnails.add_child (thumb);
			}

			//if there went something wrong, we need to get the system back rolling
			if (Prefs.get_dynamic_workspaces ()
				&& screen.n_workspaces == 1
				&& Utils.get_n_windows (screen.get_workspaces ().first ().data) > 0)
				add_workspace ();
		}

		bool outside_clicked (Clutter.ButtonEvent event)
		{
			hide ();
			return true;
		}

		bool draw_background (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			background_style.render_background (cr, 0, 0, width, height);
			background_style.render_frame (cr, 0, 0, width, height);

			var pat = new Cairo.Pattern.for_surface (new Cairo.ImageSurface.from_png (Config.PKGDATADIR + "/texture.png"));
			pat.set_extend (Cairo.Extend.REPEAT);
			cr.set_source (pat);
			cr.paint_with_alpha (0.6);

			return false;
		}

		bool draw_scroll (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 4, 4, scroll.width-32, 4, 2);
			cr.set_source_rgba (1, 1, 1, 0.8);
			cr.fill ();

			return false;
		}

		void add_workspace ()
		{
			var wp = screen.append_new_workspace (false, screen.get_display ().get_current_time ());
			if (wp == null)
				return;
		}

		void create_workspace_thumb (Meta.Workspace workspace)
		{
			var thumb = new WorkspaceThumb (workspace, wm.background_group);
			thumb.clicked.connect (hide);
			thumb.closed.connect (remove_workspace);
			thumb.window_on_last.connect (add_workspace);

			thumbnails.insert_child_at_index (thumb, workspace.index ());

			thumb.show ();

			check_scrollbar ();
		}

		void remove_workspace (WorkspaceThumb thumb)
		{
			//if there's only one used left, remove the second one to avoid rather confusing workspace movement
			if (thumb.workspace.index () == 0 && screen.n_workspaces == 2) {
				return;
			}

			thumb.clicked.disconnect (hide);
			thumb.closed.disconnect (remove_workspace);
			thumb.window_on_last.disconnect (add_workspace);

			var workspace = thumb.workspace;

			//dont remove non existing workspaces
			if (workspace != null && workspace.index () > -1) {
				var screen = workspace.get_screen ();
				screen.remove_workspace (workspace, screen.get_display ().get_current_time ());
			}

			thumb.workspace = null;

			thumbnails.remove_child (thumb);
			thumb.destroy ();
			check_scrollbar ();
		}

		void check_scrollbar ()
		{
			scroll.visible = thumbnails.width > width;

			if (scroll.visible) {
				if (thumbnails.x + thumbnails.width < width)
					thumbnails.x = width - thumbnails.width;
				scroll.width = width / thumbnails.width * width;
				scroll.y = height - 12;
				(scroll.content as Clutter.Canvas).set_size ((int)scroll.width, 12);
			} else {
				thumbnails.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x : width / 2 - thumbnails.width / 2);
			}
		}

		public override void key_focus_out ()
		{
			hide ();
		}

		public override bool key_press_event (Clutter.KeyEvent event)
		{
			var display = screen.get_display ();
			var current_time = display.get_current_time_roundtrip ();

			// Don't allow switching while another animation is still in progress to avoid visual disruptions
			if (current_time < (last_switch_time + AnimationSettings.get_default ().workspace_switch_duration))
				return false;

			int switch_index = -1;

			switch (event.keyval) {
				case Clutter.Key.Left:
					if ((event.modifier_state & Clutter.ModifierType.SHIFT_MASK) != 0)
						wm.move_window (display.get_focus_window (), MotionDirection.LEFT);
					else
						wm.switch_to_next_workspace (MotionDirection.LEFT);

					last_switch_time = current_time;

					return false;
				case Clutter.Key.Right:
					if ((event.modifier_state & Clutter.ModifierType.SHIFT_MASK) != 0)
						wm.move_window (display.get_focus_window (), MotionDirection.RIGHT);
					else
						wm.switch_to_next_workspace (MotionDirection.RIGHT);

					last_switch_time = current_time;

					return false;
				case Clutter.Key.@1:
					switch_index = 1;
					break;
				case Clutter.Key.@2:
					switch_index = 2;
					break;
				case Clutter.Key.@3:
					switch_index = 3;
					break;
				case Clutter.Key.@4:
					switch_index = 4;
					break;
				case Clutter.Key.@5:
					switch_index = 5;
					break;
				case Clutter.Key.@6:
					switch_index = 6;
					break;
				case Clutter.Key.@7:
					switch_index = 7;
					break;
				case Clutter.Key.@8:
					switch_index = 8;
					break;
				case Clutter.Key.@9:
					switch_index = 9;
					break;
				case Clutter.Key.@0:
					switch_index = 10;
					break;
				//we have super+s as default combination, so we allow closing by pressing s
				case Clutter.Key.s:
					hide ();
					break;
				default:
					break;
			}

			if (switch_index > 0 && switch_index <= screen.n_workspaces) {
				screen.get_workspace_by_index (switch_index - 1).activate (current_time);

				last_switch_time = current_time;
			}

			return true;
		}

		public override bool key_release_event (Clutter.KeyEvent event)
		{
			switch (event.keyval) {
			case Clutter.Key.Alt_L:
			case Clutter.Key.Alt_R:
			case Clutter.Key.Control_L:
			case Clutter.Key.Control_R:
			case Clutter.Key.Super_L:
			case Clutter.Key.Super_R:
			case Clutter.Key.Escape:
			case Clutter.Key.Return:
				if (wait_one_key_release) {
					wait_one_key_release = false;
					return false;
				}

				hide ();

				return true;
			}

			return false;
		}

		public override bool scroll_event (Clutter.ScrollEvent event)
		{
			switch (event.direction) {
			case Clutter.ScrollDirection.DOWN:
			case Clutter.ScrollDirection.RIGHT:
				if (thumbnails.width + thumbnails.x > width)
					thumbnails.x -= SCROLL_SPEED;
				break;
			case Clutter.ScrollDirection.UP:
			case Clutter.ScrollDirection.LEFT:
				if (thumbnails.x < 0)
					thumbnails.x += SCROLL_SPEED;
				break;
			default:
				return false;
			}

			scroll.x = Math.floorf (width / thumbnails.width * -thumbnails.x);

			return false;
		}

		/*
		 * if shortcut, wait one key release before closing
		 */
		public new void show (bool shortcut = false)
		{
			if (visible) {
				hide ();
				return;
			}

			wait_one_key_release = shortcut;

			var screen = wm.get_screen ();

			visible = true;
			grab_key_focus ();

			wm.begin_modal ();

			wm.ui_group.button_release_event.connect (outside_clicked);

			var area = screen.get_monitor_geometry (screen.get_primary_monitor ());
			y = area.height + area.y;
			x = area.x;
			width = area.width;
			(content as Clutter.Canvas).set_size ((int)width, (int)height);

			thumbnails.get_children ().foreach ((thumb) => {
				thumb.show ();
			});

			thumbnails.x = width / 2 - thumbnails.width / 2;
			thumbnails.y = 15;

			scroll.visible = thumbnails.width > width;
			if (scroll.visible) {
				scroll.y = height - 12;
				scroll.x = 0.0f;
				scroll.width = width / thumbnails.width * width;
				thumbnails.x = 4.0f;
			}

			int swidth, sheight;
			screen.get_size (out swidth, out sheight);

			animating = true;
			Clutter.Threads.Timeout.add (50, () => {
				animating = false;
				return false;
			}); //catch hot corner hiding problem

			var wins = Compositor.get_window_group_for_screen (screen);
			wins.detach_animation ();
			wins.x = 0.0f;

			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, y : (area.height + area.y) - height);
			wins.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, y : -height + 1.01f);
		}

		public new void hide ()
		{
			if (!visible || animating)
				return;

			wm.ui_group.button_release_event.disconnect (outside_clicked);

			float width, height;
			wm.get_screen ().get_size (out width, out height);

			wm.end_modal ();
			wm.update_input_area ();

			animating = true;
			animate (Clutter.AnimationMode.EASE_OUT_EXPO, 500, y : height).completed.connect (() => {
				thumbnails.get_children ().foreach ((thumb) => {
					thumb.hide ();
				});
				animating = false;
				visible = false;
			});

			var wins = Compositor.get_window_group_for_screen (screen);
			wins.detach_animation ();
			wins.x = 0.0f;
			wins.animate (Clutter.AnimationMode.EASE_OUT_EXPO, 500, y : 0.0f);
		}
	}
}
