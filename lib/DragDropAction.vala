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

using Clutter;

namespace Gala {
    [Flags]
    public enum DragDropActionType {
        SOURCE,
        DESTINATION
    }

    public class DragDropAction : Clutter.Action {
        private static Gee.HashMap<string,Gee.LinkedList<Actor>>? sources = null;
        private static Gee.HashMap<string,Gee.LinkedList<Actor>>? destinations = null;

        /**
         * A drag has been started. You have to connect to this signal and
         * return an actor that is transformed during the drag operation.
         *
         * @param x The global x coordinate where the action was activated
         * @param y The global y coordinate where the action was activated
         * @return  A ClutterActor that serves as handle
         */
        public signal Actor? drag_begin (float x, float y);

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
        public signal void drag_end (Actor actor);

        /**
         * The destination has been crossed
         *
         * @param target the target actor that is crossing the destination
         * @param hovered indicates whether the actor is now hovered or not
         */
        public signal void crossed (Actor? target, bool hovered);

        /**
         * Emitted on the source when a destination is crossed.
         *
         * @param destination The destination actor that has been crossed
         * @param hovered     Whether the actor is now hovered or has just been left
         */
        public signal void destination_crossed (Actor destination, bool hovered);

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

        public Actor handle { get; private set; }
        /**
         * Indicates whether a drag action is currently active
         */
        public bool dragging { get; private set; default = false; }

        /**
         * Allow checking the parents of reactive children if they are valid destinations
         * if the child is none
         */
        public bool allow_bubbling { get; set; default = true; }

        public Actor? hovered { private get; set; default = null; }

        private bool clicked = false;
        private float last_x;
        private float last_y;

        private Grab? grab = null;
        private static unowned Actor? grabbed_actor = null;
        private InputDevice? grabbed_device = null;
        private ulong on_event_id = 0;

        /**
         * Create a new DragDropAction
         *
         * @param type The type of this actor
         * @param id   An ID that marks which sources can be dragged on
         *             which destinations. It has to be the same for all actors that
         *             should be compatible with each other.
         */
        public DragDropAction (DragDropActionType type, string id) {
            Object (drag_type : type, drag_id : id);

            if (sources == null)
                sources = new Gee.HashMap<string,Gee.LinkedList<Actor>> ();

            if (destinations == null)
                destinations = new Gee.HashMap<string,Gee.LinkedList<Actor>> ();

        }

        ~DragDropAction () {
            if (actor != null)
                release_actor (actor);
        }

        public override void set_actor (Actor? new_actor) {
            if (actor != null) {
                release_actor (actor);
            }

            if (new_actor != null) {
                connect_actor (new_actor);
            }

            base.set_actor (new_actor);
        }

        private void release_actor (Actor actor) {
            if (DragDropActionType.SOURCE in drag_type) {

                var source_list = sources.@get (drag_id);
                source_list.remove (actor);
            }

            if (DragDropActionType.DESTINATION in drag_type) {
                var dest_list = destinations[drag_id];
                dest_list.remove (actor);
            }
        }

        private void connect_actor (Actor actor) {
            if (DragDropActionType.SOURCE in drag_type) {

                var source_list = sources.@get (drag_id);
                if (source_list == null) {
                    source_list = new Gee.LinkedList<Actor> ();
                    sources.@set (drag_id, source_list);
                }

                source_list.add (actor);
            }

            if (DragDropActionType.DESTINATION in drag_type) {
                var dest_list = destinations[drag_id];
                if (dest_list == null) {
                    dest_list = new Gee.LinkedList<Actor> ();
                    destinations[drag_id] = dest_list;
                }

                dest_list.add (actor);
            }
        }

        private void emit_crossed (Actor destination, bool is_hovered) {
            get_drag_drop_action (destination).crossed (actor, is_hovered);
            destination_crossed (destination, is_hovered);
        }

        public override bool handle_event (Event event) {
            if (!(DragDropActionType.SOURCE in drag_type)) {
                return Gdk.EVENT_PROPAGATE;
            }

            switch (event.get_type ()) {
                case EventType.BUTTON_PRESS:
                    if (grabbed_actor != null) {
                        return Gdk.EVENT_PROPAGATE;
                    }

                    grab_actor (actor, event.get_device ());
                    clicked = true;

                    float x, y;
                    event.get_coords (out x, out y);

                    last_x = x;
                    last_y = y;

                    return Gdk.EVENT_STOP;

                case EventType.BUTTON_RELEASE:
                    if (!dragging) {
                        float x, y, ex, ey;
                        event.get_coords (out ex, out ey);
                        actor.get_transformed_position (out x, out y);

                        // release has happened within bounds of actor
                        if (clicked && x < ex && x + actor.width > ex && y < ey && y + actor.height > ey) {
                            actor_clicked (event.get_button ());
                        }

                        if (clicked) {
                            ungrab_actor ();
                            clicked = false;
                        }

                        return Gdk.EVENT_STOP;
                    } else if (dragging) {
                        if (hovered != null) {
                            finish ();
                        } else {
                            cancel ();
                        }

                        return Gdk.EVENT_STOP;
                    }
                    break;

                default:
                    break;
            }

            return base.handle_event (event);
        }

        private void grab_actor (Actor actor, InputDevice device) {
            if (grabbed_actor != null) {
                critical ("Tried to grab an actor with a grab already in progress");
            }

            grab = actor.get_stage ().grab (actor);
            grabbed_actor = actor;
            grabbed_device = device;
            on_event_id = actor.event.connect (on_event);
        }

        private void ungrab_actor () {
            if (on_event_id == 0 || grabbed_actor == null) {
                return;
            }

            if (grab != null) {
                grab.dismiss ();
                grab = null;
            }

            grabbed_device = null;
            grabbed_actor.disconnect (on_event_id);
            on_event_id = 0;
            grabbed_actor = null;
        }

        private bool on_event (Clutter.Event event) {
            var device = event.get_device ();

            if (grabbed_device != null &&
                device != grabbed_device &&
                device.get_device_type () != InputDeviceType.KEYBOARD_DEVICE) {
                    return Gdk.EVENT_PROPAGATE;
                }

            switch (event.get_type ()) {
                case EventType.KEY_PRESS:
                    if (event.get_key_symbol () == Key.Escape) {
                        cancel ();
                    }
                    break;
                case EventType.MOTION:
                    float x, y;
                    event.get_coords (out x, out y);

                    if (!dragging && clicked) {
                        var drag_threshold = Clutter.Settings.get_default ().dnd_drag_threshold;
                        if (Math.fabsf (last_x - x) > drag_threshold || Math.fabsf (last_y - y) > drag_threshold) {
                            handle = drag_begin (x, y);
                            if (handle == null) {
                                ungrab_actor ();
                                critical ("No handle has been returned by the started signal, aborting drag.");
                                return Gdk.EVENT_PROPAGATE;
                            }

                            clicked = false;
                            dragging = true;

                            ungrab_actor ();
                            grab_actor (handle, event.get_device ());

                            var source_list = sources.@get (drag_id);
                            if (source_list != null) {
                                var dest_list = destinations[drag_id];
                                foreach (var actor in source_list) {
                                    // Do not unset reactivity on destinations
                                    if (dest_list == null || actor in dest_list) {
                                        continue;
                                    }

                                    actor.reactive = false;
                                }
                            }
                        }
                        return Gdk.EVENT_STOP;
                    } else if (dragging) {
                        handle.x -= last_x - x;
                        handle.y -= last_y - y;
                        last_x = x;
                        last_y = y;

                        var stage = actor.get_stage ();
                        var actor = stage.get_actor_at_pos (PickMode.REACTIVE, (int) x, (int) y);
                        DragDropAction action = null;
                        // if we're allowed to bubble and this actor is not a destination, check its parents
                        if (actor != null && (action = get_drag_drop_action (actor)) == null && allow_bubbling) {
                            while ((actor = actor.get_parent ()) != stage) {
                                if ((action = get_drag_drop_action (actor)) != null)
                                    break;
                            }
                        }

                        // didn't change, no need to do anything
                        if (actor == hovered)
                            return Gdk.EVENT_STOP;

                        if (action == null) {
                            // apparently we left ours if we had one before
                            if (hovered != null) {
                                emit_crossed (hovered, false);
                                hovered = null;
                            }

                            return Gdk.EVENT_STOP;
                        }

                        // signal the previous one that we left it
                        if (hovered != null) {
                            emit_crossed (hovered, false);
                        }

                        // tell the new one that it is hovered
                        hovered = actor;
                        emit_crossed (hovered, true);

                        return Gdk.EVENT_STOP;
                    }

                    break;
                default:
                    break;
            }

            return Gdk.EVENT_PROPAGATE;
        }

        /**
         * Looks for a DragDropAction instance if this actor has one or NULL.
         * It also checks if it is a DESTINATION and if the id matches
         *
         * @return the DragDropAction instance on this actor or NULL
         */
        private DragDropAction? get_drag_drop_action (Actor actor) {
            DragDropAction? drop_action = null;

            foreach (var action in actor.get_actions ()) {
                drop_action = action as DragDropAction;
                if (drop_action == null
                    || !(DragDropActionType.DESTINATION in drop_action.drag_type)
                    || drop_action.drag_id != drag_id)
                    continue;

                return drop_action;
            }

            return null;
        }

        /**
         * Abort the drag
         */
        public void cancel () {
            cleanup ();

            drag_canceled ();
        }

        /**
         * Allows you to abort all drags currently running for a given drag-id
         */
        public static void cancel_all_by_id (string id) {
            var actors = sources.@get (id);
            if (actors == null)
                return;

            foreach (var actor in actors) {
                foreach (var action in actor.get_actions ()) {
                    var drag_action = action as DragDropAction;
                    if (drag_action != null && drag_action.dragging) {
                        drag_action.cancel ();
                        break;
                    }
                }
            }
        }

        private void finish () {
            // make sure they reset the style or whatever they changed when hovered
            emit_crossed (hovered, false);

            cleanup ();

            drag_end (hovered);
        }

        private void cleanup () {
            var source_list = sources.@get (drag_id);
            if (source_list != null) {
                foreach (var actor in source_list) {
                    actor.reactive = true;
                }
            }

            if (dragging) {
                ungrab_actor ();
            }

            dragging = false;
        }
    }
}
