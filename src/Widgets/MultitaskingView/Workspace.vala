using Clutter;

namespace Gala
{
	class FramedBackground : Background
	{
		public FramedBackground (Meta.Screen screen)
		{
			base (screen, screen.get_primary_monitor (),
				BackgroundSettings.get_default ().schema);

			add_effect (new BackgroundShadowEffect (screen));
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

	class BackgroundShadowEffect : Effect
	{
		static Meta.Screen screen;
		static Cogl.Texture? bitmap;

		const int SHADOW_SIZE = 40;
		const int SHADOW_OFFSET = 5;

		static int width;
		static int height;

		public BackgroundShadowEffect (Meta.Screen _screen)
		{
			if (bitmap == null) {
				screen = _screen;

				var primary = screen.get_primary_monitor ();
				var monitor_geom = screen.get_monitor_geometry (primary);

				width = monitor_geom.width + SHADOW_SIZE * 2;
				height = monitor_geom.height + SHADOW_SIZE * 2;

				var buffer = new Granite.Drawing.BufferSurface (width, height);
				buffer.context.rectangle (SHADOW_SIZE - SHADOW_OFFSET, SHADOW_SIZE - SHADOW_OFFSET,
					monitor_geom.width + SHADOW_OFFSET * 2, monitor_geom.height + SHADOW_OFFSET * 2);
				buffer.context.set_source_rgba (0, 0, 0, 0.5);
				buffer.context.fill ();

				buffer.exponential_blur (20);

				var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
				var cr = new Cairo.Context (surface);

				cr.set_source_surface (buffer.surface, 0, 0);
				cr.paint ();

				bitmap = new Cogl.Texture.from_data (width, height, 0, Cogl.PixelFormat.BGRA_8888_PRE,
					Cogl.PixelFormat.ANY, surface.get_stride (), surface.get_data ());
			}
		}

		public override void paint (EffectPaintFlags flags)
		{
			Cogl.set_source_texture (bitmap);
			Cogl.rectangle (-SHADOW_SIZE, -SHADOW_SIZE, width - SHADOW_SIZE, height - SHADOW_SIZE);

			actor.continue_paint ();
		}
	}

	public class WorkspaceClone : Clutter.Actor
	{
		public static const int BOTTOM_OFFSET = 100;
		const int TOP_OFFSET = 20;
		const int HOVER_ACTIVATE_DELAY = 400;

		public signal void window_selected (Meta.Window window);
		public signal void selected (bool close_view);

		public WindowManager wm { get; construct; }
		public Meta.Workspace workspace { get; construct set; }
		public Background background { get; private set; }
		public IconGroup icon_group { get; private set; }
		public TiledWorkspaceContainer window_container { get; private set; }

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

		bool opened = false;

		uint hover_activate_timeout = 0;

		public WorkspaceClone (Meta.Workspace workspace, WindowManager wm)
		{
			Object (workspace: workspace, wm: wm);

			var screen = workspace.get_screen ();
			var monitor_geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());

			background = new FramedBackground (workspace.get_screen ());
			background.reactive = true;
			background.button_press_event.connect (() => {
				selected (true);
				return false;
			});

			window_container = new TiledWorkspaceContainer (wm.window_stacking_order);
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
				if (monitor == screen.get_primary_monitor ()
					&& window.get_workspace () == workspace)
					add_window (window);
			});
			workspace.window_added.connect (add_window);

			add_child (background);
			add_child (window_container);
		}

		private void add_window (Meta.Window window)
		{
			if (window.window_type != Meta.WindowType.NORMAL)
				return;

			foreach (var child in window_container.get_children ())
				if ((child as TiledWindow).window == window)
					return;

			window_container.add_window (window);
			icon_group.add_window (window);
		}

		private void remove_window (Meta.Window window)
		{
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
			background.animate (AnimationMode.EASE_OUT_QUAD, 250, scale_x: scale, scale_y: scale);

			Meta.Rectangle area = {
				(int)Math.floorf (monitor.x + monitor.width - monitor.width * scale) / 2,
				(int)Math.floorf (monitor.y + TOP_OFFSET),
				(int)Math.floorf (monitor.width * scale),
				(int)Math.floorf (monitor.height * scale)
			};
			shrink_rectangle (ref area, 32);

			opened = true;

			// TODO this can be optimized
			icon_group.clear ();
			window_container.destroy_all_children ();
			window_container.padding_top = TOP_OFFSET;
			window_container.padding_left =
				window_container.padding_right = (int)(monitor.width - monitor.width * scale) / 2;
			window_container.padding_bottom = BOTTOM_OFFSET;

			var windows = workspace.list_windows ();
			foreach (var window in windows) {
				if (window.window_type == Meta.WindowType.NORMAL) {
					window_container.add_window (window);
					icon_group.add_window (window, true);
				}
			}

			icon_group.redraw ();
			window_container.restack ();
			window_container.reflow ();
		}

		public void close ()
		{
			opened = false;

			background.animate (AnimationMode.EASE_IN_OUT_CUBIC, 300, scale_x: 1.0f, scale_y: 1.0f);

			window_container.transition_to_original_state ();
		}

		~Workspace ()
		{
			background.destroy ();
		}
	}
}

