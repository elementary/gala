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
                child = new Gtk.Label (value.label);
            } else if (value.icon != null) {
                child = new Gtk.Image.from_gicon (value.icon);
            } else {
                child = new Gtk.Label (_("Unknown Key"));
            }

            _key = value;
        }
    }

    private Key? _key;

    class construct {
        set_css_name ("button");
    }

    construct {
        var click_gesture = new Gtk.GestureClick ();
        click_gesture.pressed.connect (on_pressed);
        click_gesture.released.connect (on_released);
        add_controller (click_gesture);

        add_css_class ("keycap");
    }

    private void on_pressed () {
        if (_key?.press_detailed_action_name == null) {
            return;
        }

        activate_detailed_action (_key.press_detailed_action_name);
    }

    private void on_released () {
        activate_detailed_action (_key.detailed_action_name);
    }

    private void activate_detailed_action (string detailed_action) {
        string action_name;
        Variant? target;
        try {
            Action.parse_detailed_name (detailed_action, out action_name, out target);
        } catch (Error e) {
            warning ("Failed to parse action name %s: %s", detailed_action, e.message);
            return;
        }

        activate_action_variant (action_name, target);
    }
}
