using Clutter;
using Meta;

namespace Gala
{
	public class MonitorClone : Actor
	{
		public WindowManager wm { get; construct; }
		public Screen screen { get; construct; }
		public int monitor { get; construct; }

		public signal void window_selected (Window window);

		TiledWorkspaceContainer window_container;
		Background background;

		public MonitorClone (WindowManager wm, Screen screen, int monitor)
		{
			Object (wm: wm, monitor: monitor, screen: screen);

			reactive = true;

			background = new Background (screen, monitor, BackgroundSettings.get_default ().schema);
			background.set_easing_duration (300);

			window_container = new TiledWorkspaceContainer (wm.window_stacking_order);
			window_container.window_selected.connect ((w) => { window_selected (w); });

			wm.windows_restacked.connect (() => {
				window_container.stacking_order = wm.window_stacking_order;
			});

			screen.window_entered_monitor.connect (window_entered);
			screen.window_left_monitor.connect (window_left);

			foreach (var window_actor in Compositor.get_window_actors (screen)) {
				var window = window_actor.get_meta_window ();
				if (window.get_monitor () == monitor) {
					window_entered (monitor, window);
				}
			}

			add_child (background);
			add_child (window_container);

			var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			add_action (drop);

			update_allocation ();
		}

		public void update_allocation ()
		{
			var monitor_geometry = screen.get_monitor_geometry (monitor);

			set_position (monitor_geometry.x, monitor_geometry.y);
			set_size (monitor_geometry.width, monitor_geometry.height);
			window_container.set_size (monitor_geometry.width, monitor_geometry.height);
		}

		public void open ()
		{
			window_container.opened = true;
			// background.opacity = 0; TODO consider this option
		}

		public void close ()
		{
			window_container.opened = false;
			background.opacity = 255;
		}

		void window_left (int window_monitor, Window window)
		{
			if (window_monitor != monitor)
				return;

			window_container.remove_window (window);
		}

		void window_entered (int window_monitor, Window window)
		{
			if (window_monitor != monitor || window.window_type != WindowType.NORMAL)
				return;

			window_container.add_window (window);
		}
	}
}

