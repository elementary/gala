/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.FocusController : Clutter.Action {
    internal static Quark focus_visible_quark = Quark.from_string ("gala-focus-visible");

    public Focusable root { get; construct; }

    private uint timeout_id = 0;

    public FocusController (Focusable root) {
        Object (root: root);
    }

    public override bool handle_event (Clutter.Event event) {
        if (event.get_type () != KEY_PRESS) {
            return Clutter.EVENT_PROPAGATE;
        }

        var direction = FocusDirection.get_for_event (event);

        if (direction == null) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (!root.focus (direction)) {
#if HAS_MUTTER47
            stage.context.get_backend ().get_default_seat ().bell_notify ();
#else
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
#endif
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
        var stage = actor.get_stage ();
        stage.set_qdata (focus_visible_quark, visible);
        (stage.key_focus as Focusable)?.focus_changed ();
    }
}
