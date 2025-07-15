/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2013 Tom Beckmann
 */

namespace Gala {
    [Flags]
    public enum DragDropActionType {
        SOURCE,
        DESTINATION
    }

    public class DragDropAction : Clutter.Action {
        // DO NOT keep a reference otherwise we get a ref cycle
        private static Gee.HashMap<string,Gee.LinkedList<unowned Clutter.Actor>>? sources = null;
        private static Gee.HashMap<string,Gee.LinkedList<unowned Clutter.Actor>>? destinations = null;

        /**
         * A drag has been started. You have to connect to this signal and
         * return an actor that is transformed during the drag operation.
         *
         * @param x The global x coordinate where the action was activated
         * @param y The global y coordinate where the action was activated
         * @return  A ClutterActor that serves as handle
         */
        public signal Clutter.Actor? drag_begin (float x, float y);

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
         * @param target the target actor that is crossing the destination
         * @param hovered indicates whether the actor is now hovered or not
         */
        public signal void crossed (Clutter.Actor? target, bool hovered);

        /**
         * Emitted on the source when a destination is crossed.
         *
         * @param destination The destination actor that has been crossed
         * @param hovered     Whether the actor is now hovered or has just been left
         */
        public signal void destination_crossed (Clutter.Actor destination, bool hovered);

        /**
         * The source has been clicked, but the movement was not larger than
         * the drag threshold. Useful if the source is also activatable.
         *
         * @param button The button which was pressed
         */
        public signal void actor_clicked (uint32 button, Clutter.InputDeviceType device_type);

        /**
         * The type of the action
         */
        public DragDropActionType drag_type { get; construct; }

        /**
         * The unique id given to this drag-drop-group
         */
        public string drag_id { get; construct; }

        public Clutter.Actor? handle { get; private set; }
        /**
         * Indicates whether a drag action is currently active
         */
        public bool dragging { get; private set; default = false; }

        /**
         * Allow checking the parents of reactive children if they are valid destinations
         * if the child is none
         */
        public bool allow_bubbling { get; set; default = true; }

        public Clutter.Actor? hovered { private get; set; default = null; }

        private bool clicked = false;
        private float last_x;
        private float last_y;

        private Clutter.Grab? grab = null;
        private static unowned Clutter.Actor? grabbed_actor = null;
        private Clutter.InputDevice? grabbed_device = null;
        private ulong on_event_id = 0;

        static construct {
            sources = new Gee.HashMap<string,Gee.LinkedList<unowned Clutter.Actor>> ();
            destinations = new Gee.HashMap<string,Gee.LinkedList<unowned Clutter.Actor>> ();
        }

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
        }

        ~DragDropAction () {
            if (actor != null) {
                release_actor (actor);
            }
        }

        public override void set_actor (Clutter.Actor? new_actor) {
            if (actor != null) {
                release_actor (actor);
            }

            if (new_actor != null) {
                connect_actor (new_actor);
            }

            base.set_actor (new_actor);
        }

        private void release_actor (Clutter.Actor actor) {
            if (DragDropActionType.SOURCE in drag_type) {

                var source_list = sources.@get (drag_id);
                source_list.remove (actor);
            }

            if (DragDropActionType.DESTINATION in drag_type) {
                var dest_list = destinations[drag_id];
                dest_list.remove (actor);
            }

            actor.destroy.disconnect (release_actor);
        }

        private void connect_actor (Clutter.Actor actor) {
            if (DragDropActionType.SOURCE in drag_type) {

                var source_list = sources.@get (drag_id);
                if (source_list == null) {
                    source_list = new Gee.LinkedList<unowned Clutter.Actor> ();
                    sources.@set (drag_id, source_list);
                }

                source_list.add (actor);
            }

            if (DragDropActionType.DESTINATION in drag_type) {
                var dest_list = destinations[drag_id];
                if (dest_list == null) {
                    dest_list = new Gee.LinkedList<unowned Clutter.Actor> ();
                    destinations[drag_id] = dest_list;
                }

                dest_list.add (actor);
            }

            actor.destroy.connect (release_actor);
        }

        private void emit_crossed (Clutter.Actor destination, bool is_hovered) {
            get_drag_drop_action (destination).crossed (actor, is_hovered);
            destination_crossed (destination, is_hovered);
        }

        public override bool handle_event (Clutter.Event event) {
            if (!(DragDropActionType.SOURCE in drag_type)) {
                return Clutter.EVENT_PROPAGATE;
            }

            switch (event.get_type ()) {
                case Clutter.EventType.BUTTON_PRESS:
                case Clutter.EventType.TOUCH_BEGIN:
                    if (!is_valid_touch_event (event)) {
                        return Clutter.EVENT_PROPAGATE;
                    }

                    if (grabbed_actor != null) {
                        return Clutter.EVENT_PROPAGATE;
                    }

                    grab_actor (actor, event.get_device ());
                    clicked = true;

                    float x, y;
                    event.get_coords (out x, out y);

                    last_x = x;
                    last_y = y;

                    return Clutter.EVENT_STOP;

                default:
                    break;
            }

            return base.handle_event (event);
        }

        private void grab_actor (Clutter.Actor actor, Clutter.InputDevice device) {
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
                device.get_device_type () != Clutter.InputDeviceType.KEYBOARD_DEVICE) {
                    return Clutter.EVENT_PROPAGATE;
                }

            switch (event.get_type ()) {
                case Clutter.EventType.KEY_PRESS:
                    if (event.get_key_symbol () == Clutter.Key.Escape) {
                        cancel ();
                    }

                    return Clutter.EVENT_STOP;

                case Clutter.EventType.BUTTON_RELEASE:
                case Clutter.EventType.TOUCH_END:
                    if (!is_valid_touch_event (event)) {
                        return Clutter.EVENT_PROPAGATE;
                    }

                    if (dragging) {
                        if (hovered != null) {
                            finish ();
                            hovered = null;
                        } else {
                            cancel ();
                        }

                        return Clutter.EVENT_STOP;
                    }

                    float x, y, ex, ey;
                    event.get_coords (out ex, out ey);
                    actor.get_transformed_position (out x, out y);

                    // release has happened within bounds of actor
                    if (clicked && x < ex && x + actor.width > ex && y < ey && y + actor.height > ey) {
                        actor_clicked (
                            event.get_type () == BUTTON_RELEASE ? event.get_button () : Clutter.Button.PRIMARY,
                            event.get_source_device ().get_device_type ()
                        );
                    }

                    if (clicked) {
                        ungrab_actor ();
                        clicked = false;
                    }

                    return Clutter.EVENT_STOP;

                case Clutter.EventType.MOTION:
                case Clutter.EventType.TOUCH_UPDATE:
                    if (!is_valid_touch_event (event)) {
                        return Clutter.EVENT_PROPAGATE;
                    }

                    float x, y;
                    event.get_coords (out x, out y);

                    if (!dragging && clicked) {
#if HAS_MUTTER47
                        var drag_threshold = actor.context.get_settings ().dnd_drag_threshold;
#else
                        var drag_threshold = Clutter.Settings.get_default ().dnd_drag_threshold;
#endif
                        if (Math.fabsf (last_x - x) > drag_threshold || Math.fabsf (last_y - y) > drag_threshold) {
                            handle = drag_begin (last_x, last_y);
                            if (handle == null) {
                                ungrab_actor ();
                                critical ("No handle has been returned by the started signal, aborting drag.");
                                return Clutter.EVENT_PROPAGATE;
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
                        return Clutter.EVENT_STOP;

                    } else if (dragging) {
                        handle.x -= last_x - x;
                        handle.y -= last_y - y;
                        last_x = x;
                        last_y = y;

                        var stage = actor.get_stage ();
                        var actor = stage.get_actor_at_pos (Clutter.PickMode.REACTIVE, (int) x, (int) y);
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
                            return Clutter.EVENT_STOP;

                        if (action == null) {
                            // apparently we left ours if we had one before
                            if (hovered != null) {
                                emit_crossed (hovered, false);
                                hovered = null;
                            }

                            return Clutter.EVENT_STOP;
                        }

                        // signal the previous one that we left it
                        if (hovered != null) {
                            emit_crossed (hovered, false);
                        }

                        // tell the new one that it is hovered
                        hovered = actor;
                        emit_crossed (hovered, true);

                        return Clutter.EVENT_STOP;
                    }

                    break;
                default:
                    break;
            }

            return Clutter.EVENT_PROPAGATE;
        }

        /**
         * Looks for a DragDropAction instance if this actor has one or NULL.
         * It also checks if it is a DESTINATION and if the id matches
         *
         * @return the DragDropAction instance on this actor or NULL
         */
        private DragDropAction? get_drag_drop_action (Clutter.Actor actor) {
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
            handle = null;
        }

        private bool is_valid_touch_event (Clutter.Event event) {
            var type = event.get_type ();

            return (
                Meta.Util.is_wayland_compositor () ||
                type != Clutter.EventType.TOUCH_BEGIN &&
                type != Clutter.EventType.TOUCH_CANCEL &&
                type != Clutter.EventType.TOUCH_END &&
                type != Clutter.EventType.TOUCH_UPDATE
            );
        }
    }
}
