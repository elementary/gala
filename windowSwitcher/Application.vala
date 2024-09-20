/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcher.Application : Gtk.Application {
    public const string ACTION_PREFIX = "app.";
    public const string CYCLE_FORWARD_ACTION = "switch-windows";
    public const string CYCLE_BACKWARD_ACTION = "switch-windows-backward";
    public const string CYCLE_CURRENT_FORWARD_ACTION = "switch-group";
    public const string CYCLE_CURRENT_BACKWARD_ACTION = "switch-group-backward";

    private const ActionEntry[] ACTIONS = {
        {CYCLE_FORWARD_ACTION, cycle, null, null, null},
        {CYCLE_BACKWARD_ACTION, cycle_backward, null, null, null},
        {CYCLE_CURRENT_FORWARD_ACTION, cycle_current, null, null, null},
        {CYCLE_CURRENT_BACKWARD_ACTION, cycle_current_backward, null, null, null}
    };

    private static Settings settings;

    private WindowSwitcher window_switcher;

    public Application () {
        Object (application_id: "io.elementary.window-switcher");
    }

    public override void startup () {
        base.startup ();

        settings = new Settings ("io.elementary.desktop.window-switcher");
        settings.changed.connect (setup_accels);
        setup_accels ();

        add_action_entries (ACTIONS, this);

        Granite.init ();

        window_switcher = new WindowSwitcher (this);

        ShellKeyGrabber.init ({CYCLE_FORWARD_ACTION, CYCLE_BACKWARD_ACTION,
            CYCLE_CURRENT_FORWARD_ACTION, CYCLE_CURRENT_BACKWARD_ACTION}, settings);
    }

    private void setup_accels () {
        set_accels_for_action (ACTION_PREFIX + CYCLE_FORWARD_ACTION, settings.get_strv (CYCLE_FORWARD_ACTION));
        set_accels_for_action (ACTION_PREFIX + CYCLE_BACKWARD_ACTION, settings.get_strv (CYCLE_BACKWARD_ACTION));
        set_accels_for_action (ACTION_PREFIX + CYCLE_CURRENT_FORWARD_ACTION, settings.get_strv (CYCLE_CURRENT_FORWARD_ACTION));
        set_accels_for_action (ACTION_PREFIX + CYCLE_CURRENT_BACKWARD_ACTION, settings.get_strv (CYCLE_CURRENT_BACKWARD_ACTION));
    }

    private void cycle () {
        window_switcher.cycle (false, false);
    }

    private void cycle_backward () {
        window_switcher.cycle (false, true);
    }

    private void cycle_current () {
        window_switcher.cycle (true, false);
    }

    private void cycle_current_backward () {
        window_switcher.cycle (true, true);
    }

    public override void activate () { }
}

public static int main (string[] args) {
    GLib.Intl.setlocale (LocaleCategory.ALL, "");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

    var app = new Gala.WindowSwitcher.Application ();
    return app.run ();
}
