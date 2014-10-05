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
	/**
	 * Private class which is basically just a container for the actual
	 * icon and takes care of blending the same icon in different sizes
	 * over each other and various animations related to the icons
	 */
	class WindowIcon : Actor
	{
		public Window window { get; construct; }

		int _icon_size;
		/**
		 * The icon size of the WindowIcon. Once set the new icon will be
		 * faded over the old one and the actor animates to the new size.
		 */
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
		/**
		 * Mark the WindowIcon as temporary. Only effect of this is that a pulse
		 * animation will be played on the actor. Used while DnDing window thumbs
		 * over the group.
		 */
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
					scale_x_transition.set_to_value (1.1);
					scale_x_transition.auto_reverse = true;

					var scale_y_transition = new PropertyTransition ("scale-y");
					scale_y_transition.set_from_value (0.8);
					scale_y_transition.set_to_value (1.1);
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

		Utils.WindowIcon? icon = null;
		Utils.WindowIcon? old_icon = null;

		public WindowIcon (Window window)
		{
			Object (window: window);
		}

		construct
		{
			set_pivot_point (0.5f, 0.5f);
			set_easing_mode (AnimationMode.EASE_OUT_ELASTIC);
			set_easing_duration (800);

			window.notify["on-all-workspaces"].connect (on_all_workspaces_changed);
		}

		~WindowIcon ()
		{
			window.notify["on-all-workspaces"].disconnect (on_all_workspaces_changed);
		}

		void on_all_workspaces_changed ()
		{
			// we don't display windows that are on all workspaces
			if (window.on_all_workspaces)
				destroy ();
		}

		/**
		 * Shortcut to set both position and size of the icon
		 *
		 * @param x    The x coordinate to which to animate to
		 * @param y    The y coordinate to which to animate to
		 * @param size The size to which to animate to and display the icon in
		 */
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

		/**
		 * Fades out the old icon and fades in the new icon
		 */
		void fade_new_icon ()
		{
			var new_icon = new Utils.WindowIcon (window, icon_size);
			new_icon.add_constraint (new BindConstraint (this, BindCoordinate.SIZE, 0));
			new_icon.opacity = 0;

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

	/**
	 * Container for WindowIcons which takes care of the scaling and positioning.
	 * It also decides whether to draw the container shape, a plus sign or an ellipsis.
	 * Lastly it also includes the drawing code for the active highlight.
	 */
	public class IconGroup : Actor
	{
		public static const int SIZE = 64;

		static const int PLUS_SIZE = 8;
		static const int PLUS_WIDTH = 24;

		const int SHOW_CLOSE_BUTTON_DELAY = 200;

		/**
		 * The group has been clicked. The MultitaskingView should consider activating
		 * its workspace.
		 */
		public signal void selected ();

		uint8 _backdrop_opacity = 0;
		/**
		 * The opacity of the backdrop/highlight. Set by the active property setter.
		 */
		protected uint8 backdrop_opacity {
			get {
				return _backdrop_opacity;
			}
			set {
				_backdrop_opacity = value;
				queue_redraw ();
			}
		}

		bool _active = false;
		/**
		 * Fades in/out the backdrop/highlight
		 */
		public bool active {
			get {
				return _active;
			}
			set {
				if (_active == value)
					return;

				if (get_transition ("backdrop-opacity") != null)
					remove_transition ("backdrop-opacity");

				_active = value;

				var transition = new PropertyTransition ("backdrop-opacity");
				transition.duration = 300;
				transition.remove_on_complete = true;
				transition.set_from_value (_active ? 0 : 40);
				transition.set_to_value (_active ? 40 : 0);

				add_transition ("backdrop-opacity", transition);
			}
		}

		public Workspace workspace { get; construct; }

		Actor close_button;
		Actor icon_container;
		Cogl.Material dummy_material;

		uint show_close_button_timeout = 0;

		public IconGroup (Workspace workspace)
		{
			Object (workspace: workspace);
		}

		construct
		{
			width = SIZE;
			height = SIZE;
			reactive = true;

			var canvas = new Canvas ();
			canvas.set_size (SIZE, SIZE);
			canvas.draw.connect (draw);
			content = canvas;

			dummy_material = new Cogl.Material ();

			var click = new ClickAction ();
			click.clicked.connect (() => selected ());
			// when the actor is pressed, the ClickAction grabs all events, so we won't be
			// notified when the cursor leaves the actor, which makes our close button stay
			// forever. To fix this we hide the button for as long as the actor is pressed.
			click.notify["pressed"].connect (() => {
				toggle_close_button (!click.pressed && get_has_pointer ());
			});
			add_action (click);

			icon_container = new Actor ();
			icon_container.width = width;
			icon_container.height = height;

			add_child (icon_container);

			close_button = Utils.create_close_button ();
			close_button.x = -Math.floorf (close_button.width * 0.4f);
			close_button.y = -Math.floorf (close_button.height * 0.4f);
			close_button.opacity = 0;
			close_button.reactive = true;
			close_button.visible = false;
			close_button.set_easing_duration (200);

			// block propagation of button presses on the close button, otherwise
			// the click action on the icon group will act weirdly
			close_button.button_press_event.connect (() => { return true; });

			add_child (close_button);

			var close_click = new ClickAction ();
			close_click.clicked.connect (close);
			close_button.add_action (close_click);

			icon_container.actor_removed.connect_after (redraw);
		}

		~IconGroup ()
		{
			icon_container.actor_removed.disconnect (redraw);
		}

		public override bool enter_event (CrossingEvent event)
		{
			toggle_close_button (true);
			return false;
		}

		public override bool leave_event (CrossingEvent event)
		{
			if (!contains (event.related))
				toggle_close_button (false);

			return false;
		}

		/**
		 * Requests toggling the close button. If show is true, a timeout will be set after which
		 * the close button is shown, if false, the close button is hidden and the timeout is removed,
		 * if it exists. The close button may not be shown even though requested if the workspace has
		 * no windows or workspaces aren't set to be dynamic.
		 *
		 * @param show Whether to show the close button
		 */
		void toggle_close_button (bool show)
		{
			// don't display the close button when we don't have dynamic workspaces
			// or when there are no windows on us. For one, our method for closing
			// wouldn't work anyway without windows and it's also the last workspace
			// which we don't want to have closed if everything went correct
			if (!Prefs.get_dynamic_workspaces () || icon_container.get_n_children () < 1)
				return;

			if (show_close_button_timeout != 0) {
				Source.remove (show_close_button_timeout);
				show_close_button_timeout = 0;
			}

			if (show) {
				show_close_button_timeout = Timeout.add (SHOW_CLOSE_BUTTON_DELAY, () => {
					close_button.visible = true;
					close_button.opacity = 255;
					show_close_button_timeout = 0;
					return false;
				});
				return;
			}

			close_button.opacity = 0;
			var transition = get_transition ("opacity");
			if (transition != null)
				transition.completed.connect (() => {
					close_button.visible = false;
				});
			else
				close_button.visible = false;
		}

		/**
		 * Override the paint handler to draw our backdrop if necessary
		 */
		public override void paint ()
		{
			if (backdrop_opacity < 1) {
				base.paint ();
				return;
			}

			var width = 100;
			var x = (SIZE - width) / 2;
			var y = -10;
			var height = WorkspaceClone.BOTTOM_OFFSET;

			var color_top = Cogl.Color.from_4ub (0, 0, 0, 0);
			var color_bottom = Cogl.Color.from_4ub (255, 255, 255, backdrop_opacity);
			color_bottom.premultiply ();

			Cogl.TextureVertex vertices[4];
			vertices[0] = { x, y, 0, 0, 0, color_top };
			vertices[1] = { x, y + height, 0, 0, 1, color_bottom };
			vertices[2] = { x + width, y + height, 0, 1, 1, color_bottom };
			vertices[3] = { x + width, y, 0, 1, 0, color_top };

			// for some reason cogl will try mapping the textures of the children
			// to the cogl_polygon call. We can fix this and force it to use our
			// color by setting a different material with no properties.
			Cogl.set_source (dummy_material);
			Cogl.polygon (vertices, true);

			base.paint ();
		}

		/**
		 * Remove all currently added WindowIcons
		 */
		public void clear ()
		{
			icon_container.destroy_all_children ();
		}

		/**
		 * Creates a WindowIcon for the given window and adds it to the group
		 *
		 * @param window    The MetaWindow for which to create the WindowIcon
		 * @param no_redraw If you add multiple windows at once you may want to consider
		 *                  settings this to true and when done calling redraw() manually
		 * @param temporary Mark the WindowIcon as temporary. Used for windows dragged over
		 *                  the group.
		 */
		public void add_window (Window window, bool no_redraw = false, bool temporary = false)
		{
			var new_window = new WindowIcon (window);

			new_window.save_easing_state ();
			new_window.set_easing_duration (0);
			new_window.set_position (32, 32);
			new_window.restore_easing_state ();
			new_window.temporary = temporary;

			icon_container.add_child (new_window);

			if (!no_redraw)
				redraw ();
		}

		/**
		 * Remove the WindowIcon for a MetaWindow from the group
		 *
		 * @param animate Whether to fade the icon out before removing it
		 */
		public void remove_window (Window window, bool animate = true)
		{
			foreach (var child in icon_container.get_children ()) {
				unowned WindowIcon w = (WindowIcon) child;
				if (w.window == window) {
					if (animate) {
						w.set_easing_mode (AnimationMode.LINEAR);
						w.set_easing_duration (200);
						w.opacity = 0;

						var transition = w.get_transition ("opacity");
						if (transition != null) {
							transition.completed.connect (() => {
								w.destroy ();
							});
						} else {
							w.destroy ();
						}

					} else
						w.destroy ();

					// don't break here! If people spam hover events and we animate
					// removal, we can actually multiple instances of the same window icon
				}
			}
		}

		/**
		 * Trigger a redraw
		 */
		public void redraw ()
		{
			content.invalidate ();
		}

		/**
		 * Close handler. We close the workspace by deleting all the windows on it.
		 * That way the workspace won't be deleted if windows decide to ignore the
		 * delete signal
		 */
		void close ()
		{
			var time = workspace.get_screen ().get_display ().get_current_time ();
			foreach (var window in workspace.list_windows ()) {
				var type = window.window_type;
				if (!window.is_on_all_workspaces () && (type == WindowType.NORMAL
					|| type == WindowType.DIALOG || type == WindowType.MODAL_DIALOG))
					window.@delete (time);
			}
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

			var n_windows = icon_container.get_n_children ();

			// single icon => big icon
			if (n_windows == 1) {
				var icon = (WindowIcon) icon_container.get_child_at_index (0);
				icon.place (0, 0, 64);

				return false;
			}

			// more than one => we need a folder
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, (int) width - 1, (int) height - 1, 5);

			cr.set_source_rgba (0, 0, 0, 0.1);
			cr.fill_preserve ();

			cr.set_line_width (1);

			var grad = new Cairo.Pattern.linear (0, 0, 0, height);
			grad.add_color_stop_rgba (0.8, 0, 0, 0, 0);
			grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.1);

			cr.set_source (grad);
			cr.stroke ();

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 1.5, 1.5, (int) width - 3, (int) height - 3, 5);

			cr.set_source_rgba (0, 0, 0, 0.3);
			cr.stroke ();

			// it's not safe to to call meta_workspace_index() here, we may be still animating something
			// while the workspace is already gone, which would result in a crash.
			var screen = workspace.get_screen ();
			var workspace_index = screen.get_workspaces ().index (workspace);

			if (n_windows < 1) {
				if (!Prefs.get_dynamic_workspaces ()
					|| workspace_index != screen.get_n_workspaces () - 1)
					return false;

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
				size = 24;
			else
				size = 16;

			var n_tiled_windows = uint.min (n_windows, 9);
			var columns = (int) Math.ceil (Math.sqrt (n_tiled_windows));
			var rows = (int) Math.ceil (n_tiled_windows / (double) columns);

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
				var window = (WindowIcon) icon_container.get_child_at_index (i);

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

