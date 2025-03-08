/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2015 Nicolas Bruguier
 *                         2015 Corentin Noël
 *                         2025 elementary, Inc. (https://elementary.io)
 */

[DBus (name="org.gnome.Shell")]
public class Gala.DBusAccelerator {
    [Flags]
    public enum ActionMode {
        /**
         * Block action
         */
        NONE = 0,
        /**
         * allow action when in window mode, e.g. when the focus is in an application window
         */
        NORMAL = 1 << 0,
        /**
         * allow action while the overview is active
         */
        OVERVIEW = 1 << 1,
        /**
         * allow action when the screen is locked, e.g. when the screen shield is shown
         */
        LOCK_SCREEN = 1 << 2,
        /**
         * allow action in the unlock dialog
         */
        UNLOCK_SCREEN = 1 << 3,
        /**
         * allow action in the login screen
         */
        LOGIN_SCREEN = 1 << 4,
        /**
         * allow action when a system modal dialog (e.g. authentification or session dialogs) is open
         */
        SYSTEM_MODAL = 1 << 5,
        /**
         * allow action in looking glass
         */
        LOOKING_GLASS = 1 << 6,
        /**
         * allow action while a shell menu is open
         */
        POPUP = 1 << 7,
    }

    public struct Accelerator {
        public string name;
        public ActionMode flags;
        public Meta.KeyBindingFlags grab_flags;
    }

    [Compact]
    private class GrabbedAccelerator {
        public string name;
        public ActionMode flags;
        public Meta.KeyBindingFlags grab_flags;
        public uint action;
    }

    private const string NOTIFICATION_COMPONENT_NAME = "DBusAccelerator";

    public signal void accelerator_activated (uint action, GLib.HashTable<string, Variant> parameters);

    private Meta.Display display;
    private NotificationsManager notifications_manager;
    private GLib.HashTable<unowned string, GrabbedAccelerator> grabbed_accelerators;

    public DBusAccelerator (Meta.Display _display, NotificationsManager _notifications_manager) {
        display = _display;
        notifications_manager = _notifications_manager;
        grabbed_accelerators = new HashTable<unowned string, GrabbedAccelerator> (str_hash, str_equal);
        display.accelerator_activated.connect (on_accelerator_activated);
    }

    private void on_accelerator_activated (uint action, Clutter.InputDevice device, uint timestamp) {
        foreach (unowned GrabbedAccelerator accel in grabbed_accelerators.get_values ()) {
            if (accel.action == action) {
                var parameters = new GLib.HashTable<string, Variant> (null, null);
                parameters.set ("timestamp", new Variant.uint32 (timestamp));
                if (device.device_node != null) {
                    parameters.set ("device-node", new Variant.string (device.device_node));
                }

                accelerator_activated (action, parameters);

                return;
            }
        }
    }

    public uint grab_accelerator (string accelerator, ActionMode flags, Meta.KeyBindingFlags grab_flags) throws GLib.DBusError, GLib.IOError {
        unowned var found_accel = grabbed_accelerators[accelerator];
        if (found_accel != null) {
            return found_accel.action;
        }

        uint action = display.grab_accelerator (accelerator, grab_flags);
        if (action != Meta.KeyBindingFlags.NONE) {
            var accel = new GrabbedAccelerator ();
            accel.action = action;
            accel.name = accelerator;
            accel.flags = flags;
            accel.grab_flags = grab_flags;
            grabbed_accelerators.insert (accel.name, (owned)accel);
        }

        return action;
    }

    public uint[] grab_accelerators (Accelerator[] accelerators) throws GLib.DBusError, GLib.IOError {
        uint[] actions = {};

        foreach (unowned Accelerator accelerator in accelerators) {
            actions += grab_accelerator (accelerator.name, accelerator.flags, accelerator.grab_flags);
        }

        return actions;
    }

    public bool ungrab_accelerator (uint action) throws GLib.DBusError, GLib.IOError {
        foreach (unowned GrabbedAccelerator accel in grabbed_accelerators.get_values ()) {
            if (accel.action == action) {
                bool ret = display.ungrab_accelerator (action);
                grabbed_accelerators.remove (accel.name);
                return ret;
            }
        }

        return false;
    }

    public bool ungrab_accelerators (uint[] actions) throws GLib.DBusError, GLib.IOError {
        foreach (uint action in actions) {
            ungrab_accelerator (action);
        }

        return true;
    }

    [DBus (name = "ShowOSD")]
    public void show_osd (GLib.HashTable<string, Variant> parameters) throws GLib.DBusError, GLib.IOError {
        int32 monitor_index = -1;
        if (parameters.contains ("monitor"))
            monitor_index = parameters["monitor"].get_int32 ();
        string icon = "";
        if (parameters.contains ("icon"))
            icon = parameters["icon"].get_string ();
        string label = "";
        if (parameters.contains ("label"))
            label = parameters["label"].get_string ();
        int32 level = 0;
        if (parameters.contains ("level")) {
            var double_level = parameters["level"].get_double ();
            level = (int)(double_level * 100);
        }

        var hints = new GLib.HashTable<string, Variant> (null, null);
        hints.set ("x-canonical-private-synchronous", new Variant.string ("gala-feedback"));
        hints.set ("value", new Variant.int32 (level));

        notifications_manager.send.begin (
            NOTIFICATION_COMPONENT_NAME,
            icon,
            label,
            "",
            {},
            hints
        );
    }
}
