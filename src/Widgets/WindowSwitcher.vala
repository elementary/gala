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
	public class WindowSwitcher : Clutter.Actor
	{
		Gala.Plugin plugin;
		
		Gee.ArrayList<Clutter.Clone> window_clones = new Gee.ArrayList<Clutter.Clone> ();
		
		Meta.Window? current_window;
		
		Meta.WindowActor? dock_window;
		Actor dock;
		CairoTexture dock_background;
		Plank.Drawing.DockSurface? dock_surface;
		Plank.Drawing.DockThemeRenderer dock_renderer;
		Plank.DockPreferences dock_settings;
		
		//FIXME window titles of supported docks, to be extended
		const string [] DOCK_NAMES = {"plank", "Docky"};
		
		public WindowSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			//pull drawing methods from libplank
			dock_settings = new Plank.DockPreferences.with_filename (Environment.get_user_config_dir () + "/plank/dock1/settings");
			dock_settings.changed.connect (setup_plank_renderer);
			
			dock_renderer = new Plank.Drawing.DockThemeRenderer ();
			dock_renderer.load ("dock");
			dock_renderer.changed.connect (setup_plank_renderer);
			
			dock = new Actor ();
			dock.layout_manager = new BoxLayout ();
			dock.anchor_gravity = Clutter.Gravity.CENTER;
			
			dock_background = new CairoTexture (100, dock_settings.IconSize);
			dock_background.anchor_gravity = Clutter.Gravity.CENTER;
			dock_background.auto_resize = true;
			dock_background.draw.connect (draw_dock_background);
			dock_background.add_constraint (new BindConstraint (dock, BindCoordinate.X, 0));
			dock_background.add_constraint (new BindConstraint (dock, BindCoordinate.Y, 0));
			dock_background.add_constraint (new BindConstraint (dock, BindCoordinate.WIDTH, 0));
			dock_background.add_constraint (new BindConstraint (dock, BindCoordinate.HEIGHT, 0));
			
			add_child (dock_background);
			add_child (dock);
			
			setup_plank_renderer ();
			
			visible = false;
		}
		
		//set the values which don't get set every time and need to be updated when the theme changes
		void setup_plank_renderer ()
		{
			(dock.layout_manager as BoxLayout).spacing = (uint)(dock_renderer.ItemPadding / 10.0 * dock_settings.IconSize);
			dock.height = dock_settings.IconSize;
		}
		
		bool draw_dock_background (Cairo.Context cr)
		{
			var top_offset = (int)(dock_renderer.TopPadding / 10.0 * dock_settings.IconSize);
			var bottom_offset = (int)(dock_renderer.BottomPadding / 10.0 * dock_settings.IconSize);
			
			if (dock_surface == null || dock_surface.Width != dock_background.width) {
				dock_surface = dock_renderer.create_background ((int)dock_background.width,
					dock_settings.IconSize + top_offset + bottom_offset, Gtk.PositionType.BOTTOM,
					new Plank.Drawing.DockSurface.with_surface (1, 1, cr.get_target ()));
			}
			
			cr.set_source_surface (dock_surface.Internal, 0, -top_offset - bottom_offset);
			cr.paint ();
			
			return false;
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (((event.modifier_state & ModifierType.MOD1_MASK) == 0) || 
					event.keyval == Key.Alt_L) {
				close (event.time);
			}
			
			return true;
		}
		
		void close (uint time)
		{
			foreach (var clone in window_clones) {
				remove_child (clone);
				clone.destroy ();
			}
			
			Meta.Compositor.get_window_actors (plugin.get_screen ()).foreach ((w) => {
				var meta_win = w.get_meta_window ();
				if (!meta_win.minimized && 
					(meta_win.get_workspace () == plugin.get_screen ().get_active_workspace ()) || 
					meta_win.is_on_all_workspaces ())
					w.show ();
			});
			if (dock_window != null)
				dock_window.opacity = 0;
			
			window_clones.clear ();
			
			plugin.end_modal ();
			if (current_window != null) {
				current_window.activate (time);
				current_window = null;
			}
			
			var dest_width = (dock_window != null ? dock_window.width : 800.0f);
			
			set_child_above_sibling (dock, null);
			dock_background.animate (AnimationMode.EASE_OUT_CUBIC, 250, opacity : 0);
			
			if (dock_window != null)
				dock_window.animate (AnimationMode.LINEAR, 250, opacity : 255);
			
			dock.animate (AnimationMode.EASE_OUT_CUBIC, 250, width:dest_width, opacity : 0).
				completed.connect (() => {
				dock.remove_all_children ();
				
				if (dock_window != null)
					dock_window = null;
				
				visible = false;
			});
		}
		
		//used to figure out delays between switching when holding the tab key
		uint last_time = -1;
		bool released = false;
		public override bool captured_event (Clutter.Event event)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			if (event.get_type () == EventType.KEY_RELEASE) {
				released = true;
				return false;
			}
			
			if (!(event.get_type () == EventType.KEY_PRESS) || 
				(!released && display.get_current_time_roundtrip () < (last_time + 300)))
				return false;
			
			released = false;
			
			bool backward = (event.get_state () & X.KeyMask.ShiftMask) != 0;
			var action = display.get_keybinding_action (event.get_key_code (), event.get_state ());
			
			var prev_win = current_window;
			switch (action) {
				case Meta.KeyBindingAction.SWITCH_GROUP:
				case Meta.KeyBindingAction.SWITCH_WINDOWS:
					current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
							screen.get_active_workspace (), current_window, backward);
					last_time = display.get_current_time_roundtrip ();
					break;
				case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
				case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
					current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
							screen.get_active_workspace (), current_window, true);
					last_time = display.get_current_time_roundtrip ();
					break;
				default:
					break;
			}
			
			if (prev_win != current_window) {
				dim_windows ();
			}
			
			return true;
		}
		
		void dim_windows ()
		{
			var current_actor = current_window.get_compositor_private () as Actor;
			var i = 0;
			foreach (var clone in window_clones) {
				if (current_actor == clone.source) {
					clone.get_parent ().set_child_above_sibling (clone, null);
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : 0.0f, opacity : 255);
					
					dock.get_child_at_index (i).animate (AnimationMode.LINEAR, 100, opacity : 255);
				} else {
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : -200.0f, opacity : 0);
					dock.get_child_at_index (i).animate (AnimationMode.LINEAR, 100, opacity : 100);
				}
				
				i++;
			}
		}
		
		public void handle_switch_windows (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			if (visible) {
				if (window_clones.size != 0)
					close (screen.get_display ().get_current_time ());
				return;
			}
			
			var metawindows = display.get_tab_list (Meta.TabList.NORMAL, screen, screen.get_active_workspace ());
			if (metawindows.length () <= 1)
				return;
			
			visible = true;
			
			//grab the windows to be switched
			var layout = dock.layout_manager as BoxLayout;
			window_clones.clear ();
			foreach (var win in metawindows) {
				var actor = win.get_compositor_private () as Actor;
				var clone = new Clone (actor);
				clone.x = actor.x;
				clone.y = actor.y;
				
				add_child (clone);
				window_clones.add (clone);
				
				var icon = new GtkClutter.Texture ();
				try {
					icon.set_from_pixbuf (Utils.get_icon_for_window (win, dock_settings.IconSize));
				} catch (Error e) { warning (e.message); }
				
				icon.opacity = 100;
				dock.add_child (icon);
				layout.set_expand (icon, true);
			}
			
			//hide the others
			Meta.Compositor.get_window_actors (screen).foreach ((w) => {
				var type = w.get_meta_window ().window_type;
				if (type != Meta.WindowType.DOCK && type != Meta.WindowType.DESKTOP && type != Meta.WindowType.NOTIFICATION)
					w.hide ();
				
				if (w.get_meta_window ().title in DOCK_NAMES && type == Meta.WindowType.DOCK) {
					dock_window = w;
					dock_window.hide ();
				}
			});
			
			plugin.begin_modal ();
			
			bool backward = (binding.get_name () == "switch-windows-backward");
			
			current_window = Utils.get_next_window (screen.get_active_workspace (), backward);
			if (current_window == null)
				return;
			
			if (binding.get_mask () == 0) {
				current_window.activate (display.get_current_time ());
				return;
			}
			
			//plank type switcher thing
			var geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());
			
			if (dock_window != null)
				dock.width = dock_window.width;
			
			dock.opacity = 255;
			dock.x = Math.ceilf (geometry.x + geometry.width / 2.0f);
			dock.y = Math.ceilf (geometry.y + geometry.height - dock.height / 2.0f);
			
			//add spacing on outer most items
			var horiz_padding = (float) Math.ceil (dock_renderer.HorizPadding / 10.0 * dock_settings.IconSize);
			dock.get_first_child ().margin_left = horiz_padding;
			dock.get_last_child ().margin_right = horiz_padding;
			
			float dest_width;
			layout.get_preferred_width (dock, dock.height, null, out dest_width);
			
			set_child_above_sibling (dock_background, null);
			dock_background.opacity = 255;
			dock.animate (AnimationMode.EASE_OUT_CUBIC, 250, width : dest_width);
			set_child_above_sibling (dock, null);
			
			dim_windows ();
			grab_key_focus ();
		}
	}
}
