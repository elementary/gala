/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021-2023, 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.CloseDialog : AccessDialog, Meta.CloseDialog {
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
