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
		public DragDropActionType drag_type { get; construct; }
		public string drag_id { get; construct; }
		public Clutter.Actor handle { get; private set; }

		Clutter.Actor? hovered = null;
		bool clicked = false;
		bool dragging = false;

		/**
		 * A drag has been started. You have to connect to this signal
		 * @return A ClutterActor that serves as handle
		 */
		public signal Clutter.Actor drag_begin ();

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
		 * Create a new DragDropAction
		 *
		 * @param type The type of this actor
		 * @param id An ID that marks which sources can be dragged on
		 *     which destinations. It has to be the same for all actors that
		 *     should be compatible with each other.
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
				actor.motion_event.disconnect (source_motion);
			}
		}

		void connect_actor (Clutter.Actor actor)
		{
			if (drag_type == DragDropActionType.SOURCE) {
				actor.button_press_event.connect (source_clicked);
				actor.motion_event.connect (source_motion);
			}
		}

		bool source_clicked (Clutter.ButtonEvent event)
		{
			if (event.button != 1)
				return false;

			clicked = true;
			return true;
		}

		bool source_motion (Clutter.MotionEvent event)
		{
			if (!clicked)
				return false;

			handle = drag_begin ();
			if (handle == null) {
				critical ("No handle has been returned by the started signal, aborting drag.");
				return false;
			}

			dragging = true;
			clicked = false;
			actor.get_stage ().captured_event.connect (follow_move);
			return true;
		}

		bool follow_move (Clutter.Event event)
		{
			switch (event.get_type ()) {
				case Clutter.EventType.KEY_PRESS:
					if (event.get_key_code () == Clutter.Key.Escape) {
						cancel ();
					}
					return true;
				case Clutter.EventType.MOTION:
					float x, y;
					event.get_coords (out x, out y);
					handle.x = x;
					handle.y = y;

					var actor = actor.get_stage ().get_actor_at_pos (Clutter.PickMode.REACTIVE, (int)x, (int)y);
					DragDropAction action = null;
					if (actor == null || (action = get_drag_drop_action (actor)) == null) {
						if (hovered != null) {
							get_drag_drop_action (hovered).crossed (false);
							hovered = null;
						}
						return true;
					}

					if (hovered != null) {
						get_drag_drop_action (hovered).crossed (false);
					}

					hovered = actor;
					action.crossed (true);

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

			drag_canceled ();
			dragging = false;
		}

		void finish ()
		{
			// make sure they reset the style or whatever they changed when hovered
			get_drag_drop_action (hovered).crossed (false);

			actor.get_stage ().captured_event.disconnect (follow_move);
			drag_end (hovered);
		}
	}
}
