/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public struct Accelerator {
    public string name;
    public uint mode_flags;
    public uint grab_flags;
}

[DBus (name = "org.gnome.Shell")]
public interface Gala.WindowSwitcher.ShellKeyGrabber : GLib.Object {
    public abstract signal void accelerator_activated (uint action, GLib.HashTable<string, GLib.Variant> parameters_dict);

    public abstract uint grab_accelerator (string accelerator, uint mode_flags, uint grab_flags) throws GLib.DBusError, GLib.IOError;
    public abstract uint[] grab_accelerators (Accelerator[] accelerators) throws GLib.DBusError, GLib.IOError;
    public abstract bool ungrab_accelerators (uint[] actions) throws GLib.DBusError, GLib.IOError;

    private static string[] actions;
    private static Settings settings;

    private static Gee.HashMap<uint, string> saved_action_ids;

    private static ShellKeyGrabber? instance;

    public static void init (string[] _actions, Settings _settings) {
        actions = _actions;
        settings = _settings;

        saved_action_ids = new Gee.HashMap<uint, string> ();

        settings.changed.connect (() => {
            ungrab_keybindings ();
            setup_grabs ();
        });

        Bus.watch_name (BusType.SESSION, "org.gnome.Shell", BusNameWatcherFlags.NONE, () => on_watch.begin (), () => instance = null);
    }

    private static async void on_watch () {
        try {
            instance = yield Bus.get_proxy (SESSION, "org.gnome.Shell", "/org/gnome/Shell");

            setup_grabs ();
            instance.accelerator_activated.connect (on_accelerator_activated);
        } catch (Error e) {
            warning ("Failed to connect to bus for keyboard shortcut grabs: %s", e.message);
        }
    }

    private static void setup_grabs () requires (instance != null) {
        foreach (var action in actions) {
            Accelerator[] accelerators = {};

            foreach (var keybinding in settings.get_strv (action)) {
                accelerators += Accelerator () {
                    name = keybinding,
                    mode_flags = 0,
                    grab_flags = 0
                };
            }

            try {
                foreach (var id in instance.grab_accelerators (accelerators)) {
                    saved_action_ids.set (id, action);
                }
            } catch (Error e) {
                critical ("Couldn't grab accelerators: %s", e.message);
            }
        }
    }

    private static void on_accelerator_activated (uint action, GLib.HashTable<string, GLib.Variant> parameters_dict) {
        if (!saved_action_ids.has_key (action)) {
            return;
        }

        ((Gtk.Application) GLib.Application.get_default ()).activate_action (
            saved_action_ids[action],
            null
        );
    }

    private static void ungrab_keybindings () requires (instance != null) {
        try {
            instance.ungrab_accelerators (saved_action_ids.keys.to_array ());
        } catch (Error e) {
            critical ("Couldn't ungrab accelerators: %s", e.message);
        }
    }
}
