/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Root : Widget {
    private bool _focus_visible = false;
    internal bool focus_visible {
        get { return _focus_visible; }
        set {
            _focus_visible = value;
            (get_stage ().key_focus as Widget)?.focus_changed ();
        }
    }

    private uint timeout_id = 0;

    public override void map () {
        base.map ();
        // In the case the key focus moves out of our widget tree by some other means
        // make sure we can recapture it
        get_stage ().key_press_event.connect (check_focus);
    }

    public override void unmap () {
        base.unmap ();
        get_stage ().key_press_event.disconnect (check_focus);
    }

    public override bool key_press_event (Clutter.Event event) {
        return check_focus (event);
    }

    private bool check_focus (Clutter.Event event) {
        var direction = FocusDirection.get_for_event (event);

        if (direction == null) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (!focus (direction)) {
#if HAS_MUTTER47
            get_stage ().context.get_backend ().get_default_seat ().bell_notify ();
#else
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
#endif

            if (!(get_stage ().key_focus in this)) {
                get_stage ().key_focus = this;
            }
        }

        show_focus ();

        return Clutter.EVENT_STOP;
    }

    private void show_focus () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
        } else {
            focus_visible = true;
        }

        timeout_id = Timeout.add_seconds (5, () => {
            focus_visible = false;
            timeout_id = 0;
            return Source.REMOVE;
        });
    }
}
