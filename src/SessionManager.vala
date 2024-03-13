/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

[DBus (name = "org.gnome.SessionManager.EndSessionDialog")]
public class Gala.SessionManager : Object {
    [DBus (name = "io.elementary.wm.daemon.EndSessionDialog")]
    public interface EndSessionDialog : Object {
        public signal void confirmed_logout ();
        public signal void confirmed_reboot ();
        public signal void confirmed_shutdown ();
        public signal void cancelled ();

        public abstract void open (uint type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError;
    }

    public signal void confirmed_logout ();
    public signal void confirmed_reboot ();
    public signal void confirmed_shutdown ();
    public signal void canceled ();
    public signal void closed ();

    private EndSessionDialog? proxy = null;

    construct {
        Bus.watch_name (SESSION, "org.pantheon.gala.daemon", NONE, () => on_proxy_appeared.begin (), () => proxy = null);
    }

    private async void on_proxy_appeared () {
        try {
            proxy = yield Bus.get_proxy (BusType.SESSION, "org.pantheon.gala.daemon", "/org/pantheon/gala/daemon", 0, null);
        } catch (Error e) {
            warning ("Could not connect to io.elementary.wm.daemon.EndSessionDialog proxy: %s", e.message);
            return;
        }

        proxy.confirmed_logout.connect (() => confirmed_logout ());
        proxy.confirmed_reboot.connect (() => confirmed_reboot ());
        proxy.confirmed_shutdown.connect (() => confirmed_shutdown ());
        proxy.cancelled.connect (() => canceled ());
    }

    public void open (uint type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError {
        if (proxy == null) {
            throw new DBusError.FAILED ("io.elementary.wm.daemon.EndSessionDialog DBus interface is not registered.");
        }

        proxy.open (type, timestamp, open_length, inhibiters);
    }
}
