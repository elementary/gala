/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.FocusController : Clutter.Action {
    internal static Quark focus_visible_quark = Quark.from_string ("gala-focus-visible");

    private uint timeout_id = 0;

    public Clutter.Stage stage { get; construct; }

    public FocusController (Clutter.Stage stage) {
        Object (stage: stage);
    }

    construct {
        // In the case the key focus moves out of our focusable tree by some other means
        // make sure we can recapture it
        stage.key_press_event.connect (check_focus);
    }

    public override bool handle_event (Clutter.Event event) {
        return event.get_type () != KEY_PRESS ? Clutter.EVENT_PROPAGATE : check_focus (event);
    }

    private bool check_focus (Clutter.Event event) requires (
        actor is Focusable && !(actor.get_parent () is Focusable) // Make sure we are only attached to root focusables
    ) {
        var direction = FocusDirection.get_for_event (event);

        if (direction == null) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (!((Focusable) actor).focus (direction)) {
#if HAS_MUTTER47
            stage.context.get_backend ().get_default_seat ().bell_notify ();
#else
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
#endif

            if (!(stage.key_focus in actor)) {
                stage.key_focus = actor;
            }
        }

        show_focus ();

        return Clutter.EVENT_STOP;
    }

    private void show_focus () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
        } else {
            set_focus_visible (true);
        }

        timeout_id = Timeout.add_seconds (5, () => {
            set_focus_visible (false);
            timeout_id = 0;
            return Source.REMOVE;
        });
    }

    private void set_focus_visible (bool visible) {
        actor.set_qdata (focus_visible_quark, visible);
        (stage.key_focus as Focusable)?.focus_changed ();
    }
}
