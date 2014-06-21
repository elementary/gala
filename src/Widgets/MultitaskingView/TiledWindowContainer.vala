using Clutter;
using Meta;

namespace Gala
{
	public class TiledWindow : Actor
	{
		const int WINDOW_ICON_SIZE = 64;
		const int ACTIVE_SHAPE_SIZE = 12;

		public signal void selected ();
		public signal void request_reposition ();

		public Meta.Window window { get; construct; }
		public Meta.Rectangle? slot { get; private set; default = null; }

		bool _active = false;
		public bool active {
			get {
				return _active;
			}
			set {
				_active = value;

				active_shape.save_easing_state ();
				active_shape.set_easing_duration (200);

				active_shape.opacity = _active ? 255 : 0;

				active_shape.restore_easing_state ();
			}
		}

		DragDropAction drag_action;
		Clone? clone = null;

		Actor prev_parent = null;
		int prev_index = -1;
		ulong check_confirm_dialog_cb = 0;
		uint shadow_update_timeout = 0;

		Actor close_button;
		Actor active_shape;
		GtkClutter.Texture window_icon;

		public TiledWindow (Meta.Window window)
		{
			Object (window: window);

			reactive = true;

			window.unmanaged.connect (unmanaged);

			drag_action = new DragDropAction (DragDropActionType.SOURCE, "multitaskingview-window");
			drag_action.drag_begin.connect (drag_begin);
			drag_action.destination_crossed.connect (drag_destination_crossed);
			drag_action.drag_end.connect (drag_end);
			drag_action.drag_canceled.connect (drag_canceled);
			drag_action.actor_clicked.connect ((button) => {
				switch (button) {
					case 1:
						selected ();
						break;
					case 2:
						close_window ();
						break;
				}
			});

			add_action (drag_action);

			close_button = Utils.create_close_button ();
			close_button.opacity = 0;
			close_button.set_easing_duration (200);
			close_button.button_press_event.connect (() => {
				close_window ();
				return true;
			});
			enter_event.connect (() => {
				close_button.opacity = 255;
				return false;
			});
			leave_event.connect (() => {
				close_button.opacity = 0;
				return false;
			});

			window_icon = new Utils.WindowIcon (window, WINDOW_ICON_SIZE);
			window_icon.opacity = 0;
			window_icon.set_easing_duration (300);

			active_shape = new Clutter.Actor ();
			active_shape.background_color = { 255, 255, 255, 200 };
			active_shape.opacity = 0;

			add_child (active_shape);
			add_child (window_icon);
			add_child (close_button);

			load_clone ();
		}

		~TiledWindow ()
		{
			window.unmanaged.disconnect (unmanaged);

			if (shadow_update_timeout != 0)
				Source.remove (shadow_update_timeout);

#if HAS_MUTTER312
			window.size_changed.disconnect (update_shadow_size);
#else
			var actor = window.get_compositor_private () as WindowActor;
			if (actor != null)
				actor.size_changed.disconnect (update_shadow_size);
#endif
		}

		public void load_clone (bool was_waiting = false)
		{
			var actor = window.get_compositor_private () as WindowActor;
			if (actor == null) {
				Idle.add (() => {
					if (window.get_compositor_private () != null)
						load_clone (true);
					return false;
				});

				return;
			}

			clone = new Clone (actor.get_texture ());
			add_child (clone);

			set_child_below_sibling (active_shape, clone);
			set_child_above_sibling (close_button, clone);
			set_child_above_sibling (window_icon, clone);

			transition_to_original_state (false);

			var outer_rect = window.get_outer_rect ();
			add_effect_with_name ("shadow", new ShadowEffect (outer_rect.width, outer_rect.height, 40, 5));
#if HAS_MUTTER312
			window.size_changed.connect (update_shadow_size);
#else
			actor.size_changed.connect (update_shadow_size);
#endif

			// if we were waiting the view was most probably already opened when our window
			// finally got available. So we fade-in and make sure we took the took place.
			// If the slot is not available however, the view was probably closed while this
			// window was opened, so we stay at our old place.
			if (was_waiting && slot != null) {
				opacity = 0;
				take_slot (slot);
				opacity = 255;

				request_reposition ();
			}
		}

		void update_shadow_size ()
		{
			if (shadow_update_timeout != 0)
				Source.remove (shadow_update_timeout);

			shadow_update_timeout = Timeout.add (500, () => {
				var rect = window.get_outer_rect ();
				var effect = get_effect ("shadow") as ShadowEffect;
				effect.update_size (rect.width, rect.height);

				shadow_update_timeout = 0;

				// if there was a size change it makes sense to recalculate the positions
				request_reposition ();

				return false;
			});
		}

		public void transition_to_original_state (bool animate = true)
		{
			var outer_rect = window.get_outer_rect ();

			float offset_x = 0, offset_y = 0;

			var parent = get_parent ();
			if (parent != null)
				parent.get_transformed_position (out offset_x, out offset_y);

			set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
			set_easing_duration (animate ? 300 : 0);

			set_position (outer_rect.x - offset_x, outer_rect.y - offset_y);
			set_size (outer_rect.width, outer_rect.height);

			window_icon.opacity = 0;
		}

		public void take_slot (Meta.Rectangle rect)
		{
			slot = rect;

			set_easing_duration (250);
			set_easing_mode (AnimationMode.EASE_OUT_QUAD);

			set_size (rect.width, rect.height);
			set_position (rect.x, rect.y);

			window_icon.opacity = 255;
		}

		public override void allocate (ActorBox box, AllocationFlags flags)
		{
			base.allocate (box, flags);

			foreach (var child in get_children ()) {
				if (child != clone && child != active_shape)
					child.allocate_preferred_size (flags);
			}

			ActorBox shape_alloc = {
				-ACTIVE_SHAPE_SIZE,
				-ACTIVE_SHAPE_SIZE,
				box.get_width () + ACTIVE_SHAPE_SIZE,
				box.get_height () + ACTIVE_SHAPE_SIZE
			};
			active_shape.allocate (shape_alloc, flags);

			if (clone == null)
				return;

			var actor = window.get_compositor_private () as WindowActor;
			var input_rect = window.get_input_rect ();
			var outer_rect = window.get_outer_rect ();
			var scale_factor = (float)width / outer_rect.width;

			var shadow_effect = get_effect ("shadow") as ShadowEffect;
			shadow_effect.scale_factor = scale_factor;

			var alloc = ActorBox ();
			alloc.set_origin ((input_rect.x - outer_rect.x) * scale_factor,
			                  (input_rect.y - outer_rect.y) * scale_factor);
			alloc.set_size (actor.width * scale_factor, actor.height * scale_factor);

			clone.allocate (alloc, flags);
		}

		public void place_widgets (int dest_width, int dest_height)
		{
			Granite.CloseButtonPosition pos;
			Granite.Widgets.Utils.get_default_close_button_position (out pos);

			close_button.save_easing_state ();
			close_button.set_easing_duration (0);

			close_button.y = -close_button.height * 0.25f;

			switch (pos) {
				case Granite.CloseButtonPosition.RIGHT:
					close_button.x = dest_width + close_button.width * 0.25f;
					break;
				case Granite.CloseButtonPosition.LEFT:
					close_button.x = -close_button.width * 0.25f;
					break;
			}
			close_button.restore_easing_state ();

			window_icon.save_easing_state ();
			window_icon.set_easing_duration (0);

			window_icon.x = (dest_width - WINDOW_ICON_SIZE) / 2;
			window_icon.y = dest_height - WINDOW_ICON_SIZE * 0.75f;

			window_icon.restore_easing_state ();
		}

		void close_window ()
		{
			check_confirm_dialog_cb = window.get_workspace ().window_added.connect (check_confirm_dialog);

			window.delete (window.get_screen ().get_display ().get_current_time ());
		}

		void check_confirm_dialog (Meta.Window new_window)
		{
			if (new_window.get_transient_for () == window) {
				Idle.add (() => {
					selected ();
					return false;
				});

				SignalHandler.disconnect (window.get_workspace (), check_confirm_dialog_cb);
				check_confirm_dialog_cb = 0;
			}
		}

		void unmanaged ()
		{
			if (drag_action.dragging)
				drag_action.cancel ();

			if (clone != null)
				clone.destroy ();

			if (check_confirm_dialog_cb != 0) {
				SignalHandler.disconnect (window.get_workspace (), check_confirm_dialog_cb);
				check_confirm_dialog_cb = 0;
			}

			destroy ();
		}

		Actor drag_begin (float click_x, float click_y)
		{
			float abs_x, abs_y;
			get_transformed_position (out abs_x, out abs_y);

			prev_parent = get_parent ();
			prev_index = prev_parent.get_children ().index (this);
			reparent (get_stage ());

			save_easing_state ();
			set_easing_duration (200);
			set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
			set_scale (0.4, 0.4);
			restore_easing_state ();

			request_reposition ();

			save_easing_state ();
			set_easing_duration (0);
			set_position (abs_x, abs_y);
			set_pivot_point ((click_x - abs_x) / width, (click_y - abs_y) / height);

			return this;
		}

		void drag_destination_crossed (Actor destination, bool hovered)
		{
			if (!(destination is IconGroup))
				return;

			var icon_group = destination as IconGroup;

			if (icon_group.workspace == window.get_workspace ()
				&& window.get_monitor () == window.get_screen ().get_primary_monitor ())
				return;

			var scale = hovered ? 0.1 : 0.4;
			var opacity = hovered ? 100 : 255;
			var mode = hovered ? AnimationMode.EASE_IN_OUT_BACK : AnimationMode.EASE_OUT_ELASTIC;

			save_easing_state ();

			set_easing_mode (mode);
			set_easing_duration (300);
			set_scale (scale, scale);

			set_easing_mode (AnimationMode.LINEAR);
			set_opacity (opacity);

			restore_easing_state ();

			if (hovered) {
				icon_group.add_window (window, false, true);
			} else {
				icon_group.remove_window (window);
			}
		}

		void drag_end (Actor destination)
		{
			Meta.Workspace workspace = null;

			if (destination is IconGroup) {
				workspace = (destination as IconGroup).workspace;
			} else if (destination is FramedBackground) {
				workspace = (destination.get_parent () as WorkspaceClone).workspace;
			} else if (destination is MonitorClone) {
				window.move_to_monitor ((destination as MonitorClone).monitor);
				unmanaged ();
				return;
			}

			bool did_move = false;

			var primary = window.get_screen ().get_primary_monitor ();
			if (window.get_monitor () != primary) {
				window.move_to_monitor (primary);
				did_move = true;
			}

			if (workspace != null && workspace != window.get_workspace ()) {
				window.change_workspace (workspace);
				did_move = true;
			}

			if (did_move)
				unmanaged ();
			else
				// if we're dropped at the place where we came from interpret as cancel
				drag_canceled ();
		}

		void drag_canceled ()
		{
			get_parent ().remove_child (this);
			prev_parent.insert_child_at_index (this, prev_index);

			save_easing_state ();
			set_easing_duration (400);
			set_easing_mode (AnimationMode.EASE_OUT_BOUNCE);
			set_scale (1, 1);

			request_reposition ();

			restore_easing_state ();
			restore_easing_state ();

			opacity = 255;
		}
	}

	public class TiledWorkspaceContainer : Actor
	{
		public signal void window_selected (Meta.Window window);

		public int padding_top { get; set; default = 12; }
		public int padding_left { get; set; default = 12; }
		public int padding_right { get; set; default = 12; }
		public int padding_bottom { get; set; default = 12; }

		HashTable<int,int> _stacking_order;
		public HashTable<int,int> stacking_order {
			get {
				return _stacking_order;
			}
			set {
				_stacking_order = value;
				restack ();
			}
		}

		bool _opened;
		public bool opened {
			get {
				return _opened;
			}
			set {
				if (value == _opened)
					return;

				_opened = value;

				if (_opened) {
					// hide the highlight when opened
					if (_current_window != null)
						_current_window.active = false;

					// make sure our windows are where they belong in case they were moved
					// while were closed.
					foreach (var window in get_children ()) {
						(window as TiledWindow).transition_to_original_state (false);
					}

					restack ();
					reflow ();
				} else {
					transition_to_original_state ();
				}
			}
		}

		TiledWindow? _current_window = null;
		public Window? current_window {
			get {
				return _current_window != null ? _current_window.window : null;
			}
			set {
				foreach (var child in get_children ()) {
					if ((child as TiledWindow).window == value) {
						_current_window = child as TiledWindow;
						break;
					}
				}
			}
		}

		public TiledWorkspaceContainer (HashTable<int,int> stacking_order)
		{
			_stacking_order = stacking_order;
		}

		public void add_window (Meta.Window window, bool reflow_windows = true)
		{
			var new_window = new TiledWindow (window);
			var new_seq = stacking_order.get ((int)window.get_stable_sequence ());

			new_window.selected.connect (window_selected_cb);
			new_window.destroy.connect (window_destroyed);
			new_window.request_reposition.connect (reflow);

			var children = get_children ();
			var added = false;
			foreach (var child in children) {
				if (stacking_order.get ((int)(child as TiledWindow).window.get_stable_sequence ()) < new_seq) {
					insert_child_below (new_window, child);
					added = true;
					break;
				}
			}

			// top most or no other children
			if (!added)
				add_child (new_window);

			if (reflow_windows)
				reflow ();
		}

		public void remove_window (Meta.Window window)
		{
			foreach (var child in get_children ()) {
				if ((child as TiledWindow).window == window) {
					remove_child (child);
					break;
				}
			}

			reflow ();
		}

		void window_selected_cb (TiledWindow tiled)
		{
			window_selected (tiled.window);
		}

		void window_destroyed (Actor actor)
		{
			var window = actor as TiledWindow;

			window.destroy.disconnect (window_destroyed);
			window.selected.disconnect (window_selected_cb);

			Idle.add (() => {
				reflow ();
				return false;
			});
		}

		public void restack ()
		{
			// FIXME there is certainly a way to do this in less than n^2 steps
			foreach (var child1 in get_children ()) {
				var i = 0;
				foreach (var child2 in get_children ()) {
					int index1 = stacking_order.get ((int)(child1 as TiledWindow).window.get_stable_sequence ());
					int index2 = stacking_order.get ((int)(child2 as TiledWindow).window.get_stable_sequence ());
					if (index1 < index2) {
						set_child_at_index (child1, i);
						i++;
						break;
					}
				}
			}
		}

		public void reflow ()
		{
			if (!opened)
				return;

			var windows = new List<InternalUtils.TilableWindow?> ();
			foreach (var child in get_children ()) {
				var window = child as TiledWindow;
				windows.prepend ({ window.window.get_outer_rect (), window });
			}
			windows.reverse ();

			if (windows.length () < 1)
				return;

			Meta.Rectangle area = {
				padding_left,
				padding_top,
				(int)width - padding_left - padding_right,
				(int)height - padding_top - padding_bottom
			};

			var window_positions = InternalUtils.calculate_grid_placement (area, windows);

			foreach (var tilable in window_positions) {
				var window = (TiledWindow)tilable.id;
				window.take_slot (tilable.rect);
				window.place_widgets (tilable.rect.width, tilable.rect.height);
			}
		}

		public void select_next_window (MotionDirection direction)
		{
			if (get_n_children () < 1)
				return;

			if (_current_window == null) {
				_current_window = get_child_at_index (0) as TiledWindow;
				return;
			}

			var current_rect = _current_window.slot;

			TiledWindow? closest = null;
			foreach (var window in get_children ()) {
				if (window == _current_window)
					continue;

				var window_rect = (window as TiledWindow).slot;

				switch (direction) {
					case MotionDirection.LEFT:
						if (window_rect.x > current_rect.x)
							continue;

						// test for vertical intersection
						if (!(window_rect.y + window_rect.height < current_rect.y
							|| window_rect.y > current_rect.y + current_rect.height)) {

							if (closest != null
								&& closest.slot.x < window_rect.x)
								closest = window as TiledWindow;
							else
								closest = window as TiledWindow;
						}
						break;
					case MotionDirection.RIGHT:
						if (window_rect.x < current_rect.x)
							continue;

						// test for vertical intersection
						if (!(window_rect.y + window_rect.height < current_rect.y
							|| window_rect.y > current_rect.y + current_rect.height)) {

							if (closest != null
								&& closest.slot.x > window_rect.x)
								closest = window as TiledWindow;
							else
								closest = window as TiledWindow;
						}
						break;
					case MotionDirection.UP:
						if (window_rect.y > current_rect.y)
							continue;

						// test for horizontal intersection
						if (!(window_rect.x + window_rect.width < current_rect.x
							|| window_rect.x > current_rect.x + current_rect.width)) {

							if (closest != null
								&& closest.slot.y > window_rect.y)
								closest = window as TiledWindow;
							else
								closest = window as TiledWindow;
						}
						break;
					case MotionDirection.DOWN:
						if (window_rect.y < current_rect.y)
							continue;

						// test for horizontal intersection
						if (!(window_rect.x + window_rect.width < current_rect.x
							|| window_rect.x > current_rect.x + current_rect.width)) {

							if (closest != null
								&& closest.slot.y < window_rect.y)
								closest = window as TiledWindow;
							else
								closest = window as TiledWindow;
						}
						break;
				}
			}

			if (closest == null)
				return;

			if (_current_window != null)
				_current_window.active = false;

			closest.active = true;
			_current_window = closest;
		}

		public void activate_selected_window ()
		{
			if (_current_window != null)
				_current_window.selected ();
		}

		void transition_to_original_state ()
		{
			foreach (var child in get_children ()) {
				var clone = child as TiledWindow;
				clone.transition_to_original_state ();
			}
		}
	}
}

