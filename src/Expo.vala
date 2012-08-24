//  
//  Copyright (C) 2012 Tom Beckmann
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
	
	public class Expo : Actor
	{
		Plugin plugin;
		Screen screen;
		
		bool ready;
		
		static const int PADDING = 50;
		
		public Expo (Plugin _plugin)
		{
			plugin = _plugin;
			screen = plugin.get_screen ();
			
			screen.workspace_switched.connect (() => close (false));
			
			visible = false;
			ready = true;
		}
		
		public override bool key_press_event (Clutter.KeyEvent event)
		{
			//FIXME need to figure out the actual keycombo, for now leave it by default and others will close it by selecting a window!
			if (event.keyval == Clutter.Key.e || event.keyval == Clutter.Key.Escape) {
				close (true);
				
				return true;
			}
			
			return false;
		}
		
		public override void key_focus_out ()
		{
			close (false);
		}
		
		/**
		 * Code taken from KWin present windows effect
		 * https://projects.kde.org/projects/kde/kde-workspace/repository/revisions/master/entry/kwin/effects/presentwindows/presentwindows.cpp
		 *
		 **/
		const int GAPS = 20;
		const int MAX_TRANSLATIONS = 100000;
		const int ACCURACY = 1;
		const int BORDER = 10;
		const int TOP_GAP = 20;
		const bool use_more_screen = false;
		
		struct Point
		{
			int x;
			int y;
		}
		
		Point rect_center (Meta.Rectangle rect)
		{
			return {rect.x + rect.width / 2, rect.y + rect.height / 2};
		}
		Meta.Rectangle rect_adjusted (Meta.Rectangle rect, int dx1, int dy1, int dx2, int dy2)
		{
			return {rect.x + dx1, rect.y + dy1, rect.width + (-dx1 + dx2), rect.height + (-dy1 + dy2)};
		}
		Meta.Rectangle rect_translate (Meta.Rectangle rect, int x, int y)
		{
			return {rect.x + x, rect.y + y, rect.width, rect.height};
		}
		float point_distance (Point a, Point b)
		{
			var k1 = b.x - a.x;
			var k2 = b.y - a.y;
			return Math.sqrtf (k1*k1 + k2*k2);
		}
		
		void calculate_places (List<Actor> windows)
		{
			var clones = windows.copy ();
			clones.sort ((a, b) => {
				return (int)(a as ExposedWindow).window.get_stable_sequence () - (int)(b as ExposedWindow).window.get_stable_sequence ();
			});
			
			// Put a gap on the right edge of the workspace to separe it from the workspace selector
			var geom = screen.get_monitor_geometry (screen.get_primary_monitor ());
			var ratio = geom.width / (float)geom.height;
			var x_gap = Math.fmaxf (BORDER, TOP_GAP * ratio);
			var y_gap = Math.fmaxf (BORDER / ratio, TOP_GAP);
			Meta.Rectangle area = {(int)Math.floorf (geom.x + x_gap / 2), 
			                       (int)Math.floorf (geom.y + TOP_GAP + y_gap), 
			                       (int)Math.floorf (geom.width - x_gap), 
			                       (int)Math.floorf (geom.height - 100 - y_gap)};
			
			if (BehaviorSettings.get_default ().schema.get_enum ("window-overview-type") == WindowOverviewType.GRID)
				grid_placement (area, clones);
			else
				natural_placement (area, clones);
		}
		
		public void place_window (ExposedWindow clone, Meta.Rectangle rect)
		{
			var fscale = rect.width / clone.width;
			
			//animate the windows and icons to the calculated positions
			clone.icon.x = rect.x + Math.floorf (clone.width * fscale / 2.0f - clone.icon.width / 2.0f);
			clone.icon.y = rect.y + Math.floorf (clone.height * fscale - 50.0f);
			clone.icon.get_parent ().set_child_above_sibling (clone.icon, null);
			
			clone.close_button.x = rect.x - 10;
			clone.close_button.y = rect.y - 10;
			
			clone.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 250, scale_x:fscale, scale_y:fscale, x:rect.x+0.0f, y:rect.y+0.0f)
				.completed.connect (() => ready = true );
			clone.icon.opacity = 0;
			clone.icon.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 350, scale_x:1.0f, scale_y:1.0f, opacity:255);
		}
		
		void grid_placement (Meta.Rectangle area, List<Actor> clones)
		{
			int columns = (int)Math.ceil (Math.sqrt (clones.length ()));
			int rows = (int)Math.ceil (clones.length () / (double)columns);
			
			// Assign slots
			int slot_width = area.width / columns;
			int slot_height = area.height / rows;
			ExposedWindow[] taken_slots = {};
			taken_slots.resize (rows * columns);
			
			// precalculate all slot centers
			Point[] slot_centers = {};
			slot_centers.resize (rows * columns);
			for (int x = 0; x < columns; x++)
				for (int y = 0; y < rows; y++) {
					slot_centers[x + y*columns] = {area.x + slot_width  * x + slot_width  / 2,
								                   area.y + slot_height * y + slot_height / 2};
				}
			
			// Assign each window to the closest available slot
			var tmplist = clones.copy (); // use a QLinkedList copy instead?
			while (tmplist.length () > 0) {
				var w = tmplist.nth_data (0) as ExposedWindow;
				var r = w.window.get_outer_rect ();
				int slot_candidate = -1;
				int slot_candidate_distance = int.MAX;
				var pos = rect_center (r);
				for (int i = 0; i < columns * rows; i++) { // all slots
					int dist = (int)point_distance (pos, slot_centers[i]);
					if (dist < slot_candidate_distance) { // window is interested in this slot
						ExposedWindow occupier = taken_slots[i];
						if (occupier == w)
							continue;
						if (occupier == null || dist < point_distance(rect_center (occupier.window.get_outer_rect ()), slot_centers[i])) {
							// either nobody lives here, or we're better - takeover the slot if it's our best
							slot_candidate = i;
							slot_candidate_distance = dist;
						}
					}
				}
				if (slot_candidate == -1)
					continue;
				
				if (taken_slots[slot_candidate] != null)
					tmplist.prepend (taken_slots[slot_candidate]); // occupier needs a new home now :p
				tmplist.remove_all(w);
				taken_slots[slot_candidate] = w; // ...and we rumble in =)
			}
			
			for (int slot = 0; slot < columns * rows; slot++) {
				ExposedWindow w = taken_slots[slot];
				if (w == null) // some slots might be empty
					continue;
				var r = w.window.get_outer_rect ();
				
				// Work out where the slot is
				Meta.Rectangle target = {area.x + (slot % columns) * slot_width,
				              area.y + (slot / columns) * slot_height,
				              slot_width, slot_height};
				target = rect_adjusted (target, 10, 10, -10, -10);   // Borders
				float scale;
				if (target.width / (double)r.width < target.height / (double)r.height) {
					// Center vertically
					scale = target.width / (float)r.width;
					target = rect_translate (target, 0, (target.y + (target.height - (int)(r.height * scale)) / 2) - target.y);
					target.height = (int)Math.floorf (r.height * scale);
				} else {
					// Center horizontally
					scale = target.height / (float)w.height;
					target = rect_translate (target, (target.x + (target.width - (int)(r.width * scale)) / 2) - target.x, 0);
					target.width = (int)Math.floorf (r.width * scale);
				}
				
				// Don't scale the windows too much
				if (scale > 2.0 || (scale > 1.0 && (r.width > 300 || r.height > 300))) {
					scale = (r.width > 300 || r.height > 300) ? 1.0f : 2.0f;
					target = {rect_center (target).x - (int)Math.floorf (r.width * scale) / 2,
					          rect_center (target).y - (int)Math.floorf (r.height * scale) / 2,
					          (int)Math.floorf (scale * r.width), 
					          (int)Math.floorf (scale * r.height)};
				}
				
				place_window (w, target);
			}
		}
		
		void natural_placement (Meta.Rectangle area, List<Actor> clones)
		{
			Meta.Rectangle bounds = {area.x, area.y, area.width, area.height};
			
			var direction = 0;
			var directions = new List<int> ();
			var rects = new List<Meta.Rectangle?> ();
			for (var i = 0; i < clones.length (); i++) {
				// save rectangles into 4-dimensional arrays representing two corners of the rectangular: [left_x, top_y, right_x, bottom_y]
				var rect = (clones.nth_data (i) as ExposedWindow).window.get_outer_rect ();
				rects.append ({rect.x, rect.y, rect.width, rect.height});
				bounds = bounds.union (rects.nth_data (i));
				
				// This is used when the window is on the edge of the screen to try to use as much screen real estate as possible.
				directions.append (direction);
				direction ++;
				if (direction == 4) {
					direction = 0;
				}
			}
			
			var loop_counter = 0;
			var overlap = false;
			do {
				overlap = false;
				for (var i = 0; i < rects.length (); i++) {
					for (var j = 0; j < rects.length (); j++) {
						if (i != j && rect_adjusted(rects.nth_data (i), -GAPS, -GAPS, GAPS, GAPS).overlap (
							rect_adjusted (rects.nth_data (j), -GAPS, -GAPS, GAPS, GAPS))) {
							loop_counter ++;
							overlap = true;
							
							// Determine pushing direction
							Point i_center = rect_center (rects.nth_data (i));
							Point j_center = rect_center (rects.nth_data (j));
							Point diff = {j_center.x - i_center.x, j_center.y - i_center.y};
							
							// Prevent dividing by zero and non-movement
							if (diff.x == 0 && diff.y == 0)
								diff.x = 1;
							// Try to keep screen/workspace aspect ratio
							if (bounds.height / bounds.width > area.height / area.width)
								diff.x *= 2;
							else
								diff.y *= 2;
							
							// Approximate a vector of between 10px and 20px in magnitude in the same direction
							var length = Math.sqrtf (diff.x * diff.x + diff.y * diff.y);
							diff.x = (int)Math.floorf (diff.x * ACCURACY / length);
							diff.y = (int)Math.floorf (diff.y * ACCURACY / length);
							
							// Move both windows apart
							rects.nth_data (i).x += -diff.x;
							rects.nth_data (i).y += -diff.y;
							rects.nth_data (j).x += diff.x;
							rects.nth_data (j).y += diff.y;
							
							if (use_more_screen) {
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
								var x_section = Math.roundf ((rects.nth_data (i).x - bounds.x) / (bounds.width / 3.0f));
								var y_section = Math.roundf ((rects.nth_data (j).y - bounds.y) / (bounds.height / 3.0f));
								
								i_center = rect_center (rects.nth_data (i));
								diff.x = 0;
								diff.y = 0;
								if (x_section != 1 || y_section != 1) { // Remove this if you want the center to pull as well
									if (x_section == 1)
										x_section = (directions.nth_data (i) / 2 == 1 ? 2 : 0);
									if (y_section == 1)
										y_section = (directions.nth_data (i) % 2 == 1 ? 2 : 0);
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
									rects.nth_data (i).x += diff.x;
									rects.nth_data (i).y += diff.y;
								}
							}
							
							// Update bounding rect
							bounds = bounds.union(rects.nth_data (i));
							bounds = bounds.union(rects.nth_data (j));
						}
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
			for (var i = 0; i < rects.length (); i++) {
				rects.nth_data (i).x += -bounds.x;
				rects.nth_data (i).y += -bounds.y;
				
				rects.nth_data (i).x = (int)Math.floorf (rects.nth_data (i).x * scale + area.x);
				rects.nth_data (i).y = (int)Math.floorf (rects.nth_data (i).y * scale + area.y);
				rects.nth_data (i).width = (int)Math.floorf (rects.nth_data (i).width * scale);
				rects.nth_data (i).height = (int)Math.floorf (rects.nth_data (i).height * scale);
				
				place_window (clones.nth_data (i) as ExposedWindow, rects.nth_data (i));
			}
		}
		
		public void open (bool animate = true)
		{
			if (!ready)
				return;
			
			if (visible) {
				close (true);
				return;
			}
			
			ready = false;
			
			var used_windows = new SList<Window> ();
			
			Compositor.get_background_actor_for_screen (screen).
				animate (AnimationMode.EASE_OUT_QUAD, 1000, dim_factor : 0.4);
			
			foreach (var window in screen.get_active_workspace ().list_windows ()) {
				if (window.window_type != WindowType.NORMAL && window.window_type != WindowType.DOCK) {
					(window.get_compositor_private () as Actor).hide ();
					continue;
				}
				if (window.window_type == WindowType.DOCK)
					continue;
				
				used_windows.append (window);
			}
			
			var n_windows = used_windows.length ();
			if (n_windows == 0)
				return;
			
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
				
				var clone = new ExposedWindow (window);
				clone.x = actor.x;
				clone.y = actor.y;
				
				clone.selected.connect (selected);
				clone.reposition.connect (reposition);
				
				add_child (clone);
			}
			
			calculate_places (get_children ());
		}
		
		void reposition (ExposedWindow removed)
		{
				var children = get_children ().copy ();
				children.remove (removed);
				calculate_places (children);
		}
		
		void selected (Window window)
		{
			window.activate (screen.get_display ().get_current_time ());
			
			close (true);
		}
		
		void close (bool animate)
		{
			if (!visible || !ready)
				return;
			
			ready = false;
			
			plugin.end_modal ();
			plugin.update_input_area ();
			
			foreach (var child in get_children ()) {
				var exposed = child as ExposedWindow;
				exposed.close (animate);
				exposed.selected.disconnect (selected);
			}
			
			Compositor.get_background_actor_for_screen (screen).
				animate (AnimationMode.EASE_OUT_QUAD, 500, dim_factor : 1.0);
			
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
