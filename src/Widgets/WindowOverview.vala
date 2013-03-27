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
	
	public class WindowOverview : Actor
	{
		Plugin plugin;
		Screen screen;
		
		bool ready;
		
		//the workspaces which we expose right now
		List<Workspace> workspaces;
		
		static const int PADDING = 50;
		
		public WindowOverview (Plugin _plugin)
		{
			plugin = _plugin;
			screen = plugin.get_screen ();
			
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
		
		/**
		 * Code ported from KWin present windows effect
		 * https://projects.kde.org/projects/kde/kde-workspace/repository/revisions/master/entry/kwin/effects/presentwindows/presentwindows.cpp
		 **/
		
		//constants, mainly for natural expo
		const int GAPS = 10;
		const int MAX_TRANSLATIONS = 100000;
		const int ACCURACY = 20;
		const int BORDER = 10;
		const int TOP_GAP = 20;
		const int BOTTOM_GAP = 100;
		
		//some math utilities
		int squared_distance (Gdk.Point a, Gdk.Point b)
		{
			var k1 = b.x - a.x;
			var k2 = b.y - a.y;
			
			return k1*k1 + k2*k2;
		}
		
		bool rect_is_overlapping_any (Meta.Rectangle rect, Meta.Rectangle[] rects, Meta.Rectangle border)
		{
			if (!border.contains_rect (rect))
				return true;
			foreach (var comp in rects) {
				if (comp == rect)
					continue;
				
				if (rect.overlap (comp))
					return true;
			}
			
			return false;
		}
		
		Meta.Rectangle rect_adjusted (Meta.Rectangle rect, int dx1, int dy1, int dx2, int dy2)
		{
			return {rect.x + dx1, rect.y + dy1, rect.width + (-dx1 + dx2), rect.height + (-dy1 + dy2)};
		}
		
		Gdk.Point rect_center (Meta.Rectangle rect)
		{
			return {rect.x + rect.width / 2, rect.y + rect.height / 2};
		}
		
		
		void calculate_places (List<Actor> windows)
		{
			var clones = windows.copy ();
			clones.sort ((a, b) => {
				return (int)(a as WindowThumb).window.get_stable_sequence () - 
				        (int)(b as WindowThumb).window.get_stable_sequence ();
			});
			
			//sort windows by monitor
			List<Actor>[] monitors = {};
			monitors.resize (screen.get_n_monitors ());
			
			foreach (var clone in clones) {
				// we had some crashes here so there's a reasonable suspicion
				// that get_monitor() could be larger than get_n_monitors()
				var index = (clone as WindowThumb).window.get_monitor ();
				if (index >= screen.get_n_monitors ()) {
					critical ("Window '%s' has a monitor assigned that does not actually exists", 
						(clone as WindowThumb).window.get_title ());
					index = screen.get_n_monitors () - 1;
				}
				monitors[index].append (clone);
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
				
				if (BehaviorSettings.get_default ().schema.get_enum ("window-overview-type") == WindowOverviewType.GRID)
					grid_placement (area, monitors[i]);
				else
					natural_placement (area, monitors[i]);
			}
		}
		
		void grid_placement (Meta.Rectangle area, List<Actor> clones)
		{
			int columns = (int)Math.ceil (Math.sqrt (clones.length ()));
			int rows = (int)Math.ceil (clones.length () / (double)columns);
			
			// Assign slots
			int slot_width = area.width / columns;
			int slot_height = area.height / rows;
			
			WindowThumb[] taken_slots = {};
			taken_slots.resize (rows * columns);
			
			// precalculate all slot centers
			Gdk.Point[] slot_centers = {};
			slot_centers.resize (rows * columns);
			for (int x = 0; x < columns; x++) {
				for (int y = 0; y < rows; y++) {
					slot_centers[x + y * columns] = {area.x + slot_width  * x + slot_width  / 2,
					                                 area.y + slot_height * y + slot_height / 2};
				}
			}
			
			// Assign each window to the closest available slot
			var tmplist = clones.copy ();
			var window_count = tmplist.length ();
			while (tmplist.length () > 0) {
				var window = tmplist.nth_data (0) as WindowThumb;
				var rect = window.window.get_outer_rect ();
				
				var slot_candidate = -1;
				var slot_candidate_distance = int.MAX;
				var pos = rect_center (rect);
				
				// all slots
				for (int i = 0; i < columns * rows; i++) {
					if (i > window_count - 1)
						break;
					
					var dist = squared_distance (pos, slot_centers[i]);
					
					if (dist < slot_candidate_distance) {
						// window is interested in this slot
						WindowThumb occupier = taken_slots[i];
						if (occupier == window)
							continue;
						
						if (occupier == null || dist < squared_distance (rect_center (occupier.window.get_outer_rect ()), slot_centers[i])) {
							// either nobody lives here, or we're better - takeover the slot if it's our best
							slot_candidate = i;
							slot_candidate_distance = dist;
						}
					}
				}
				
				if (slot_candidate == -1)
					continue;
				
				if (taken_slots[slot_candidate] != null)
					tmplist.prepend (taken_slots[slot_candidate]);
				
				tmplist.remove_all (window);
				taken_slots[slot_candidate] = window;
			}
			
			//see how many windows we have on the last row
			int left_over = (int)clones.length () - columns * (rows - 1);
			
			for (int slot = 0; slot < columns * rows; slot++) {
				var window = taken_slots[slot];
				// some slots might be empty
				if (window == null)
					continue;
				
				var rect = window.window.get_outer_rect ();
				
				// Work out where the slot is
				Meta.Rectangle target = {area.x + (slot % columns) * slot_width,
				                         area.y + (slot / columns) * slot_height,
				                         slot_width, 
				                         slot_height};
				target = rect_adjusted (target, 10, 10, -10, -10);
				
				float scale;
				if (target.width / (double)rect.width < target.height / (double)rect.height) {
					// Center vertically
					scale = target.width / (float)rect.width;
					target.y += (target.height - (int)(rect.height * scale)) / 2;
					target.height = (int)Math.floorf (rect.height * scale);
				} else {
					// Center horizontally
					scale = target.height / (float)window.height;
					target.x += (target.width - (int)(rect.width * scale)) / 2;
					target.width = (int)Math.floorf (rect.width * scale);
				}
				
				// Don't scale the windows too much
				if (scale > 1.0) {
					scale = 1.0f;
					target = {rect_center (target).x - (int)Math.floorf (rect.width * scale) / 2,
					          rect_center (target).y - (int)Math.floorf (rect.height * scale) / 2,
					          (int)Math.floorf (scale * rect.width), 
					          (int)Math.floorf (scale * rect.height)};
				}
				
				//put the last row in the center, if necessary
				if (left_over != columns && slot >= columns * (rows - 1))
					target.x += (columns - left_over) * slot_width / 2;
				
				place_window (window, target);
			}
		}
		
		void natural_placement (Meta.Rectangle area, List<Actor> clones)
		{
			Meta.Rectangle bounds = {area.x, area.y, area.width, area.height};
			
			var direction = 0;
			int[] directions = new int[clones.length ()];
			Meta.Rectangle[] rects = new Meta.Rectangle[clones.length ()];
			
			for (int i = 0; i < clones.length (); i++) {
				// save rectangles into 4-dimensional arrays representing two corners of the rectangular: [left_x, top_y, right_x, bottom_y]
				var rect = (clones.nth_data (i) as WindowThumb).window.get_outer_rect ();
				rect = rect_adjusted(rect, -GAPS, -GAPS, GAPS, GAPS);
				rects[i] = rect;
				bounds = bounds.union (rect);
				
				// This is used when the window is on the edge of the screen to try to use as much screen real estate as possible.
				directions[i] = direction;
				direction++;
				if (direction == 4)
					direction = 0;
			}
			
			var loop_counter = 0;
			var overlap = false;
			do {
				overlap = false;
				for (var i = 0; i < rects.length; i++) {
					for (var j = 0; j < rects.length; j++) {
						if (i == j)
							continue;
						
						var rect = rects[i];
						var comp = rects[j];
						
						if (!rect.overlap (comp))
							continue;
						
						loop_counter ++;
						overlap = true;
						
						// Determine pushing direction
						Gdk.Point i_center = rect_center (rect);
						Gdk.Point j_center = rect_center (comp);
						Gdk.Point diff = {j_center.x - i_center.x, j_center.y - i_center.y};
						
						// Prevent dividing by zero and non-movement
						if (diff.x == 0 && diff.y == 0)
							diff.x = 1;
						
						// Approximate a vector of between 10px and 20px in magnitude in the same direction
						var length = Math.sqrtf (diff.x * diff.x + diff.y * diff.y);
						diff.x = (int)Math.floorf (diff.x * ACCURACY / length);
						diff.y = (int)Math.floorf (diff.y * ACCURACY / length);
						// Move both windows apart
						rect.x += -diff.x;
						rect.y += -diff.y;
						comp.x += diff.x;
						comp.y += diff.y;
						
						// Try to keep the bounding rect the same aspect as the screen so that more
						// screen real estate is utilised. We do this by splitting the screen into nine
						// equal sections, if the window center is in any of the corner sections pull the
						// window towards the outer corner. If it is in any of the other edge sections
						// alternate between each corner on that edge. We don't want to determine it
						// randomly as it will not produce consistant locations when using the filter.
						// Only move one window so we don't cause large amounts of unnecessary zooming
						// in some situations. We need to do this even when expanding later just in case
						// all windows are the same size.
						// (We are using an old bounding rect for this, hopefully it doesn't matter)
						var x_section = (int)Math.roundf ((rect.x - bounds.x) / (bounds.width / 3.0f));
						var y_section = (int)Math.roundf ((comp.y - bounds.y) / (bounds.height / 3.0f));
						
						i_center = rect_center (rect);
						diff.x = 0;
						diff.y = 0;
						if (x_section != 1 || y_section != 1) { // Remove this if you want the center to pull as well
							if (x_section == 1)
								x_section = (directions[i] / 2 == 1 ? 2 : 0);
							if (y_section == 1)
								y_section = (directions[i] % 2 == 1 ? 2 : 0);
						}
						if (x_section == 0 && y_section == 0) {
							diff.x = bounds.x - i_center.x;
							diff.y = bounds.y - i_center.y;
						}
						if (x_section == 2 && y_section == 0) {
							diff.x = bounds.x + bounds.width - i_center.x;
							diff.y = bounds.y - i_center.y;
						}
						if (x_section == 2 && y_section == 2) {
							diff.x = bounds.x + bounds.width - i_center.x;
							diff.y = bounds.y + bounds.height - i_center.y;
						}
						if (x_section == 0 && y_section == 2) {
							diff.x = bounds.x - i_center.x;
							diff.y = bounds.y + bounds.height - i_center.y;
						}
						if (diff.x != 0 || diff.y != 0) {
							length = Math.sqrtf (diff.x * diff.x + diff.y * diff.y);
							diff.x *= (int)Math.floorf (ACCURACY / length / 2.0f);
							diff.y *= (int)Math.floorf (ACCURACY / length / 2.0f);
							rect.x += diff.x;
							rect.y += diff.y;
						}
						
						// Update bounding rect
						bounds = bounds.union(rect);
						bounds = bounds.union(comp);
						
						//we took copies from the rects from our list so we need to reassign them
						rects[i] = rect;
						rects[j] = comp;
					}
				}
			} while (overlap && loop_counter < MAX_TRANSLATIONS);
			
			// Work out scaling by getting the most top-left and most bottom-right window coords.
			float scale = Math.fminf (Math.fminf (area.width / (float)bounds.width, area.height / (float)bounds.height), 1.0f);
			
			// Make bounding rect fill the screen size for later steps
			bounds.x = (int)Math.floorf (bounds.x - (area.width - bounds.width * scale) / 2);
			bounds.y = (int)Math.floorf (bounds.y - (area.height - bounds.height * scale) / 2);
			bounds.width = (int)Math.floorf (area.width / scale);
			bounds.height = (int)Math.floorf (area.height / scale);
			
			// Move all windows back onto the screen and set their scale
			var index = 0;
			foreach (var rect in rects) {
				rect = {(int)Math.floorf ((rect.x - bounds.x) * scale + area.x),
				        (int)Math.floorf ((rect.y - bounds.y) * scale + area.y),
				        (int)Math.floorf (rect.width * scale),
				        (int)Math.floorf (rect.height * scale)};
				
				rects[index] = rect;
				index++;
			}
			
			// fill gaps by enlarging windows
			bool moved = false;
			Meta.Rectangle border = area;
			do {
				moved = false;
				
				index = 0;
				foreach (var rect in rects) {
					
					int width_diff = ACCURACY;
					int height_diff = (int)Math.floorf ((((rect.width + width_diff) - rect.height) / 
					    (float)rect.width) * rect.height);
					int x_diff = width_diff / 2;
					int y_diff = height_diff / 2;
					
					//top right
					Meta.Rectangle old = rect;
					rect = {rect.x + x_diff, rect.y - y_diff - height_diff, rect.width + width_diff, rect.height + width_diff};
					if (rect_is_overlapping_any (rect, rects, border))
						rect = old;
					else
						moved = true;
					
					//bottom right
					old = rect;
					rect = {rect.x + x_diff, rect.y + y_diff, rect.width + width_diff, rect.height + width_diff};
					if (rect_is_overlapping_any (rect, rects, border))
						rect = old;
					else
						moved = true;
					
					//bottom left
					old = rect;
					rect = {rect.x - x_diff, rect.y + y_diff, rect.width + width_diff, rect.height + width_diff};
					if (rect_is_overlapping_any (rect, rects, border))
						rect = old;
					else
						moved = true;
					
					//top left
					old = rect;
					rect = {rect.x - x_diff, rect.y - y_diff - height_diff, rect.width + width_diff, rect.height + width_diff};
					if (rect_is_overlapping_any (rect, rects, border))
						rect = old;
					else
						moved = true;
					
					rects[index] = rect;
					index++;
				}
			} while (moved);
			
			index = 0;
			foreach (var rect in rects) {
				var window = clones.nth_data (index) as WindowThumb;
				var window_rect = window.window.get_outer_rect ();
				
				rect = rect_adjusted(rect, GAPS, GAPS, -GAPS, -GAPS);
				scale = rect.width / (float)window_rect.width;
				
				if (scale > 2.0 || (scale > 1.0 && (window_rect.width > 300 || window_rect.height > 300))) {
					scale = (window_rect.width > 300 || window_rect.height > 300) ? 1.0f : 2.0f;
					rect = {rect_center (rect).x - (int)Math.floorf (window_rect.width * scale) / 2,
					        rect_center (rect).y - (int)Math.floorf (window_rect.height * scale) / 2,
					        (int)Math.floorf (window_rect.width * scale),
					        (int)Math.floorf (window_rect.height * scale)};
				}
				
				place_window (window, rect);
				index++;
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
			
			float offset_x, offset_y;
			Utils.get_window_frame_offset (clone.window, out offset_x, out offset_y, null, null);

			clone.close_button.x = rect.x - offset_x * fscale - 8;
			clone.close_button.y = rect.y - offset_y * fscale - 8;
			
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
			
#if HAS_MUTTER38
			plugin.wallpaper.
#else
			Compositor.get_background_actor_for_screen (screen).
#endif
				animate (AnimationMode.EASE_OUT_QUAD, 350, dim_factor : 0.6);
			
			// sort windows by stacking order
			var windows = screen.get_display ().sort_windows_by_stacking (used_windows);
			
			grab_key_focus ();
			
			plugin.begin_modal ();
			Utils.set_input_area (screen, InputArea.FULLSCREEN);
			
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
		
		void add_window (Window window)
		{
			if (!visible || window.get_workspace () != screen.get_active_workspace ())
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
			
			if (thumb != null)
				thumb.close_window ();
		}
		
		void thumb_closed (WindowThumb thumb)
		{
			remove_child (thumb);
			
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
					window.get_workspace ().activate (screen.get_display ().get_current_time ());
					window.activate (screen.get_display ().get_current_time ());
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
			
			ready = false;
			
			plugin.end_modal ();
			plugin.update_input_area ();
			
			foreach (var child in get_children ()) {
				var exposed = child as WindowThumb;
				exposed.close (animate);
				exposed.selected.disconnect (thumb_selected);
			}
			
#if HAS_MUTTER38
			plugin.wallpaper.
#else
			Compositor.get_background_actor_for_screen (screen).
#endif
				animate (AnimationMode.EASE_OUT_QUAD, 300, dim_factor : 1.0);
			
			if (animate) {
				Timeout.add (300, () => {
					visible = false;
					ready = true;
					
					foreach (var window in screen.get_active_workspace ().list_windows ())
						(window.get_compositor_private () as Actor).show ();
					
					return false;
				});
			} else {
				ready = true;
				visible = false;
				
				foreach (var window in screen.get_active_workspace ().list_windows ())
					(window.get_compositor_private () as Actor).show ();
			}
		}
	}
}
