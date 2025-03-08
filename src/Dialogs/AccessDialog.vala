/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021-2023, 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.AccessDialog : Object {
    [DBus (name = "org.freedesktop.impl.portal.Access")]
    protected interface AccessPortal : Object {
        [DBus (timeout = 2147483647)] // timeout = int.MAX; value got from <limits.h>
        public abstract async void access_dialog (
            ObjectPath request_path,
            string app_id,
            string window_handle,
            string title,
            string sub_title,
            string body,
            HashTable<string, Variant> options,
            out uint response
        ) throws IOError, DBusError;
    }

    [DBus (name = "org.freedesktop.impl.portal.Request")]
    private interface Request : Object {
        public abstract void close () throws DBusError, IOError;
    }

    public signal void response (uint response);

    public Meta.Window parent { owned get; construct set; }

    public string title { get; construct set; }
    public string body { get; construct set; }
    public string icon { get; construct set; }
    public string accept_label { get; set; }
    public string deny_label { get; set; }

    private const string PANTHEON_PORTAL_NAME = "org.freedesktop.impl.portal.desktop.pantheon";
    private const string FDO_PORTAL_PATH = "/org/freedesktop/portal/desktop";
    private const string GALA_DIALOG_PATH = "/io/elementary/gala/dialog";

    protected static AccessPortal? portal = null;
    protected ObjectPath? path = null;

    public static void watch_portal () {
        Bus.watch_name (BusType.SESSION, PANTHEON_PORTAL_NAME, BusNameWatcherFlags.NONE,
            () => {
                try {
                    portal = Bus.get_proxy_sync (BusType.SESSION, PANTHEON_PORTAL_NAME, FDO_PORTAL_PATH);
                } catch (Error e) {
                    warning ("can't reach portal session: %s", e.message);
                }
            },
            () => {
                portal = null;
            }
        );
    }

    public AccessDialog (string title, string body, string icon) {
        Object (title: title, body: body, icon: icon);
    }

    [Signal (run = "first")]
    public virtual signal void show () {
        if (portal == null) {
            return;
        }

        path = new ObjectPath (GALA_DIALOG_PATH + "/%i".printf (Random.int_range (0, int.MAX)));
        string parent_handler = "";
        var app_id = "";

        if (parent != null) {
            if (parent.get_client_type () == Meta.WindowClientType.X11) {
#if HAS_MUTTER46
                unowned Meta.Display display = parent.get_display ();
                unowned Meta.X11Display x11display = display.get_x11_display ();
                parent_handler = "x11:%x".printf ((uint) x11display.lookup_xwindow (parent));
#else
                parent_handler = "x11:%x".printf ((uint) parent.get_xwindow ());
#endif
                //TODO: wayland support
            }

            app_id = parent.get_sandboxed_app_id () ?? "";
        }

        var options = new HashTable<string, Variant> (str_hash, str_equal);
        options["grant_label"] = accept_label;
        options["deny_label"] = deny_label;
        options["icon"] = icon;

        if (this is CloseDialog) {
            options["destructive"] = true;
        }

        portal.access_dialog.begin (path, app_id, parent_handler, title, body, "", options, (obj, res) => {
            uint ret;

            try {
                ((AccessPortal) obj).access_dialog.end (res, out ret);
            } catch (Error e) {
                warning (e.message);
                ret = 2;
            }

            on_response (ret);
            path = null;
        });
    }

    public void close () {
        try {
            Bus.get_proxy_sync<Request> (BusType.SESSION, PANTHEON_PORTAL_NAME, path).close ();
            path = null;
        } catch (Error e) {
            warning (e.message);
        }
    }

    protected virtual void on_response (uint response_id) {
        response (response_id);
    }
}
