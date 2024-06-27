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

    public class CloseDialog : AccessDialog, Meta.CloseDialog {
        public Meta.Window window {
            owned get { return parent; }
            construct { parent = value; }
        }

        public App app { get; construct; }

        public CloseDialog (Gala.App app, Meta.Window window) {
            Object (app: app, window: window);
        }

        construct {
            icon = "computer-fail";

            var window_title = app.name;
            if (window_title != null) {
                title = _("“%s” is not responding").printf (window_title);
            } else {
                title = _("Application is not responding");
            }

            body = _("You may choose to wait a short while for the application to continue, or force it to quit entirely.");
            accept_label = _("Force Quit");
            deny_label = _("Wait");
        }

        public override void show () {
            if (path != null) {
                return;
            }

            try {
                var our_pid = new Credentials ().get_unix_pid ();
                if (our_pid == window.get_pid ()) {
                    critical ("We have an unresponsive window somewhere. Mutter wants to end its own process. Don't let it.");
                    // In all seriousness this sounds bad, but can happen if one of our WaylandClients gets unresponsive.
                    on_response (1);
                    return;
                }
            } catch (Error e) {
                warning ("Failed to safeguard kill pid: %s", e.message);
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

    public class InhibitShortcutsDialog : AccessDialog, Meta.InhibitShortcutsDialog {
        public Meta.Window window {
            owned get { return parent; }
            construct { parent = value; }
        }

        public App app { get; construct; }

        public InhibitShortcutsDialog (Gala.App app, Meta.Window window) {
            Object (app: app, window: window);
        }

        construct {
            icon = "preferences-desktop-keyboard";

            var window_title = app.name;
            if (window_title != null) {
                title = _("“%s” wants to inhibit system shortcuts").printf (window_title);
            } else {
                title = _("An application wants to inhibit system shortcuts");
            }

            body = _("All system shortcuts will be redirected to the application.");
            accept_label = _("Allow");
            deny_label = _("Deny");
        }

        public override void show () {
            if (path != null) {
                return;
            }

            // Naive check to always allow inhibiting by our settings app. This is needed for setting custom shortcuts
            if (app.id == "io.elementary.settings.desktop") {
                on_response (0);
                return;
            }

            base.show ();
        }

        public void hide () {
            if (path != null) {
                close ();
            }
        }

        protected override void on_response (uint response_id) {
            if (response_id == 0) {
                base.response (Meta.InhibitShortcutsDialogResponse.ALLOW);
            } else {
                base.response (Meta.InhibitShortcutsDialogResponse.DENY);
            }
        }
    }
}
