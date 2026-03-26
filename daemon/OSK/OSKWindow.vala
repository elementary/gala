/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.OSKWindow : Gtk.Window {
    public const string ACTION_GROUP_PREFIX = "osk";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_KEYVAL_PRESSED = "keyval-pressed";
    public const string ACTION_KEYVAL_RELEASED = "keyval-released";

    /**
     * Convenience for pressed + released
     */
    public const string ACTION_KEYVAL_CLICKED = "keyval-clicked";

    public signal void keyval_pressed (uint keyval);
    public signal void keyval_released (uint keyval);

    construct {
        var keyboard = new Keyboard ();

        child = keyboard;
        titlebar = new Gtk.Grid () { visible = false };
        title = "OSK";

        ((Gtk.Widget) this).realize.connect (update_size);

        var pressed_action = new SimpleAction (ACTION_KEYVAL_PRESSED, new VariantType ("u"));
        pressed_action.activate.connect (on_keyval_pressed);

        var released_action = new SimpleAction (ACTION_KEYVAL_RELEASED, new VariantType ("u"));
        released_action.activate.connect (on_keyval_released);

        var clicked_action = new SimpleAction (ACTION_KEYVAL_CLICKED, new VariantType ("u"));
        clicked_action.activate.connect (on_keyval_clicked);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (pressed_action);
        action_group.add_action (released_action);
        action_group.add_action (clicked_action);
        insert_action_group (ACTION_GROUP_PREFIX, action_group);
    }

    private void update_size () {
        var display = Gdk.Display.get_default ();
        var monitor = display.get_monitor_at_surface (get_surface ());
        var monitor_geom = monitor.geometry;

        default_width = monitor_geom.width;
        default_height = monitor_geom.height / 3;
    }

    private void on_keyval_pressed (SimpleAction action, Variant? parameter) {
        uint keyval = parameter.get_uint32 ();
        keyval_pressed (keyval);
    }

    private void on_keyval_released (SimpleAction action, Variant? parameter) {
        uint keyval = parameter.get_uint32 ();
        keyval_released (keyval);
    }

    private void on_keyval_clicked (SimpleAction action, Variant? parameter) {
        uint keyval = parameter.get_uint32 ();
        keyval_pressed (keyval);
        keyval_released (keyval);
    }
}
