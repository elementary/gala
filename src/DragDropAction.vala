//
//  Copyright (C) 2013 Tom Beckmann
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

namespace Gala
{
	public enum DragDropActionType
	{
		SOURCE = 0,
		DESTINATION
	}

	public class DragDropAction : Clutter.Action
	{
		/**
		 * A drag has been started. You have to connect to this signal and
		 * return an actor that is transformed during the drag operation.
		 *
		 * @param x The global x coordinate where the action was activated
		 * @param y The global y coordinate where the action was activated
		 * @return  A ClutterActor that serves as handle
		 */
		public signal Clutter.Actor drag_begin (float x, float y);

		/**
		 * A drag has been canceled. You may want to consider cleaning up
		 * your handle.
		 */
		public signal void drag_canceled ();

		/**
		 * A drag action has successfully been finished.
		 *
		 * @param actor The actor on which the drag finished
		 */
		public signal void drag_end (Clutter.Actor actor);

		/**
		 * The destination has been crossed
		 *
		 * @param hovered indicates whether the actor is now hovered or not
		 */
		public signal void crossed (bool hovered);

		/**
		 * Emitted on the source when a destination is crossed.
		 *
		 * @param destination The destination actor that has been crossed
		 * @param hovered     Whether the actor is now hovered or has just been left
		 */
		public signal void destination_crossed (Clutter.Actor destination, bool hovered);

		/**
		 * The source has been clicked, but the movement was not larger than
		 * the drag threshold. Useful if the source is also activable.
		 *
		 * @param button The button which was pressed
		 */
		public signal void actor_clicked (uint32 button);

		/**
		 * The type of the action
		 */
		public DragDropActionType drag_type { get; construct; }

		/**
		 * The unique id given to this drag-drop-group
		 */		 
		public string drag_id { get; construct; }

		public Clutter.Actor handle { get; private set; }
		/**
		 * Indicates whether a drag action is currently active
		 */
		public bool dragging { get; private set; default = false; }

		/**
		 * Allow checking the parents of reactive children if they are valid destinations
		 * if the child is none
		 */
		public bool allow_bubbling { get; set; default = true; }

		Clutter.Actor? hovered = null;
		bool clicked = false;
		bool actor_was_reactive = false;
		float last_x;
		float last_y;

		/**
		 * Create a new DragDropAction
		 *
		 * @param type The type of this actor
		 * @param id   An ID that marks which sources can be dragged on
		 *             which destinations. It has to be the same for all actors that
		 *             should be compatible with each other.
		 */
		public DragDropAction (DragDropActionType type, string id)
		{
			Object (drag_type : type, drag_id : id);
		}

		~DragDropAction ()
		{
			if (actor != null)
				release_actor (actor);
		}

		public override void set_actor (Clutter.Actor? new_actor)
		{
			if (actor != null) {
				release_actor (actor);
			}

			if (new_actor != null) {
				connect_actor (new_actor);
			}

			base.set_actor (new_actor);
		}

		void release_actor (Clutter.Actor actor)
		{
			if (drag_type == DragDropActionType.SOURCE) {
				actor.button_press_event.disconnect (source_clicked);
			}
		}

		void connect_actor (Clutter.Actor actor)
		{
			if (drag_type == DragDropActionType.SOURCE) {
				actor.button_press_event.connect (source_clicked);
			}
		}

		void emit_crossed (Clutter.Actor destination, bool hovered)
		{
			get_drag_drop_action (destination).crossed (hovered);
			destination_crossed (destination, hovered);
		}

		bool source_clicked (Clutter.ButtonEvent event)
		{
			if (event.button != 1) {
				actor_clicked (event.button);
				return false;
			}

			actor.get_stage ().captured_event.connect (follow_move);
			clicked = true;
			last_x = event.x;
			last_y = event.y;

			return true;
		}

		bool follow_move (Clutter.Event event)
		{
			// still determining if we actually want to start a drag action
			if (!dragging) {
				switch (event.get_type ()) {
					case Clutter.EventType.MOTION:
						float x, y;
						event.get_coords (out x, out y);

						var drag_threshold = Clutter.Settings.get_default ().dnd_drag_threshold;
						if (Math.fabsf (last_x - x) > drag_threshold || Math.fabsf (last_y - y) > drag_threshold) {
							handle = drag_begin (x, y);
							if (handle == null) {
								actor.get_stage ().captured_event.disconnect (follow_move);
								critical ("No handle has been returned by the started signal, aborting drag.");
								return false;
							}

							actor_was_reactive = handle.reactive;
							handle.reactive = false;

							clicked = false;
							dragging = true;
						}
						return true;
					case Clutter.EventType.BUTTON_RELEASE:
						float x, y, ex, ey;
						event.get_coords (out ex, out ey);
						actor.get_transformed_position (out x, out y);

						// release has happened within bounds of actor
						if (x < ex && x + actor.width > ex && y < ey && y + actor.height > ey) {
							actor_clicked (event.get_button ());
						}

						actor.get_stage ().captured_event.disconnect (follow_move);
						clicked = false;
						dragging = false;
						return true;
					default:
						return true;
				}
			}

			switch (event.get_type ()) {
				case Clutter.EventType.KEY_PRESS:
					if (event.get_key_code () == Clutter.Key.Escape) {
						cancel ();
					}
					return true;
				case Clutter.EventType.MOTION:
					float x, y;
					event.get_coords (out x, out y);
					handle.x -= last_x - x;
					handle.y -= last_y - y;
					last_x = x;
					last_y = y;

					var stage = actor.get_stage ();
					var actor = actor.get_stage ().get_actor_at_pos (Clutter.PickMode.REACTIVE, (int)x, (int)y);
					DragDropAction action = null;
					// if we're allowed to bubble and we this actor is not a destination, check its parents
					if (actor != null && (action = get_drag_drop_action (actor)) == null && allow_bubbling) {
						while ((actor = actor.get_parent ()) != stage) {
							if ((action = get_drag_drop_action (actor)) != null)
								break;
						}
					}

					// didn't change, no need to do anything
					if (actor == hovered)
						return true;

					if (action == null) {
						// apparently we left ours if we had one before
						if (hovered != null) {
							emit_crossed (hovered, false);
							hovered = null;
						}

						return true;
					}

					// signal the previous one that we left it
					if (hovered != null) {
						emit_crossed (hovered, false);
					}

					// tell the new one that it is hovered
					hovered = actor;
					emit_crossed (hovered, true);

					return true;
				case Clutter.EventType.BUTTON_RELEASE:
					if (hovered != null) {
						finish ();
					} else {
						cancel ();
					}
					return true;
				case Clutter.EventType.ENTER:
				case Clutter.EventType.LEAVE:
					return true;
			}

			return false;
		}

		/**
		 * Looks for a DragDropAction instance if this actor has one or NULL.
		 * It also checks if it is a DESTINATION and if the id matches
		 *
		 * @return the DragDropAction instance on this actor or NULL
		 */
		DragDropAction? get_drag_drop_action (Clutter.Actor actor)
		{
			DragDropAction? drop_action = null;

			foreach (var action in actor.get_actions ()) {
				drop_action = action as DragDropAction;
				if (drop_action == null
					|| drop_action.drag_type != DragDropActionType.DESTINATION
					|| drop_action.drag_id != drag_id)
					continue;

				return drop_action;
			}

			return null;
		}

		/**
		 * Abort the drag
		 */
		public void cancel ()
		{
			if (dragging) {
				actor.get_stage ().captured_event.disconnect (follow_move);
			}

			dragging = false;
			actor.reactive = actor_was_reactive;

			drag_canceled ();
		}

		void finish ()
		{
			// make sure they reset the style or whatever they changed when hovered
			emit_crossed (hovered, false);

			actor.get_stage ().captured_event.disconnect (follow_move);

			dragging = false;
			actor.reactive = actor_was_reactive;

			drag_end (hovered);
		}
	}
}
