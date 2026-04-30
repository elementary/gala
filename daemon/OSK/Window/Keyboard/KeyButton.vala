/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.KeyButton : Granite.Bin {
    public Key key {
        set {
            if (value.label != null) {
                button.label = value.label;
            } else if (value.icon != null) {
                button.child = new Gtk.Image.from_gicon (value.icon);
            } else {
                button.label = _("Unknown Key");
            }

            button.set_detailed_action_name (value.detailed_action_name);
        }
    }

    private Gtk.Button button;

    construct {
        button = new Gtk.Button ();
        child = button;
    }
}
