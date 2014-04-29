using Clutter;
using Meta;

namespace Gala
{
	public class TiledWindow : Actor
	{
		public signal void selected ();
		public signal void request_reposition ();

		public Meta.Window window { get; construct; }

		DragDropAction drag_action;
		Clone? clone = null;

		Actor prev_parent = null;
		int prev_index = -1;

		public TiledWindow (Meta.Window window)
		{
			Object (window: window);

			reactive = true;

			load_clone ();

			window.unmanaged.connect (unmanaged);

			drag_action = new DragDropAction (DragDropActionType.SOURCE, "multitaskingview-window");
			drag_action.drag_begin.connect (drag_begin);
			drag_action.destination_crossed.connect (drag_destination_crossed);
			drag_action.drag_end.connect (drag_end);
			drag_action.drag_canceled.connect (drag_canceled);
			drag_action.actor_clicked.connect (() => { selected (); });

			add_action (drag_action);
		}

		~TiledWindow ()
		{
			window.unmanaged.disconnect (unmanaged);
		}

		public void load_clone ()
		{
			var actor = window.get_compositor_private () as WindowActor;
			if (actor == null) {
				Idle.add (() => {
					if (window.get_compositor_private () != null)
						load_clone ();
					return false;
				});

				return;
			}

			clone = new Clone (actor);
			clone.add_constraint (new BindConstraint (this, BindCoordinate.SIZE, 0));
			add_child (clone);

			set_easing_duration (250);
			set_easing_mode (AnimationMode.EASE_OUT_QUAD);
			set_position (actor.x, actor.y);

			request_reposition ();
		}

		public void transition_to_original_state ()
		{
			var actor = window.get_compositor_private () as Actor;

			set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
			set_easing_duration (300);
			set_size (actor.width, actor.height);
			set_position (actor.x, actor.y);
		}

		void unmanaged ()
		{
			if (drag_action.dragging)
				drag_action.cancel ();

			if (clone != null)
				clone.destroy ();
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

			var scale = hovered ? 0.2 : 0.4;
			var opacity = hovered ? 100 : 255;
			var mode = hovered ? AnimationMode.EASE_IN_OUT_BACK : AnimationMode.EASE_OUT_ELASTIC;

			save_easing_state ();

			set_easing_mode (mode);
			set_easing_duration (300);
			set_scale (scale, scale);

			set_easing_mode (AnimationMode.LINEAR);
			set_opacity (opacity);

			restore_easing_state ();
		}

		void drag_end (Actor destination)
		{
			Meta.Workspace workspace = null;

			if (destination is IconGroup) {
				workspace = (destination as IconGroup).workspace;
			} else if (destination is FramedBackground) {
				workspace = (destination.get_parent () as WorkspaceClone).workspace;
			}

			if (workspace != null && workspace != window.get_workspace ()) {
				window.change_workspace (workspace);
				unmanaged ();
			} else {
				// if we're dropped at the place where we came from interpret as cancel
				drag_canceled ();
			}
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

		public int padding_top { get; set; }
		public int padding_left { get; set; }
		public int padding_right { get; set; }
		public int padding_bottom { get; set; }

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

			var result = InternalUtils.calculate_grid_placement (area, windows);

			foreach (var tilable in result) {
				var window = (TiledWindow)tilable.id;
				window.set_position (tilable.rect.x, tilable.rect.y);
				window.set_size (tilable.rect.width, tilable.rect.height);
			}
		}

		public void transition_to_original_state ()
		{
			foreach (var child in get_children ()) {
				var clone = child as TiledWindow;
				clone.transition_to_original_state ();
			}
		}
	}
}

