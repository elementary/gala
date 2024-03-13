/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

[DBus (name = "io.elementary.wm.daemon.EndSessionDialog")]
public class Gala.Daemon.Session.Manager : Object {
    public signal void confirmed_logout ();
    public signal void confirmed_reboot ();
    public signal void confirmed_shutdown ();
    public signal void cancelled ();

    public void open (EndSessionDialog.Type type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError {
        var window = new Window (false);
        window.get_style_context ().add_class ("black-background");
        window.opacity = 0.6;
        window.present_with_time (timestamp);

        var dialog = new EndSessionDialog (type) {
            transient_for = window
        };
        dialog.show_all ();
        dialog.present_with_time (timestamp);

        dialog.destroy.connect (window.close);
        dialog.logout.connect (() => confirmed_logout ());
        dialog.reboot.connect (() => confirmed_reboot ());
        dialog.shutdown.connect (() => confirmed_shutdown ());
        dialog.cancelled.connect (() => cancelled ());
    }
}
