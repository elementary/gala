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
			if (event.keyval == Clutter.Key.e) {
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
		 * Code borrowed from native window placement GS extension
		 * http://git.gnome.org/browse/gnome-shell-extensions/tree/extensions/native-window-placement/extension.js
		 **/
		const int GAPS = 5;
		const int MAX_TRANSLATIONS = 5000;
		const int ACCURACY = 20;
		const int BORDER = 10;
		const int TOP = 20;
		const bool use_more_screen = true;
		
		int[] rect_center (Meta.Rectangle rect)
		{
			return {rect.width / 2, rect.height / 2};
		}
		Meta.Rectangle rect_adjusted (Meta.Rectangle rect, int dx1, int dy1, int dx2, int dy2)
		{
			return {rect.x + dx1, rect.y + dy1, rect.width + (-dx1 + dx2), rect.height + (-dy1 + dy2)};
		}
		
		void calculate_places (List<Actor> windows)
		{
			var clones = windows.copy ();
			clones.sort ((a, b) => {
				return (int)(a as ExposedWindow).window.get_stable_sequence () - (int)(b as ExposedWindow).window.get_stable_sequence ();
			});
			
			//get a working area
			var monitor = screen.get_monitor_geometry (screen.get_primary_monitor ());
			var ratio = monitor.width / (float)monitor.height;
			var x_gap = Math.fmaxf (BORDER, TOP * ratio);
			var y_gap = Math.fmaxf (BORDER / ratio, TOP);
			Meta.Rectangle area = {(int)Math.floorf (monitor.x + x_gap / 2), 
			                       (int)Math.floorf (monitor.y + y_gap / 2), 
			                       (int)Math.floorf (monitor.width - x_gap), 
			                       (int)Math.floorf (monitor.height - y_gap)};
			
			//get a copy
			Meta.Rectangle bounds = {area.x, area.y, area.width, area.height};
			
			var direction = 0;
			var directions = new List<int> ();
			var rects = new List<Meta.Rectangle?> ();
			foreach (var clone in clones) {
				var rect = (clone as ExposedWindow).window.get_outer_rect ();
				rects.append (rect);
				bounds = bounds.union (rect);
				
				directions.append (direction);
				direction ++;
				if (direction  == 4)
					direction = 0;
			}
			
			int loop_counter = 0;
			bool overlap = false;
			do {
				overlap = false;
				for (var i=0;i<rects.length ();i++) {
					for (var j=0;j<rects.length ();j++) {
						if (i != j &&
							rect_adjusted (rects.nth_data (i), -GAPS, -GAPS, GAPS, GAPS).overlap (
							rect_adjusted (rects.nth_data (j), -GAPS, -GAPS, GAPS, GAPS))) {
							loop_counter ++;
							overlap = true;
							
							var i_center = rect_center (rects.nth_data (i));
							var j_center = rect_center (rects.nth_data (j));
							int[] diff = {j_center[0] - i_center[0], j_center[1] - i_center[1]};
							
							if (diff[0] == 0 && diff[1] == 0)
								diff[0] = 1;
							
							if (bounds.height / (float)bounds.width > area.height / (float)area.width)
								diff[0] *= 2;
							else
								diff[1] *= 2;
							
							var length = Math.sqrtf (diff[0] * diff[0] + diff[1] * diff[1]);
							diff[0] = (int)Math.floorf (diff[0] * ACCURACY / length);
							diff[1] = (int)Math.floorf (diff[1] * ACCURACY / length);
							
							rects.nth_data (i).x += -diff[0];
							rects.nth_data (i).y += -diff[1];
							rects.nth_data (j).x += diff[0];
							rects.nth_data (j).y += diff[1];
							
							if (use_more_screen) {
								var x_section = Math.round ((rects.nth_data (i).x - bounds.x) / (bounds.width  / 3.0f));
								var y_section = Math.round ((rects.nth_data (i).y - bounds.y) / (bounds.height / 3.0f));
								
								i_center = rect_center (rects.nth_data (i));
								diff[0] = 0;
								diff[1] = 0;
								if (x_section != 1 || y_section != 1) {
									if (x_section == 1)
										x_section = directions.nth_data (i) / 2 == 1 ? 2 : 0;
									if (y_section == 1)
										y_section = directions.nth_data (i) % 2 == 1 ? 2 : 0;
								}
								if (x_section == 0 && y_section == 0) {
									diff[0] = bounds.x - i_center[0];
									diff[1] = bounds.y - i_center[1];
								}
								if (x_section == 2 && y_section == 0) {
									diff[0] = bounds.x + bounds.width - i_center[0];
									diff[1] = bounds.y - i_center[1];
								}
								if (x_section == 2 && y_section == 2) {
									diff[0] = bounds.x + bounds.width - i_center[0];
									diff[1] = bounds.y + bounds.height - i_center[1];
								}
								if (x_section == 0 && y_section == 2) {
									diff[0] = bounds.x - i_center[0];
									diff[1] = bounds.y + bounds.height - i_center[1];
								}
								if (diff[0] != 0 || diff[1] != 0) {
									length = Math.sqrtf (diff[0] * diff[0] + diff[1] * diff[1]);
									diff[0] *= (int)Math.floorf (ACCURACY / length / 2.0f);
									diff[1] *= (int)Math.floorf (ACCURACY / length / 2.0f);
									rects.nth_data (i).x += diff[0];
									rects.nth_data (i).y += diff[1];
								}
							}
							
							bounds = bounds.union (rects.nth_data (i));
							bounds = bounds.union (rects.nth_data (j));
						}
					}
				}
			} while (overlap && loop_counter < MAX_TRANSLATIONS);
			
			var scale = Math.fminf (Math.fminf (area.width / (float)bounds.width, area.height / (float)bounds.height), 1.0f);
			bounds.x = (int)Math.floorf (bounds.x - (area.width - bounds.width * scale) / 2.0f);
			bounds.y = (int)Math.floorf (bounds.y - (area.height - bounds.height * scale) / 2.0f);
			bounds.width = (int)Math.floorf (area.width / scale);
			bounds.height = (int)Math.floorf (area.height / scale);
			
			foreach (var rect in rects) {
				rect.x += -bounds.x;
				rect.y += -bounds.y;
			}
			
			for (var i=0;i<rects.length ();i++) {
				var rect = rects.nth_data (i);
				var clone = clones.nth_data (i) as ExposedWindow;
				
				rect.x = (int)Math.floorf (rect.x * scale + area.x);
				rect.y = (int)Math.floorf (rect.y * scale + area.y);
				
				//animate the windows and icons to the calculated positions
				clone.icon.x = rect.x + Math.floorf (clone.width * scale / 2.0f - clone.icon.width / 2.0f);
				clone.icon.y = rect.x + Math.floorf (clone.height * scale - 30.0f);
				clone.icon.get_parent ().set_child_above_sibling (clone.icon, null);
				
				clone.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 250, scale_x:scale, scale_y:scale, x:rect.x+1.0f, y:rect.y+1.0f)
					.completed.connect (() => ready = true );
				clone.icon.opacity = 0;
				clone.icon.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 350, scale_x:1.0f, scale_y:1.0f, opacity:255);
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
			
			screen.get_active_workspace ().list_windows ().foreach ((w) => {
				if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
					return;
				used_windows.append (w);
			});
			
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
				
				add_child (clone);
			}
			
			calculate_places (get_children ());
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
			
			if (animate) {
				Timeout.add (250, () => {
					visible = false;
					ready = true;
					
					return false;
				});
			} else {
				ready = true;
				visible = false;
			}
		}
	}
}
