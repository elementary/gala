/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.WindowMenu : Gtk.Menu {
    public signal void action_invoked (int action);

    public void update (DaemonWindowMenuItem[] items) {
        foreach (unowned var child in get_children ()) {
            remove (child);
        }

        for (var i = 0; i < items.length; i++) {
            var item = items[i];

            var accel_label = new Granite.AccelLabel (item.display_name, item.keybinding);

            if (item.type == BUTTON) {
                var button = new Gtk.MenuItem () {
                    child = accel_label,
                    sensitive = item.sensitive
                };

                var i_copy = i;
                button.activate.connect (() => action_invoked (i_copy));

                append (button);
            } else if (item.type == TOGGLE) {
                var button = new Gtk.CheckMenuItem () {
                    child = accel_label,
                    sensitive = item.sensitive,
                    active = item.toggle_state
                };

                var i_copy = i;
                button.activate.connect (() => action_invoked (i_copy));

                append (button);
            } else {
                append (new Gtk.SeparatorMenuItem ());
            }
        }
    }
}
