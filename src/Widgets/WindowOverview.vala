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

	public enum WindowOverviewType
	{
		GRID = 0,
		NATURAL
	}

	public delegate void WindowPlacer (Actor window, Meta.Rectangle rect);

	public class WindowOverview : Actor
	{
		const int BORDER = 10;
		const int TOP_GAP = 20;
		const int BOTTOM_GAP = 100;

		WindowManager wm;
		Screen screen;

		bool ready;

		//the workspaces which we expose right now
		List<Workspace> workspaces;

		static const int PADDING = 50;

		public WindowOverview (WindowManager _wm)
		{
			wm = _wm;
			screen = wm.get_screen ();

			screen.workspace_switched.connect (() => close (false));

			visible = false;
			ready = true;
			reactive = true;
		}

		public override bool key_press_event (Clutter.KeyEvent event)
		{
			//FIXME need to figure out the actual keycombo, for now leave it by 
			// default and others will close it by selecting a window!
			if (event.keyval == Clutter.Key.w || 
				event.keyval == Clutter.Key.a || 
				event.keyval == Clutter.Key.Escape) {
				close (true);

				return true;
			}

			return false;
		}

		public override void key_focus_out ()
		{
			close (false);
		}

		public override bool button_release_event (Clutter.ButtonEvent event)
		{
			if (event.button == 1)
				close (true);

			return true;
		}

		void calculate_places (List<Actor> windows)
		{
			var clones = windows.copy ();
			clones.sort ((a, b) => {
				return (int)(a as WindowThumb).window.get_stable_sequence () - 
				        (int)(b as WindowThumb).window.get_stable_sequence ();
			});

			// sort windows by monitor
			List<InternalUtils.TilableWindow?>[] monitors = {};
			monitors.resize (screen.get_n_monitors ());

			foreach (var clone in clones) {
				// we had some crashes here so there's a reasonable suspicion
				// that get_monitor() could be larger than get_n_monitors()
				var thumb = clone as WindowThumb;
				var index = thumb.window.get_monitor ();
				if (index >= screen.get_n_monitors ()) {
					critical ("Window '%s' has a monitor assigned that does not actually exists", 
						(clone as WindowThumb).window.get_title ());
					index = screen.get_n_monitors () - 1;
				}
				monitors[index].append ({ thumb.window.get_outer_rect (), thumb });
			}

			for (var i = 0; i < screen.get_n_monitors (); i++) {
				if (monitors[i].length () == 0)
					continue;

				// get the area used by the expo algorithms together
				var geom = screen.get_monitor_geometry (i);
				Meta.Rectangle area = {(int)Math.floorf (geom.x + BORDER), 
				                       (int)Math.floorf (geom.y + TOP_GAP), 
				                       (int)Math.floorf (geom.width - BORDER * 2), 
				                       (int)Math.floorf (geom.height - BOTTOM_GAP)};

				/*TODO if (BehaviorSettings.get_default ().schema.get_enum ("window-overview-type") == WindowOverviewType.GRID)
					grid_placement (area, monitors[i], place_window);
				else
					natural_placement (area, monitors[i]);*/

				var result = InternalUtils.calculate_grid_placement (area, monitors[i]);
				foreach (var window in result) {
					place_window ((WindowThumb)window.id, window.rect);
				}
			}
		}

		// animate a window to the given position
		void place_window (WindowThumb clone, Meta.Rectangle rect)
		{
			var fscale = rect.width / clone.width;

			//animate the windows and icons to the calculated positions
			clone.icon.x = rect.x + Math.floorf (clone.width * fscale / 2.0f - clone.icon.width / 2.0f);
			clone.icon.y = rect.y + Math.floorf (clone.height * fscale - 50.0f);
			clone.icon.get_parent ().set_child_above_sibling (clone.icon, null);

			float offset_x, offset_y, offset_width;
			Utils.get_window_frame_offset (clone.window, out offset_x, out offset_y, out offset_width, null);
			float button_offset = clone.close_button.width * 0.25f;

			Granite.CloseButtonPosition pos;
			Granite.Widgets.Utils.get_default_close_button_position (out pos);
			switch (pos) {
				case Granite.CloseButtonPosition.LEFT:
					clone.close_button.x = rect.x - offset_x * fscale - button_offset;
					break;
				case Granite.CloseButtonPosition.RIGHT:
					clone.close_button.x = rect.x + rect.width - offset_width * fscale - clone.close_button.width / 2;
					break;
			}
			clone.close_button.y = rect.y - offset_y * fscale - button_offset;

			clone.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 250, scale_x:fscale, scale_y:fscale, x:rect.x+0.0f, y:rect.y+0.0f)
				.completed.connect (() => ready = true );
			clone.icon.opacity = 0;
			clone.icon.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 350, scale_x:1.0f, scale_y:1.0f, opacity:255);
		}

		public void open (bool animate = true, bool all_windows = false)
		{
			if (!ready)
				return;

			if (visible) {
				close (true);
				return;
			}

			var used_windows = new SList<Window> ();

			workspaces = new List<Workspace> ();

			if (all_windows) {
				foreach (var workspace in screen.get_workspaces ())
					workspaces.append (workspace);
			} else {
				workspaces.append (screen.get_active_workspace ());
			}

			foreach (var workspace in workspaces) {
				foreach (var window in workspace.list_windows ()) {
					if (window.window_type != WindowType.NORMAL && 
						window.window_type != WindowType.DOCK && 
						window.window_type != WindowType.DIALOG || 
						window.is_attached_dialog ()) {
						(window.get_compositor_private () as Actor).hide ();
						continue;
					}
					if (window.window_type == WindowType.DOCK)
						continue;

					// skip windows that are on all workspace except we're currently
					// processing the workspace it actually belongs to
					if (window.is_on_all_workspaces () && window.get_workspace () != workspace)
						continue;

					used_windows.append (window);
				}
			}

			var n_windows = used_windows.length ();
			if (n_windows == 0)
				return;

			ready = false;

			foreach (var workspace in workspaces) {
				workspace.window_added.connect (add_window);
				workspace.window_removed.connect (remove_window);
			}

			screen.window_left_monitor.connect (window_left_monitor);

			// sort windows by stacking order
			var windows = screen.get_display ().sort_windows_by_stacking (used_windows);

			grab_key_focus ();

			wm.begin_modal ();

			visible = true;

			foreach (var window in windows) {
				var actor = window.get_compositor_private () as WindowActor;
				if (actor == null)
					return;
				actor.hide ();

				var clone = new WindowThumb (window);
				clone.x = actor.x;
				clone.y = actor.y;

				clone.selected.connect (thumb_selected);
				clone.closed.connect (thumb_closed);

				add_child (clone);
			}

			calculate_places (get_children ());
		}

		void window_left_monitor (int num, Window window)
		{
			// see if that's happened on one of our workspaces
			foreach (var workspace in workspaces) {
#if HAS_MUTTER38
				if (window.located_on_workspace (workspace)) {
#else
				if (window.get_workspace () == workspace || 
					(window.is_on_all_workspaces () && window.get_screen () == workspace.get_screen ())) {
#endif
					remove_window (window);
					return;
				}
			}
		}

		void add_window (Window window)
		{
			if (!visible || window.get_workspace () != screen.get_active_workspace ()
				|| (window.window_type != WindowType.NORMAL && window.window_type != WindowType.DIALOG))
				return;

			var actor = window.get_compositor_private () as WindowActor;
			if (actor == null) {
				//the window possibly hasn't reached the compositor yet
				Idle.add (() => {
					if (window.get_compositor_private () != null && 
						window.get_workspace () == screen.get_active_workspace ())
						add_window (window);
					return false;
				});
				return;
			}

			actor.hide ();

			var clone = new WindowThumb (window);
			clone.x = actor.x;
			clone.y = actor.y;

			clone.selected.connect (thumb_selected);
			clone.closed.connect (thumb_closed);

			add_child (clone);

			calculate_places (get_children ());
		}

		void remove_window (Window window)
		{
			WindowThumb thumb = null;
			foreach (var child in get_children ()) {
				if ((child as WindowThumb).window == window)
					thumb = child as WindowThumb;
			}

			if (thumb != null) {
				thumb_closed (thumb);
			}
		}

		void thumb_closed (WindowThumb thumb)
		{
			thumb.destroy ();

			var children = get_children ();
			if (children.length () > 0)
				calculate_places (children);
			else
				close (false);
		}

		void thumb_selected (Window window)
		{
			if (window.get_workspace () == screen.get_active_workspace ()) {
				window.activate (screen.get_display ().get_current_time ());
				close (true);
			} else {
				close (true);
				//wait for the animation to finish before switching
				Timeout.add (400, () => {
					window.get_workspace ().activate_with_focus (window, screen.get_display ().get_current_time ());
					return false;
				});
			}
		}

		void close (bool animate)
		{
			if (!visible || !ready)
				return;

			foreach (var workspace in workspaces) {
				workspace.window_added.disconnect (add_window);
				workspace.window_removed.disconnect (remove_window);
			}
			screen.window_left_monitor.disconnect (window_left_monitor);

			ready = false;

			wm.end_modal ();
			wm.update_input_area ();

			foreach (var child in get_children ()) {
				var exposed = child as WindowThumb;
				exposed.close (animate);
				exposed.selected.disconnect (thumb_selected);
			}

			if (animate) {
				Clutter.Threads.Timeout.add (300, () => {
					visible = false;
					ready = true;

					foreach (var window in screen.get_active_workspace ().list_windows ()) {
						if (window.showing_on_its_workspace ())
							(window.get_compositor_private () as Actor).show ();
					}

					return false;
				});
			} else {
				ready = true;
				visible = false;

				foreach (var window in screen.get_active_workspace ().list_windows ())
					if (window.showing_on_its_workspace ())
						(window.get_compositor_private () as Actor).show ();
			}
		}
	}
}
