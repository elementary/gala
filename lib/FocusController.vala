/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.FocusController : Object {
    public static FocusController get_default (Clutter.Stage stage) {
        return instance.once (() => new FocusController (stage));
    }

    public Clutter.Stage stage { get; construct; }

    private bool _focus_visible = false;
    public bool focus_visible {
        get { return _focus_visible; }
        private set {
            _focus_visible = value;
            if (stage.get_key_focus () is Focusable) {
                ((Focusable) stage.get_key_focus ()).notify_visible_focus_changed ();
            }
        }
    }

    private static GLib.Once<FocusController> instance;

    private Gee.List<unowned Focusable> root_focusables;

    private uint timeout_id = 0;

    public FocusController (Clutter.Stage stage) {
        Object (stage: stage);
    }

    construct {
        root_focusables = new Gee.LinkedList<unowned Focusable> ();
        stage.key_press_event.connect (on_key_press_event);
    }

    public void register_root (Focusable root) {
        if (root in root_focusables) {
            warning ("Trying to register root focusable multiple times.");
            return;
        }

        root_focusables.add (root);
        root.weak_ref ((obj) => root_focusables.remove ((Focusable) obj));
    }

    private bool on_key_press_event (Clutter.Event event) {
        if (handle_key_event (event) == Clutter.EVENT_STOP) {
            show_focus ();
            return Clutter.EVENT_STOP;
        }

        return Clutter.EVENT_PROPAGATE;
    }

    private bool handle_key_event (Clutter.Event event) {
        Focusable? mapped_root = null;
        foreach (var root_focusable in root_focusables) {
            if (root_focusable.mapped) {
                mapped_root = root_focusable;
                break;
            }
        }

        var direction = Focusable.FocusDirection.get_for_event (event);

        if (mapped_root == null || direction == null) {
            return Clutter.EVENT_PROPAGATE;
        }

        if(!mapped_root.focus (direction)) {
#if HAS_MUTTER47
            stage.context.get_backend ().get_default_seat ().bell_notify ();
#else
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
#endif
        }

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
