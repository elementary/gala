using Clutter;

namespace Gala
{
	class FramedBackground : BackgroundManager
	{
		public FramedBackground (Meta.Screen screen)
		{
			base (screen);

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

				int screen_width, screen_height;
				screen.get_size (out screen_width, out screen_height);

				width = screen_width + SHADOW_SIZE * 2;
				height = screen_height + SHADOW_SIZE * 2;

				var buffer = new Granite.Drawing.BufferSurface (width, height);
				buffer.context.rectangle (SHADOW_SIZE - SHADOW_OFFSET, SHADOW_SIZE - SHADOW_OFFSET,
					screen_width + SHADOW_OFFSET * 2, screen_height + SHADOW_OFFSET * 2);
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
		public Meta.Workspace workspace { get; construct set; }
		public BackgroundManager background { get; private set; }
		public IconGroup icon_group { get; private set; }

		public signal void window_selected (Meta.Window window);
		public signal void selected (bool close_view);

		const int TOP_OFFSET = 20;
		public static const int BOTTOM_OFFSET = 100;

		public WorkspaceClone (Meta.Workspace workspace)
		{
			Object (workspace: workspace);

			background = new FramedBackground (workspace.get_screen ());
			background.reactive = true;
			background.button_press_event.connect (() => {
				selected (true);
				return false;
			});

			icon_group = new IconGroup ();
			icon_group.selected.connect (() => {
				selected (false);
			});

			var screen = workspace.get_screen ();
			screen.window_left_monitor.connect ((monitor, window) => {
				if (monitor == screen.get_primary_monitor ())
					remove_window (window);
			});
			workspace.window_removed.connect (remove_window);

			screen.window_entered_monitor.connect ((monitor, window) => {
				if (monitor == screen.get_primary_monitor ())
					add_window (window);
			});
			workspace.window_added.connect (add_window);

			add_child (background);
		}

		private void add_window (Meta.Window window)
		{
		}

		private void remove_window (Meta.Window window)
		{
			var window_actor = window.get_compositor_private ();

			foreach (var child in get_children ()) {
				if (child is Clone && (child as Clone).source == window_actor) {
					child.destroy ();
					break;
				}
			}
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

			icon_group.clear ();

			var unsorted_windows = workspace.list_windows ();
			var used_windows = new SList<Meta.Window> ();
			foreach (var window in unsorted_windows) {
				if (window.window_type == Meta.WindowType.NORMAL) {
					used_windows.append (window);
					icon_group.add_window (window, true);
				}
			}
			icon_group.redraw ();

			var windows = display.sort_windows_by_stacking (used_windows);
			var clones = new List<WindowThumb> ();

			foreach (var window in windows) {
				var window_actor = window.get_compositor_private () as Meta.WindowActor;

				var clone = new WindowThumb (window, false);
				clone.selected.connect (() => {
					window_selected (clone.window);
				});
				clone.set_position (window_actor.x, window_actor.y);

				add_child (clone);
				clones.append (clone);
			}

			if (clones.length () > 0)
				WindowOverview.grid_placement (area, clones, place_window);
		}

		void place_window (Actor window, Meta.Rectangle rect)
		{
			window.animate (AnimationMode.EASE_OUT_CUBIC, 250,
				x: rect.x + 0.0f, y: rect.y + 0.0f, width: rect.width + 0.0f, height: rect.height + 0.0f);
			(window as WindowThumb).place_children (rect.width, rect.height);
		}

		public void close ()
		{
			background.animate (AnimationMode.EASE_IN_OUT_CUBIC, 300, scale_x: 1.0f, scale_y: 1.0f);

			foreach (var child in get_children ()) {
				if (child is WindowThumb)
					(child as WindowThumb).close (true, false);
			}
		}

		~Workspace ()
		{
			background.destroy ();
		}
	}
}

