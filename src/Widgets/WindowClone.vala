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
	 * A container for a clone of the texture of a MetaWindow, a WindowIcon,
	 * a close button and a shadow. Used together with the WindowCloneContainer.
	 */
	public class WindowClone : Actor
	{
		const int WINDOW_ICON_SIZE = 64;
		const int ACTIVE_SHAPE_SIZE = 12;

		/**
		 * The window was selected. The MultitaskingView should consider activating
		 * the window and closing the view.
		 */
		public signal void selected ();

		/**
		 * The window was moved or resized and a relayout of the tiling layout may
		 * be sensible right now.
		 */
		public signal void request_reposition ();

		public Meta.Window window { get; construct; }

		/**
		 * The currently assigned slot of the window in the tiling layout. May be null.
		 */
		public Meta.Rectangle? slot { get; private set; default = null; }

		public bool dragging { get; private set; default = false; }

		bool _active = false;
		/**
		 * When active fades a white border around the window in. Used for the visually
		 * indicating the WindowCloneContainer's current_window.
		 */
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

		public bool overview_mode { get; construct; }

		DragDropAction? drag_action = null;
		Clone? clone = null;

		Actor prev_parent = null;
		int prev_index = -1;
		ulong check_confirm_dialog_cb = 0;
		uint shadow_update_timeout = 0;

		Actor close_button;
		Actor active_shape;
		GtkClutter.Texture window_icon;

		public WindowClone (Meta.Window window, bool overview_mode = false)
		{
			Object (window: window, overview_mode: overview_mode);
		}

		construct
		{
			reactive = true;

			window.unmanaged.connect (unmanaged);
			window.notify["on-all-workspaces"].connect (on_all_workspaces_changed);

			if (overview_mode) {
				var click_action = new ClickAction ();
				click_action.clicked.connect (() => {
					actor_clicked (click_action.get_button ());
				});

				add_action (click_action);
			} else {
				drag_action = new DragDropAction (DragDropActionType.SOURCE, "multitaskingview-window");
				drag_action.drag_begin.connect (drag_begin);
				drag_action.destination_crossed.connect (drag_destination_crossed);
				drag_action.drag_end.connect (drag_end);
				drag_action.drag_canceled.connect (drag_canceled);
				drag_action.actor_clicked.connect (actor_clicked);

				add_action (drag_action);
			}

			close_button = Utils.create_close_button ();
			close_button.opacity = 0;
			close_button.set_easing_duration (200);
			close_button.button_press_event.connect (() => {
				close_window ();
				return true;
			});

			window_icon = new WindowIcon (window, WINDOW_ICON_SIZE);
			window_icon.opacity = 0;
			window_icon.set_pivot_point (0.5f, 0.5f);

			active_shape = new Clutter.Actor ();
			active_shape.background_color = { 255, 255, 255, 200 };
			active_shape.opacity = 0;

			add_child (active_shape);
			add_child (window_icon);
			add_child (close_button);

			load_clone ();
		}

		~WindowClone ()
		{
			window.unmanaged.disconnect (unmanaged);
			window.notify["on-all-workspaces"].disconnect (on_all_workspaces_changed);

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

		/**
		 * Waits for the texture of a new WindowActor to be available
		 * and makes a close of it. If it was already was assigned a slot
		 * at this point it will animate to it. Otherwise it will just place
		 * itself at the location of the original window. Also adds the shadow
		 * effect and makes sure the shadow is updated on size changes.
		 *
		 * @param was_waiting Internal argument used to indicate that we had to 
		 *                    wait before the window's texture became available.
		 */
		void load_clone (bool was_waiting = false)
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

			if (overview_mode)
				actor.hide ();

			clone = new Clone (actor.get_texture ());
			add_child (clone);

			set_child_below_sibling (active_shape, clone);
			set_child_above_sibling (close_button, clone);
			set_child_above_sibling (window_icon, clone);

			transition_to_original_state (false);

#if HAS_MUTTER312
			var outer_rect = window.get_frame_rect ();
#else
			var outer_rect = window.get_outer_rect ();
#endif
			add_effect_with_name ("shadow", new ShadowEffect (outer_rect.width, outer_rect.height, 40, 5));
#if HAS_MUTTER312
			window.size_changed.connect (update_shadow_size);
#else
			actor.size_changed.connect (update_shadow_size);
#endif

			if (should_fade ())
				opacity = 0;

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

		/**
		 * If we are in overview mode, we may display windows from workspaces other than
		 * the current one. To ease their appearance we have to fade them in.
		 */
		bool should_fade ()
		{
			return overview_mode
				&& window.get_workspace () != window.get_screen ().get_active_workspace ();
		}

		/**
		 * Sets a timeout of 500ms after which, if no new resize action reset it,
		 * the shadow will be resized and a request_reposition() will be emitted to
		 * make the WindowCloneContainer calculate a new layout to honor the new size.
		 */
		void update_shadow_size ()
		{
			if (shadow_update_timeout != 0)
				Source.remove (shadow_update_timeout);

			shadow_update_timeout = Timeout.add (500, () => {
#if HAS_MUTTER312
				var rect = window.get_frame_rect ();
#else
				var rect = window.get_outer_rect ();
#endif
				var effect = get_effect ("shadow") as ShadowEffect;
				effect.update_size (rect.width, rect.height);

				shadow_update_timeout = 0;

				// if there was a size change it makes sense to recalculate the positions
				request_reposition ();

				return false;
			});
		}

		void on_all_workspaces_changed ()
		{
			// we don't display windows that are on all workspaces
			if (window.on_all_workspaces)
				unmanaged ();
		}

		/**
		 * Place the window at the location of the original MetaWindow
		 *
		 * @param animate Animate the transformation of the placement
		 */
		public void transition_to_original_state (bool animate)
		{
#if HAS_MUTTER312
			var outer_rect = window.get_frame_rect ();
#else
			var outer_rect = window.get_outer_rect ();
#endif

			float offset_x = 0, offset_y = 0;

			var parent = get_parent ();
			if (parent != null) {
				// in overview_mode the parent has just been added to the stage, so the
				// transforme position is not set yet. However, the set position is correct
				// for overview anyway, so we can just use that.
				if (overview_mode)
					parent.get_position (out offset_x, out offset_y);
				else
					parent.get_transformed_position (out offset_x, out offset_y);
			}

			set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
			set_easing_duration (animate ? 300 : 0);

			set_position (outer_rect.x - offset_x, outer_rect.y - offset_y);
			set_size (outer_rect.width, outer_rect.height);

			window_icon.opacity = 0;

			if (should_fade ())
				opacity = 0;
		}

		/**
		 * Animate the window to the given slot
		 */
		public void take_slot (Meta.Rectangle rect)
		{
			slot = rect;

			set_easing_duration (250);
			set_easing_mode (AnimationMode.EASE_OUT_QUAD);

			set_size (rect.width, rect.height);
			set_position (rect.x, rect.y);

			window_icon.opacity = 255;

			// for overview mode, windows may be faded out initially. Make sure
			// to fade those in.
			if (overview_mode) {
				save_easing_state ();
				set_easing_mode (AnimationMode.EASE_OUT_QUAD);
				set_easing_duration (300);

				opacity = 255;
				restore_easing_state ();
			}
		}

		/**
		 * Except for the texture clone and the highlight all children are placed
		 * according to their given allocations. The first two are placed in a way
		 * that compensates for invisible borders of the texture.
		 */
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
#if HAS_MUTTER314
			var input_rect = window.get_buffer_rect ();
#else
			var input_rect = window.get_input_rect ();
#endif
#if HAS_MUTTER312
			var outer_rect = window.get_frame_rect ();
#else
			var outer_rect = window.get_outer_rect ();
#endif
			var scale_factor = (float)width / outer_rect.width;

			var shadow_effect = get_effect ("shadow") as ShadowEffect;
			shadow_effect.scale_factor = scale_factor;

			var alloc = ActorBox ();
			alloc.set_origin ((input_rect.x - outer_rect.x) * scale_factor,
			                  (input_rect.y - outer_rect.y) * scale_factor);
			alloc.set_size (actor.width * scale_factor, actor.height * scale_factor);

			clone.allocate (alloc, flags);
		}

		public override bool button_press_event (Clutter.ButtonEvent event)
		{
			return true;
		}

		public override	bool enter_event (Clutter.CrossingEvent event)
		{
			close_button.opacity = 255;

			return false;
		}
		
		public override	bool leave_event (Clutter.CrossingEvent event)
		{
			close_button.opacity = 0;

			return false;
		}

		/**
		 * Place the widgets, that is the close button and the WindowIcon of the window,
		 * at their positions inside the actor for a given width and height.
		 */
		public void place_widgets (int dest_width, int dest_height)
		{
			Granite.CloseButtonPosition pos;
			Granite.Widgets.Utils.get_default_close_button_position (out pos);

			close_button.save_easing_state ();
			close_button.set_easing_duration (0);

			close_button.y = -close_button.height * 0.33f;

			switch (pos) {
				case Granite.CloseButtonPosition.RIGHT:
					close_button.x = dest_width - close_button.width * 0.5f;
					break;
				case Granite.CloseButtonPosition.LEFT:
					close_button.x = -close_button.width * 0.5f;
					break;
			}
			close_button.restore_easing_state ();

			if (!dragging) {
				window_icon.save_easing_state ();
				window_icon.set_easing_duration (0);

				window_icon.set_position ((dest_width - WINDOW_ICON_SIZE) / 2, dest_height - WINDOW_ICON_SIZE * 0.75f);

				window_icon.restore_easing_state ();
			}
		}

		/**
		 * Send the window the delete signal and listen for new windows to be added
		 * to the window's workspace, in which case we check if the new window is a
		 * dialog of the window we were going to delete. If that's the case, we request
		 * to select our window.
		 */
		void close_window ()
		{
			var screen = window.get_screen ();
			check_confirm_dialog_cb = screen.window_entered_monitor.connect (check_confirm_dialog);

			window.@delete (screen.get_display ().get_current_time ());
		}

		void check_confirm_dialog (int monitor, Meta.Window new_window)
		{
			if (new_window.get_transient_for () == window) {
				Idle.add (() => {
					selected ();
					return false;
				});

				SignalHandler.disconnect (window.get_screen (), check_confirm_dialog_cb);
				check_confirm_dialog_cb = 0;
			}
		}

		/**
		 * The window unmanaged by the compositor, so we need to destroy ourselves too.
		 */
		void unmanaged ()
		{
			if (drag_action != null && drag_action.dragging)
				drag_action.cancel ();

			if (clone != null)
				clone.destroy ();

			if (check_confirm_dialog_cb != 0) {
				SignalHandler.disconnect (window.get_screen (), check_confirm_dialog_cb);
				check_confirm_dialog_cb = 0;
			}

			if (shadow_update_timeout != 0) {
				Source.remove (shadow_update_timeout);
				shadow_update_timeout = 0;
			}

			destroy ();
		}

		void actor_clicked (uint32 button) {
			switch (button) {
				case 1:
					selected ();
					break;
				case 2:
					close_window ();
					break;
			}
		}

		/**
		 * A drag action has been initiated on us, we reparent ourselves to the stage so
		 * we can move freely, scale ourselves to a smaller scale and request that the
		 * position we just freed is immediately filled by the WindowCloneContainer.
		 */
		Actor drag_begin (float click_x, float click_y)
		{
			float abs_x, abs_y;

			prev_parent = get_parent ();
			prev_index = prev_parent.get_children ().index (this);

			var stage = get_stage ();
			prev_parent.remove_child (this);
			stage.add_child (this);

			var scale = window_icon.width / clone.width;

			((ShadowEffect) get_effect ("shadow")).shadow_opacity = 0;

			clone.get_transformed_position (out abs_x, out abs_y);
			clone.set_pivot_point ((click_x - abs_x) / clone.width, (click_y - abs_y) / clone.height);
			clone.save_easing_state ();
			clone.set_easing_duration (200);
			clone.set_easing_mode (AnimationMode.EASE_IN_CUBIC);
			clone.set_scale (scale, scale);
			clone.opacity = 0;
			clone.restore_easing_state ();

			request_reposition ();

			get_transformed_position (out abs_x, out abs_y);

			save_easing_state ();
			set_easing_duration (0);
			set_position (abs_x, abs_y);

			window_icon.save_easing_state ();
			window_icon.set_easing_duration (200);
			window_icon.set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
			window_icon.set_position (click_x - abs_x - window_icon.width / 2, click_y - abs_y - window_icon.height / 2);
			window_icon.restore_easing_state ();

			close_button.opacity = 0;

			dragging = true;

			return this;
		}

		/**
		 * When we cross an IconGroup, we animate to an even smaller size and slightly
		 * less opacity and add ourselves as temporary window to the group. When left, 
		 * we reverse those steps.
		 */
		void drag_destination_crossed (Actor destination, bool hovered)
		{
			IconGroup? icon_group = destination as IconGroup;
			WorkspaceInsertThumb? insert_thumb = destination as WorkspaceInsertThumb;

			// if we have don't dynamic workspace, we don't allow inserting
			if (icon_group == null && insert_thumb == null
				|| (insert_thumb != null && !Prefs.get_dynamic_workspaces ()))
				return;

			// for an icon group, we only do animations if there is an actual movement possible
			if (icon_group != null
				&& icon_group.workspace == window.get_workspace ()
				&& window.get_monitor () == window.get_screen ().get_primary_monitor ())
				return;

			var scale = hovered ? 0.4 : 1.0;
			var opacity = hovered ? 0 : 255;
			var duration = hovered && insert_thumb != null ? WorkspaceInsertThumb.EXPAND_DELAY : 100;

			window_icon.save_easing_state ();

			window_icon.set_easing_mode (AnimationMode.LINEAR);
			window_icon.set_easing_duration (duration);
			window_icon.set_scale (scale, scale);
			window_icon.set_opacity (opacity);

			window_icon.restore_easing_state ();

			if (insert_thumb != null) {
				insert_thumb.set_window_thumb (window);
			}

			if (icon_group != null) {
				if (hovered)
					icon_group.add_window (window, false, true);
				else
					icon_group.remove_window (window);
			}
		}

		/**
		 * Depending on the destination we have different ways to find the correct destination.
		 * After we found one we destroy ourselves so the dragged clone immediately disappears,
		 * otherwise we cancel the drag and animate back to our old place.
		 */
		void drag_end (Actor destination)
		{
			Meta.Workspace workspace = null;
			var primary = window.get_screen ().get_primary_monitor ();

			if (destination is IconGroup) {
				workspace = ((IconGroup) destination).workspace;
			} else if (destination is FramedBackground) {
				workspace = ((WorkspaceClone) destination.get_parent ()).workspace;
			} else if (destination is WorkspaceInsertThumb) {
				if (!Prefs.get_dynamic_workspaces ()) {
					drag_canceled ();
					return;
				}

				unowned WorkspaceInsertThumb inserter = (WorkspaceInsertThumb) destination;

				var will_move = window.get_workspace ().index () != inserter.workspace_index;

				if (Prefs.get_workspaces_only_on_primary () && window.get_monitor () != primary) {
					window.move_to_monitor (primary);
					will_move = true;
				}

				InternalUtils.insert_workspace_with_window (inserter.workspace_index, window);

				// if we don't actually change workspaces, the window-added/removed signals won't
				// be emitted so we can just keep our window here
				if (!will_move)
					drag_canceled ();
				else
					unmanaged ();

				return;
			} else if (destination is MonitorClone) {
				var monitor = ((MonitorClone) destination).monitor;
				if (window.get_monitor () != monitor) {
					window.move_to_monitor (monitor);
					unmanaged ();
				} else
					drag_canceled ();

				return;
			}

			bool did_move = false;

			if (Prefs.get_workspaces_only_on_primary () && window.get_monitor () != primary) {
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

		/**
		 * Animate back to our previous position with a bouncing animation.
		 */
		void drag_canceled ()
		{
			get_parent ().remove_child (this);
			prev_parent.insert_child_at_index (this, prev_index);

			clone.save_easing_state ();
			clone.set_easing_duration (250);
			clone.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
			clone.set_scale (1, 1);
			clone.opacity = 255;

			Clutter.Callback finished = () => {
				((ShadowEffect) get_effect ("shadow")).shadow_opacity = 255;
			};

			var transition = clone.get_transition ("scale-x");
			if (transition != null)
				transition.completed.connect (() => finished (this));
			else
				finished (this);

			clone.restore_easing_state ();

			request_reposition ();

			// pop 0 animation duration from drag_begin()
			restore_easing_state ();

			window_icon.save_easing_state ();
			window_icon.set_easing_duration (250);
			window_icon.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
			window_icon.set_position ((slot.width - WINDOW_ICON_SIZE) / 2, slot.height - WINDOW_ICON_SIZE * 0.75f);
			window_icon.restore_easing_state ();

			dragging = false;
		}
	}
}

