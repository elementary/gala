/*
 * Copyright 2021-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    [DBus (name = "org.freedesktop.impl.portal.Access")]
    public interface AccessPortal : Object {
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
    public interface Request : Object {
        public abstract void close () throws DBusError, IOError;
    }

    public class AccessDialog : Object {
        public signal void response (uint response);

        public Meta.Window parent { owned get; construct set; }

        public string title { get; construct; }
        public string body { get; construct; }
        public string icon { get; construct; }
        public string accept_label { get; set; }
        public string deny_label { get; set; }

        const string PANTHEON_PORTAL_NAME = "org.freedesktop.impl.portal.desktop.pantheon";
        const string FDO_PORTAL_PATH = "/org/freedesktop/portal/desktop";
        const string GALA_DIALOG_PATH = "/io/elementary/gala/dialog";

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
                    //TODO: wayland support
                    parent_handler = "x11:%x".printf ((uint) parent.get_xwindow ());
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
                    portal.access_dialog.end (res, out ret);
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

    public class CloseDialog : AccessDialog, Meta.CloseDialog {
        public Meta.Window window {
            owned get { return parent; }
            construct { parent = value; }
        }

        public static Gee.Set<CloseDialog> open_dialogs = new Gee.HashSet<CloseDialog> ();

        // this function isn't exported in glib.vapi
        [CCode (cname = "g_locale_from_utf8")]
        extern static string locale_from_utf8 (
            string str,
            ssize_t len = -1,
            out size_t bytes_read = null,
            out size_t bytes_wrriten = null,
            out Error err = null
        );

        public CloseDialog (Meta.Window window) {
            Object (window: window);
        }

        ~CloseDialog () {
            open_dialogs.remove (this);
        }

        construct {
            icon = "computer-fail";

            var window_title = locale_from_utf8 (window.title) ?? window.get_sandboxed_app_id ();
            if (window_title != null) {
                title = _("“%s” is not responding").printf (window_title);
            } else {
                title = _("Application is not responding");
            }

            body = _("You may choose to wait a short while for it to continue or force the application to quit entirely.");
            accept_label = _("Force Quit");
            deny_label = _("Wait");

            open_dialogs.add (this);
        }

        public override void show () {
            if (path != null) {
                return;
            }

            base.show ();
        }

        public void hide () {
            if (path != null) {
                close ();
            }
        }

        public void focus () {
            window.foreach_transient ((w) => {
                if (w.get_role () == "AccessDialog") {
                    w.activate (w.get_display ().get_current_time ());
                    return false;
                }

                return true;
            });
        }

        protected override void on_response (uint response_id) {
            if (response_id == 0) {
                base.response (Meta.CloseDialogResponse.FORCE_CLOSE);
            } else {
                base.response (Meta.CloseDialogResponse.WAIT);
            }
        }
    }
}
