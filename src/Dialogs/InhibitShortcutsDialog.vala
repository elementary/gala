/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021-2023, 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.InhibitShortcutsDialog : AccessDialog, Meta.InhibitShortcutsDialog {
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

        if (app.id == "io.elementary.settings.desktop" || // Naive check to always allow inhibiting by our settings app. This is needed for setting custom shortcuts
            ShellClientsManager.get_instance ().is_positioned_window (window) // Certain windows (e.g. centered ones) may want to disable move via super + drag
        ) {
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
