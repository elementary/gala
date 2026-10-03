/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018 Adam Bieńkowski
 *                         2025 elementary, Inc. (https://elementary.io)
 */

// Reference code by the Solus Project:
// https://github.com/solus-project/budgie-desktop/blob/master/src/wm/shim.vala

[DBus (name = "org.gnome.SessionManager.EndSessionDialog")]
public class Gala.SessionManager : Object {
    [DBus (name = "io.elementary.wingpanel.session.EndSessionDialog")]
    private interface WingpanelEndSessionDialog : Object {
        public signal void confirmed_logout ();
        public signal void confirmed_reboot ();
        public signal void confirmed_shutdown ();
        public signal void canceled ();
        public signal void closed ();

        public abstract void open (uint type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError;
    }

    private static SessionManager? instance;

    [DBus (visible = false)]
    public static unowned SessionManager init () {
        if (instance == null) {
            instance = new SessionManager ();
        }

        return instance;
    }

    public signal void confirmed_logout ();
    public signal void confirmed_reboot ();
    public signal void confirmed_shutdown ();
    public signal void canceled ();
    public signal void closed ();

    private WingpanelEndSessionDialog? proxy = null;

    private SessionManager () {
        Bus.watch_name (BusType.SESSION, "io.elementary.wingpanel.session.EndSessionDialog",
            BusNameWatcherFlags.NONE, proxy_appeared, proxy_vanished);
    }

    private void get_proxy_cb (Object? o, AsyncResult? res) {
        try {
            proxy = Bus.get_proxy.end (res);
        } catch (Error e) {
            warning ("Could not connect to io.elementary.wingpanel.session.EndSessionDialog proxy: %s", e.message);
            return;
        }

        proxy.confirmed_logout.connect (() => confirmed_logout ());
        proxy.confirmed_reboot.connect (() => confirmed_reboot ());
        proxy.confirmed_shutdown.connect (() => confirmed_shutdown ());
        proxy.canceled.connect (() => canceled ());
        proxy.closed.connect (() => closed ());
    }

    private void proxy_appeared () {
        Bus.get_proxy.begin<WingpanelEndSessionDialog> (BusType.SESSION,
            "io.elementary.wingpanel.session.EndSessionDialog", "/io/elementary/wingpanel/session/EndSessionDialog",
            0, null, get_proxy_cb);
    }

    private void proxy_vanished () {
        proxy = null;
    }

    public void open (uint type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError {
        if (proxy == null) {
            throw new DBusError.FAILED ("io.elementary.wingpanel.session.EndSessionDialog DBus interface is not registered.");
        }

        proxy.open (type, timestamp, open_length, inhibiters);
    }
}
