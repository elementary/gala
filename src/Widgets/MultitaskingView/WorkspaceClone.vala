//
//  Copyright (C) 2014 Tom Beckmann
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
using Meta;

namespace Gala
{
	class FramedBackground : Background
	{
		public FramedBackground (Screen screen)
		{
			base (screen, screen.get_primary_monitor (),
				BackgroundSettings.get_default ().schema);

			var primary = screen.get_primary_monitor ();
			var monitor_geom = screen.get_monitor_geometry (primary);

			add_effect (new ShadowEffect (monitor_geom.width, monitor_geom.height, 40, 5));
		}

		public override void paint ()
		{
			base.paint ();

			Cogl.set_source_color4ub (0, 0, 0, 100);
			Cogl.Path.rectangle (0, 0, width, height);
			Cogl.Path.stroke ();

			Cogl.set_source_color4ub (255, 255, 255, 80);
			Cogl.Path.rectangle (1, 1, width - 2, height - 2);
			Cogl.Path.stroke ();
		}
	}

	public class WorkspaceClone : Clutter.Actor
	{
		public const int BOTTOM_OFFSET = 100;
		const int TOP_OFFSET = 20;
		const int HOVER_ACTIVATE_DELAY = 400;

		public signal void window_selected (Window window);
		public signal void selected (bool close_view);

		public WindowManager wm { get; construct; }
		public Workspace workspace { get; construct; }
		public IconGroup icon_group { get; private set; }
		public TiledWindowContainer window_container { get; private set; }

		bool _active = false;
		public bool active {
			get {
				return _active;
			}
			set {
				_active = value;
				icon_group.active = value;
			}
		}

		Background background;
		bool opened;

		uint hover_activate_timeout = 0;

		public WorkspaceClone (WindowManager wm, Workspace workspace)
		{
			Object (wm: wm, workspace: workspace);
		}

		construct
		{
			opened = false;

			var screen = workspace.get_screen ();
			var monitor_geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());

			background = new FramedBackground (workspace.get_screen ());
			background.reactive = true;
			background.button_press_event.connect (() => {
				selected (true);
				return false;
			});

			window_container = new TiledWindowContainer (wm.window_stacking_order);
			window_container.window_selected.connect ((w) => { window_selected (w); });
			window_container.width = monitor_geometry.width;
			window_container.height = monitor_geometry.height;
			wm.windows_restacked.connect (() => {
				window_container.stacking_order = wm.window_stacking_order;
			});

			icon_group = new IconGroup (workspace);
			icon_group.selected.connect (() => {
				selected (false);
			});

			var icons_drop_action = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			icon_group.add_action (icons_drop_action);

			var background_drop_action = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			background.add_action (background_drop_action);
			background_drop_action.crossed.connect ((hovered) => {
				if (!hovered && hover_activate_timeout != 0) {
					Source.remove (hover_activate_timeout);
					hover_activate_timeout = 0;
					return;
				}

				if (hovered && hover_activate_timeout == 0) {
					hover_activate_timeout = Timeout.add (HOVER_ACTIVATE_DELAY, () => {
						selected (false);
						hover_activate_timeout = 0;
						return false;
					});
				}
			});

			screen.window_left_monitor.connect ((monitor, window) => {
				if (monitor == screen.get_primary_monitor ())
					remove_window (window);
			});
			workspace.window_removed.connect (remove_window);

			screen.window_entered_monitor.connect ((monitor, window) => {
				add_window (window);
			});
			workspace.window_added.connect (add_window);

			add_child (background);
			add_child (window_container);

			// add existing windows
			var windows = workspace.list_windows ();
			foreach (var window in windows) {
				if (window.window_type == WindowType.NORMAL
					&& window.get_monitor () == screen.get_primary_monitor ()) {
					window_container.add_window (window);
					icon_group.add_window (window, true);
				}
			}
		}

		~WorkspaceClone ()
		{
			background.destroy ();
		}

		private void add_window (Window window)
		{
			if (window.window_type != WindowType.NORMAL
				|| window.get_workspace () != workspace
				|| window.get_monitor () != window.get_screen ().get_primary_monitor ())
				return;

			foreach (var child in window_container.get_children ())
				if ((child as TiledWindow).window == window)
					return;

			window_container.add_window (window);
			icon_group.add_window (window);
		}

		private void remove_window (Window window)
		{
			window_container.remove_window (window);
			icon_group.remove_window (window, opened);
		}

		private void shrink_rectangle (ref Meta.Rectangle rect, int amount)
		{
			rect.x += amount;
			rect.y += amount;
			rect.width -= amount * 2;
			rect.height -= amount * 2;
		}

		public void open ()
		{
			var screen = workspace.get_screen ();
			var display = screen.get_display ();

			var monitor = screen.get_monitor_geometry (screen.get_primary_monitor ());
			var scale = (float)(monitor.height - TOP_OFFSET - BOTTOM_OFFSET) / monitor.height;
			var pivotY = TOP_OFFSET / (monitor.height - monitor.height * scale);
			background.set_pivot_point (0.5f, pivotY);

			background.save_easing_state ();
			background.set_easing_duration (250);
			background.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
			background.set_scale (scale, scale);
			background.restore_easing_state ();

			Meta.Rectangle area = {
				(int)Math.floorf (monitor.x + monitor.width - monitor.width * scale) / 2,
				(int)Math.floorf (monitor.y + TOP_OFFSET),
				(int)Math.floorf (monitor.width * scale),
				(int)Math.floorf (monitor.height * scale)
			};
			shrink_rectangle (ref area, 32);

			opened = true;

			window_container.padding_top = TOP_OFFSET;
			window_container.padding_left =
				window_container.padding_right = (int)(monitor.width - monitor.width * scale) / 2;
			window_container.padding_bottom = BOTTOM_OFFSET;

			icon_group.redraw ();

			window_container.opened = true;
			if (screen.get_active_workspace () == workspace)
				window_container.current_window = display.get_focus_window ();
		}

		public void close ()
		{
			opened = false;

			background.save_easing_state ();
			background.set_easing_duration (300);
			background.set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
			background.set_scale (1, 1);
			background.restore_easing_state ();

			window_container.opened = false;
		}
	}
}

