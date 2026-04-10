/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Keyboard : Granite.Bin {
    public signal void key_clicked (uint keyval);

    construct {
        var flowbox = new Gtk.FlowBox () {
            min_children_per_line = 12,
        };
        flowbox.append (create_button (Gdk.Key.A));
        flowbox.append (create_button (Gdk.Key.B));
        flowbox.append (create_button (Gdk.Key.C));
        flowbox.append (create_button (Gdk.Key.D));
        flowbox.append (create_button (Gdk.Key.E));
        flowbox.append (create_button (Gdk.Key.F));
        flowbox.append (create_button (Gdk.Key.G));
        flowbox.append (create_button (Gdk.Key.H));
        flowbox.append (create_button (Gdk.Key.I));
        flowbox.append (create_button (Gdk.Key.J));
        flowbox.append (create_button (Gdk.Key.K));
        flowbox.append (create_button (Gdk.Key.L));
        flowbox.append (create_button (Gdk.Key.M));
        flowbox.append (create_button (Gdk.Key.N));
        flowbox.append (create_button (Gdk.Key.O));
        flowbox.append (create_button (Gdk.Key.P));
        flowbox.append (create_button (Gdk.Key.Q));
        flowbox.append (create_button (Gdk.Key.R));
        flowbox.append (create_button (Gdk.Key.S));
        flowbox.append (create_button (Gdk.Key.T));
        flowbox.append (create_button (Gdk.Key.U));
        flowbox.append (create_button (Gdk.Key.V));
        flowbox.append (create_button (Gdk.Key.W));
        flowbox.append (create_button (Gdk.Key.X));
        flowbox.append (create_button (Gdk.Key.Y));
        flowbox.append (create_button (Gdk.Key.Z));
        flowbox.append (create_button (Gdk.Key.BackSpace));
        flowbox.append (create_button (Gdk.Key.space));
        flowbox.append (create_button (Gdk.Key.Escape));

        child = flowbox;
    }

    private Gtk.Button create_button (uint keyval) {
        var button = new Gtk.Button.with_label (Gdk.keyval_name (keyval)) {
            action_name = OSKWindow.ACTION_PREFIX + OSKWindow.ACTION_KEYVAL_CLICKED,
            action_target = keyval
        };
        return button;
    }
}
