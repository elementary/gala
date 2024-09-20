/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

/**
 * ActionMode:
 * @NONE: block action
 * @NORMAL: allow action when in window mode, e.g. when the focus is in an application window
 * @OVERVIEW: allow action while the overview is active
 * @LOCK_SCREEN: allow action when the screen is locked, e.g. when the screen shield is shown
 * @UNLOCK_SCREEN: allow action in the unlock dialog
 * @LOGIN_SCREEN: allow action in the login screen
 * @SYSTEM_MODAL: allow action when a system modal dialog (e.g. authentification or session dialogs) is open
 * @LOOKING_GLASS: allow action in looking glass
 * @POPUP: allow action while a shell menu is open
 */

[Flags]
public enum ActionMode {
    NONE = 0,
    NORMAL = 1 << 0,
    OVERVIEW = 1 << 1,
    LOCK_SCREEN = 1 << 2,
    UNLOCK_SCREEN = 1 << 3,
    LOGIN_SCREEN = 1 << 4,
    SYSTEM_MODAL = 1 << 5,
    LOOKING_GLASS = 1 << 6,
    POPUP = 1 << 7,
}

[Flags]
public enum Meta.KeyBindingFlags {
    NONE = 0,
    PER_WINDOW = 1 << 0,
    BUILTIN = 1 << 1,
    IS_REVERSED = 1 << 2,
    NON_MASKABLE = 1 << 3,
    IGNORE_AUTOREPEAT = 1 << 4,
}

public struct Accelerator {
    public string name;
    public ActionMode mode_flags;
    public Meta.KeyBindingFlags grab_flags;
}

[DBus (name = "org.gnome.Shell")]
public interface Gala.WindowSwitcher.ShellKeyGrabber : GLib.Object {
    public abstract signal void accelerator_activated (uint action, GLib.HashTable<string, GLib.Variant> parameters_dict);

    public abstract uint grab_accelerator (string accelerator, ActionMode mode_flags, Meta.KeyBindingFlags grab_flags) throws GLib.DBusError, GLib.IOError;
    public abstract uint[] grab_accelerators (Accelerator[] accelerators) throws GLib.DBusError, GLib.IOError;
    public abstract bool ungrab_accelerator (uint action) throws GLib.DBusError, GLib.IOError;
    public abstract bool ungrab_accelerators (uint[] actions) throws GLib.DBusError, GLib.IOError;

    private static Settings settings;
    private static ShellKeyGrabber? instance;

    private static Gee.HashSet<uint> saved_action_ids;

    private static WindowSwitcher window_switcher;

    public static void init (WindowSwitcher _window_switcher) {
        window_switcher = _window_switcher;

        saved_action_ids = new Gee.HashSet<uint> ();

        settings = new Settings ("org.gnome.desktop.wm.keybindings");

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
        } catch (Error e) {
            warning ("Failed to connect to bus for keyboard shortcut grabs: %s", e.message);
        }
    }

    private static void setup_grabs () requires (instance != null) {
        //  var keybindings = settings.get_strv ("switch-windows");
        string[] keybindings = {"<Alt>Tab"};
        Accelerator[] accelerators = {};
        for (int j = 0; j < keybindings.length; j++) {
            accelerators += Accelerator () {
                name = keybindings[j],
                mode_flags = ActionMode.NONE,
                grab_flags = Meta.KeyBindingFlags.NONE
            };
        }

        try {
            foreach (var id in instance.grab_accelerators (accelerators)) {
                saved_action_ids.add (id);
            }
        } catch (Error e) {
            critical ("Couldn't grab accelerators: %s", e.message);
        }

        instance.accelerator_activated.connect (on_accelerator_activated);
    }

    private static void on_accelerator_activated (uint action, GLib.HashTable<string, GLib.Variant> parameters_dict) {
        if (!(action in saved_action_ids)) {
            return;
        }

        window_switcher.activate_switcher ();
    }

    private static void ungrab_keybindings () requires (instance != null) {
        try {
            instance.ungrab_accelerators (saved_action_ids.to_array ());
        } catch (Error e) {
            critical ("Couldn't ungrab accelerators: %s", e.message);
        }
    }
}
