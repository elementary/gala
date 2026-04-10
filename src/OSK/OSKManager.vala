/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Handles enabling/disabling and showing/hiding the on-screen keyboard (OSK).
 */
public class Gala.OSKManager : Object {
    public Meta.Display display { private get; construct; }
    public InputMethod im { private get; construct; }

    public int monitor { get; private set; default = 0; }
    public bool visible { get; private set; default = false; }

    private OSKProxy? osk;
    private OSKReceiver? receiver;

    private bool enabled = false;

    public OSKManager (Meta.Display display, InputMethod im) {
        Object (display: display, im: im);
    }

    construct {
        Bus.watch_name (SESSION, DaemonManager.DAEMON_DBUS_NAME, NONE, () => daemon_appeared.begin (), daemon_lost);

        im.input_panel_state.connect (on_input_panel_state_changed);

        sync_enabled ();
    }

    private async void daemon_appeared () {
        try {
            osk = yield Bus.get_proxy<OSKProxy> (SESSION, DaemonManager.DAEMON_DBUS_NAME, DaemonManager.DAEMON_DBUS_OBJECT_PATH);
        } catch (Error e) {
            warning ("Failed to get OSK proxy: %s", e.message);
            return;
        }

        receiver = new OSKReceiver (display, osk, im);

        osk.set_enabled.begin (enabled);
    }

    private void daemon_lost () {
        osk = null;
        receiver = null;
    }

    private void sync_enabled () {
        enabled = true;

        if (osk != null) {
            osk.set_enabled.begin (enabled);
        }
    }

    private void on_input_panel_state_changed (Clutter.InputPanelState state) {
        switch (state) {
            case ON:
                visible = true;
                break;

            case OFF:
                visible = false;
                break;

            case TOGGLE:
                visible = !visible;
                break;
        }
    }
}
