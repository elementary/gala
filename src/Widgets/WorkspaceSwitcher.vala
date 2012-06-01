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

using Clutter;
using Granite.Drawing;

namespace Gala
{
	public class WorkspaceSwitcher : Group
	{
		const float HEIGHT = 150;
		const int spacing = 10;
		
		float len;
		
		Gala.Plugin plugin;
		
		CairoTexture background;
		CairoTexture current;
		
		int _workspaces = 1;
		public int workspaces {
			get { return _workspaces; }
			set {
				_workspaces = value;
				width = len * _workspaces + spacing;
			}
		}
		
		int _workspace = 0;
		public int workspace {
			get { return _workspace; }
			set {
				_workspace = value;
				current.animate (AnimationMode.EASE_OUT_QUAD, 300, x : _workspace * len + 1 + spacing);
			}
		}
		
		public WorkspaceSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			int w, h;
			plugin.screen.get_size (out w, out h);
			
			len = (float)w / h * HEIGHT;
			
			width = 100 + spacing * 2;
			height = HEIGHT + spacing * 2;
			opacity = 0;
			
			background = new CairoTexture (100, (int)HEIGHT);
			background.auto_resize = true;
			background.draw.connect (draw_background);
			
			current = new CairoTexture (100, 100);
			current.x = spacing + 1;
			current.y = spacing + 1;
			current.width = len - 1 - spacing;
			current.height = height - 1 - spacing * 2;
			current.auto_resize = true;
			current.draw.connect (draw_current);
			
			workspace = 0;
			
			add_child (background);
			add_child (current);
			
			background.add_constraint (new BindConstraint (this, BindCoordinate.WIDTH, 0));
			background.add_constraint (new BindConstraint (this, BindCoordinate.HEIGHT, 0));
		}
		
		public override bool key_release_event (KeyEvent event)
		{
			if (((event.modifier_state & ModifierType.MOD1_MASK) == 0) || 
					event.keyval == Key.Alt_L) {
				plugin.end_modal ();
				animate (AnimationMode.EASE_OUT_QUAD, 200, opacity : 0);
				
				return true;
			}
			
			return false;
		}
		
		public override bool key_press_event (KeyEvent event)
		{
			switch (event.keyval) {
				case Key.Left:
					workspace = plugin.move_workspaces (true);
					return false;
				case Key.Right:
					workspace = plugin.move_workspaces (false);
					return false;
				default:
					break;
			}
			
			return true;
		}
		
		
		bool draw_background (Cairo.Context cr)
		{
			Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, width - 1, height - 1, 10);
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 0.5);
			cr.stroke_preserve ();
			cr.set_source_rgba (1, 1, 1, 0.4);
			cr.fill ();
			
			for (var i = 0; i < workspaces; i++) {
				Utilities.cairo_rounded_rectangle (cr, i * len + 0.5 + spacing, 0.5 + spacing,
					len - 1 - spacing, height - 1 - spacing * 2, 10);
				cr.set_line_width (1);
				cr.set_source_rgba (0, 0, 0, 0.8);
				cr.stroke_preserve ();
				cr.set_source_rgba (0, 0, 0, 0.4);
				cr.fill ();
			}
			
			return true;
		}
		
		bool draw_current (Cairo.Context cr)
		{
			Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, current.width - 2, current.height - 2, 10);
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 0.9);
			cr.stroke_preserve ();
			cr.set_source_rgba (1, 1, 1, 0.9);
			cr.fill ();
			
			return true;
		}
		
		public void handle_switch_to_workspace (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			int width, height;
			screen.get_size (out width, out height);
			
			x = width / 2 - this.width / 2;
			y = height / 2 - this.height / 2;
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 100, opacity:255);
			
			bool left = (binding.get_name () == "switch-to-workspace-left");
			workspace = plugin.move_workspaces (left);
			
			plugin.begin_modal ();
			grab_key_focus ();
		}
	}
}
