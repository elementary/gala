/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Handles enabling/disabling the on-screen keyboard (OSK) and relaying information to it.
 */
public class Gala.OSKManager : Object {
    private const string OSK_BUS_NAME = "io.elementary.OSK";
    private const string OSK_OBJECT_PATH = "/io/elementary/OSK";

    private const string OSK_SETTINGS_KEY = "screen-keyboard-enabled";

    public signal void input_panel_deactivation_requested ();

    public Meta.Display display { private get; construct; }

    private static Settings settings = new Settings ("org.gnome.desktop.a11y.applications");

    private OSKProxy? osk;
    private OSKReceiver? receiver;

    private bool enabled = false;

    private IBus.InputPurpose input_purpose = FREE_FORM;

    public OSKManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        settings.changed[OSK_SETTINGS_KEY].connect (sync_enabled);
        Clutter.get_default_backend ().get_default_seat ().notify["touch-mode"].connect (sync_enabled);

        sync_enabled ();

        Bus.watch_name (SESSION, OSK_BUS_NAME, NONE, () => osk_appeared.begin (), osk_lost);
    }

    private void sync_enabled () {
        var manually_enabled = settings.get_boolean (OSK_SETTINGS_KEY);
        var auto_enabled = Clutter.get_default_backend ().get_default_seat ().touch_mode;

        enabled = manually_enabled || auto_enabled;

        if (osk != null) {
            osk.set_enabled.begin (enabled);
        }
    }

    private async void osk_appeared () {
        try {
            osk = yield Bus.get_proxy<OSKProxy> (SESSION, OSK_BUS_NAME, OSK_OBJECT_PATH);
        } catch (Error e) {
            warning ("Failed to get OSK proxy: %s", e.message);
            return;
        }

        receiver = new OSKReceiver (display, osk);

        osk.set_enabled.begin (enabled);
        osk.set_input_purpose.begin (input_purpose);

        osk.hide_requested.connect (() => input_panel_deactivation_requested ());
    }

    private void osk_lost () {
        osk = null;
        receiver = null;
    }

    public void reset () {
        if (!enabled || osk == null) {
            return;
        }

        osk.reset.begin ();
    }

    public void set_input_purpose (IBus.InputPurpose purpose) {
        this.input_purpose = purpose;

        if (osk == null) {
            return;
        }

        osk.set_input_purpose.begin (purpose);
    }
}
