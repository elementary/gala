/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.WindowMenu : Gtk.Popover {
    public signal void action_invoked (int action) {
        popdown ();
    }

    construct {
        halign = START;
        position = BOTTOM;
        autohide = false;
        has_arrow = false;
        add_css_class (Granite.STYLE_CLASS_MENU);
    }

    public void update (DaemonWindowMenuItem[] items) {
        var box = new Gtk.Box (VERTICAL, 0);
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            
            var accel_label = new Granite.AccelLabel (item.display_name, item.keybinding);

            if (item.type == BUTTON) {
                var button = new Gtk.Button () {
                    child = accel_label,
                    sensitive = item.sensitive
                };
                button.add_css_class (Granite.STYLE_CLASS_MENUITEM);

                var i_copy = i;
                button.clicked.connect (() => action_invoked (i_copy));

                box.append (button);
            } else if (item.type == TOGGLE) {
                var button = new Gtk.CheckButton () {
                    child = accel_label,
                    sensitive = item.sensitive,
                    active = item.toggle_state
                };
                button.add_css_class (Granite.STYLE_CLASS_MENUITEM);

                var i_copy = i;
                button.toggled.connect (() => action_invoked (i_copy));

                box.append (button);
            } else {
                box.append (new Gtk.Separator (HORIZONTAL));
            }
        }

        child = box;
    }
}
