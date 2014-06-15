using Clutter;

namespace Gala
{
	class WindowIcon : Actor
	{
		public Meta.Window window { get; construct; }

		int _icon_size;
		public int icon_size {
			get {
				return _icon_size;
			}
			set {
				if (value == _icon_size)
					return;

				_icon_size = value;

				set_size (_icon_size, _icon_size);

				fade_new_icon ();
			}
		}

		bool _temporary;
		public bool temporary {
			get {
				return _temporary;
			}
			set {
				if (_temporary && !value) {
					remove_transition ("pulse");
				} else if (!_temporary && value) {
					var transition = new TransitionGroup ();
					transition.duration = 800;
					transition.auto_reverse = true;
					transition.repeat_count = -1;
					transition.progress_mode = AnimationMode.LINEAR;

					var opacity_transition = new PropertyTransition ("opacity");
					opacity_transition.set_from_value (100);
					opacity_transition.set_to_value (255);
					opacity_transition.auto_reverse = true;

					var scale_x_transition = new PropertyTransition ("scale-x");
					scale_x_transition.set_from_value (0.8);
					scale_x_transition.set_to_value (1.3);
					scale_x_transition.auto_reverse = true;

					var scale_y_transition = new PropertyTransition ("scale-y");
					scale_y_transition.set_from_value (0.8);
					scale_y_transition.set_to_value (1.3);
					scale_y_transition.auto_reverse = true;

					transition.add_transition (opacity_transition);
					transition.add_transition (scale_x_transition);
					transition.add_transition (scale_y_transition);

					add_transition ("pulse", transition);
				}

				_temporary = value;
			}
		}

		bool initial = true;

		GtkClutter.Texture? icon = null;
		GtkClutter.Texture? old_icon = null;

		public WindowIcon (Meta.Window window)
		{
			Object (window: window);

			set_pivot_point (0.5f, 0.5f);
			set_easing_mode (AnimationMode.EASE_OUT_ELASTIC);
			set_easing_duration (800);
		}

		public void place (float x, float y, int size)
		{
			if (initial) {
				save_easing_state ();
				set_easing_duration (10);
			}

			set_position (x, y);
			icon_size = size;

			if (initial) {
				restore_easing_state ();
				initial = false;
			}
		}

		void fade_new_icon ()
		{
			var new_icon = new GtkClutter.Texture ();
			new_icon.add_constraint (new BindConstraint (this, BindCoordinate.SIZE, 0));
			new_icon.opacity = 0;

			var pixbuf = Utils.get_icon_for_window (window, icon_size);
			try {
				new_icon.set_from_pixbuf (pixbuf);
			} catch (Error e) {}

			add_child (new_icon);

			new_icon.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
			new_icon.set_easing_duration (500);

			if (icon == null) {
				icon = new_icon;
			} else {
				old_icon = icon;
			}

			new_icon.opacity = 255;

			if (old_icon != null) {
				old_icon.opacity = 0;
				var transition = old_icon.get_transition ("opacity");
				if (transition != null) {
					transition.completed.connect (() => {
						old_icon.destroy ();
						old_icon = null;
					});
				} else {
					old_icon.destroy ();
					old_icon = null;
				}
			}

			icon = new_icon;
		}
	}

	public class IconGroup : Actor
	{
		const int SIZE = 64;
		
		static const int PLUS_SIZE = 8;
		static const int PLUS_WIDTH = 24;

		public signal void selected ();

		public Meta.Workspace workspace { get; construct; }

		List<string> windows;

		int current_icon_size = -1;

		public IconGroup (Meta.Workspace workspace)
		{
			Object (workspace: workspace);

			clear ();

			width = SIZE;
			height = SIZE;
			reactive = true;

			var canvas = new Canvas ();
			canvas.set_size (SIZE, SIZE);
			canvas.draw.connect (draw);
			content = canvas;
		}

		public override bool button_release_event (ButtonEvent event)
		{
			selected ();

			return false;
		}

		public void clear ()
		{
			destroy_all_children ();
		}

		public void add_window (Meta.Window window, bool no_redraw = false, bool temporary = false)
		{
			var new_window = new WindowIcon (window);

			new_window.save_easing_state ();
			new_window.set_easing_duration (0);
			new_window.set_position (32, 32);
			new_window.restore_easing_state ();
			new_window.temporary = temporary;

			add_child (new_window);

			if (!no_redraw)
				redraw ();
		}

		public void remove_window (Meta.Window window, bool animate = true)
		{
			foreach (var child in get_children ()) {
				var w = child as WindowIcon;
				if (w.window == window) {
					if (animate) {
						w.set_easing_mode (AnimationMode.LINEAR);
						w.set_easing_duration (200);
						w.opacity = 0;

						print ("c\n");
						w.get_transition ("opacity").completed.connect (() => {
							w.destroy ();
							redraw ();
						});
						print ("d\n");
					} else
						w.destroy ();
					break;
				}
			}
		}

		public void redraw ()
		{
			content.invalidate ();
		}

		/**
		 * Draw the background or plus sign and do layouting. We won't lose performance here
		 * by relayouting in the same function, as it's only ever called when we invalidate it.
		 */
		bool draw (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			var n_windows = get_n_children ();

			// single icon => big icon
			if (n_windows == 1) {
				var icon = get_child_at_index (0) as WindowIcon;
				icon.place (0, 0, 64);

				return false;
			}

			// more than one => we need a folder
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, (int)width - 1, (int)height - 1, 5);

			cr.set_source_rgba (0, 0, 0, 0.1);
			cr.fill_preserve ();

			cr.set_line_width (1);

			var grad = new Cairo.Pattern.linear (0, 0, 0, height);
			grad.add_color_stop_rgba (0.8, 0, 0, 0, 0);
			grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.1);

			cr.set_source (grad);
			cr.stroke ();

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 1.5, 1.5, (int)width - 3, (int)height - 3, 5);

			cr.set_source_rgba (0, 0, 0, 0.3);
			cr.stroke ();

			// the only workspace that can be empty is the last one, so we draw our
			// plus here
			if (n_windows < 1) {
				var buffer = new Granite.Drawing.BufferSurface (SIZE, SIZE);
				var offset = SIZE / 2 - PLUS_WIDTH / 2;

				buffer.context.rectangle (PLUS_WIDTH / 2 - PLUS_SIZE / 2 + 0.5 + offset,
					0.5 + offset,
					PLUS_SIZE - 1,
					PLUS_WIDTH - 1);

				buffer.context.rectangle (0.5 + offset,
					PLUS_WIDTH / 2 - PLUS_SIZE / 2 + 0.5 + offset,
					PLUS_WIDTH - 1,
					PLUS_SIZE - 1);

				buffer.context.set_source_rgb (0, 0, 0);
				buffer.context.fill_preserve ();
				buffer.exponential_blur (5);

				buffer.context.set_source_rgb (1, 1, 1);
				buffer.context.set_line_width (1);
				buffer.context.stroke_preserve ();

				buffer.context.set_source_rgb (0.8, 0.8, 0.8);
				buffer.context.fill ();

				cr.set_source_surface (buffer.surface, 0, 0);
				cr.paint ();

				return false;
			}

			int size;
			if (n_windows < 5)
				size = 22;
			else
				size = 16;

			var n_tiled_windows = uint.min (n_windows, 9);
			var columns = (int)Math.ceil (Math.sqrt (n_tiled_windows));
			var rows = (int)Math.ceil (n_tiled_windows / (double)columns);

			const int spacing = 6;

			var width = columns * size + (columns - 1) * spacing;
			var height = rows * size + (rows - 1) * spacing;
			var x_offset = SIZE / 2 - width / 2;
			var y_offset = SIZE / 2 - height / 2;

			var show_ellipsis = false;
			var n_shown_windows = n_windows;
			// make place for an ellipsis
			if (n_shown_windows > 9) {
				n_shown_windows = 8;
				show_ellipsis = true;
			}

			var x = x_offset;
			var y = y_offset;
			for (var i = 0; i < n_windows; i++) {
				var window = get_child_at_index (i) as WindowIcon;

				// draw an ellipsis at the 9th position if we need one
				if (show_ellipsis && i == 8) {
					const int top_offset = 10;
					const int left_offset = 2;
					const int radius = 2;
					const int spacing = 3;
					cr.arc (left_offset + x, y + top_offset, radius, 0, 2 * Math.PI);
					cr.arc (left_offset + x + radius + spacing, y + top_offset, radius, 0, 2 * Math.PI);
					cr.arc (left_offset + x + radius * 2 + spacing * 2, y + top_offset, radius, 0, 2 * Math.PI);

					cr.set_source_rgb (0.3, 0.3, 0.3);
					cr.fill ();
				}

				if (i >= n_shown_windows) {
					window.visible = false;
					continue;
				}

				window.place (x, y, size);

				x += size + spacing;
				if (x + size >= SIZE) {
					x = x_offset;
					y += size + spacing;
				}
			}

			return false;
		}
	}
}

