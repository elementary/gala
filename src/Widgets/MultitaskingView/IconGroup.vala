using Clutter;

namespace Gala
{
	public class IconGroup : Actor
	{
		List<Meta.Window> windows;

		const int SIZE = 64;
		
		static const int PLUS_SIZE = 8;
		static const int PLUS_WIDTH = 24;

		public signal void selected ();

		public IconGroup ()
		{
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
			windows = new List<Meta.Window> ();
		}

		public void add_window (Meta.Window window, bool no_redraw = false)
		{
			windows.append (window);

			if (!no_redraw)
				redraw ();
		}

		public void redraw ()
		{
			content.invalidate ();
		}

		bool draw (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			// we never show more than 9, TODO: show an ellipsis when we do cut
			var n_windows = uint.min (windows.length (), 9);

			if (n_windows == 1) {
				var pix = Utils.get_icon_for_window (windows.nth_data (0), 64);
				Gdk.cairo_set_source_pixbuf (cr, pix, 0, 0);
				cr.paint ();
				return false;
			}

			// folder
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

			var columns = (int)Math.ceil (Math.sqrt (n_windows));
			var rows = (int)Math.ceil (n_windows / (double)columns);

			const int spacing = 6;

			var width = columns * size + (columns - 1) * spacing;
			var height = rows * size + (rows - 1) * spacing;
			var x_offset = SIZE / 2 - width / 2;
			var y_offset = SIZE / 2 - height / 2;

			var x = x_offset;
			var y = y_offset;
			for (var i = 0; i < n_windows; i++) {
				var pix = Utils.get_icon_for_window (windows.nth_data (i), size);

				Gdk.cairo_set_source_pixbuf (cr, pix, x, y);

				x += size + spacing;
				if (x + size >= SIZE) {
					x = x_offset;
					y += size + spacing;
				}

				cr.paint ();
			}

			return false;
		}
	}
}

