/*
 * Copyright 2020 elementary, Inc (https://elementary.io)
 *           2020 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Gala.Plugins.Touchegg.Plugin : Gala.Plugin {
    private Gala.WindowManager? wm = null;
    private Client? client = null;
    private GLib.Settings gala_settings;
    private GLib.Settings touchpad_settings;

    /**
     * Percentage of the animation to be completed to apply the action.
     */
    private const int SUCCESS_THRESHOLD = 20;

    public override void initialize (Gala.WindowManager window_manager) {
        wm = window_manager;
        gala_settings = new GLib.Settings ("io.elementary.desktop.wm.gestures");
        touchpad_settings = new GLib.Settings ("org.gnome.desktop.peripherals.touchpad");

        client = new Client ();
        client.on_gesture_begin.connect ((gesture) => Idle.add (() => {
            on_handle_gesture (gesture, "begin");
            return false;
        }));
        client.on_gesture_update.connect ((gesture) => Idle.add (() => {
            on_handle_gesture (gesture, "update");
            return false;
        }));
        client.on_gesture_end.connect ((gesture) => Idle.add (() => {
            on_handle_gesture (gesture, "end");
            return false;
        }));

        try {
            client.run ();
        } catch (Error e) {
            warning ("Error initializing Touchégg client: %s", e.message);
        }
    }

    public override void destroy () {
        if (client != null) {
            client.stop ();
        }
    }


    private void on_handle_gesture (Gesture gesture, string event) {
        // debug (@"Gesture $(event): $(gesture.type) - $(gesture.direction) - $(gesture.fingers) fingers - $(gesture.percentage)% - $(gesture.elapsed_time) - $(gesture.performed_on_device_type)");
        var hints = build_hints_from_gesture (gesture, event);

        if (is_open_workspace_gesture (gesture)) {
            wm.workspace_view.open (hints);
        } else if (is_close_workspace_gesture (gesture)) {
            wm.workspace_view.close (hints);
        } else if (is_next_desktop_gesture (gesture)) {
            if (!wm.workspace_view.is_opened ()) {
                wm.switch_to_next_workspace (Meta.MotionDirection.RIGHT, hints);
            }
        } else if (is_previous_desktop_gesture (gesture)) {
            if (!wm.workspace_view.is_opened ()) {
                wm.switch_to_next_workspace (Meta.MotionDirection.LEFT, hints);
            }
        }
    }

    private GLib.HashTable<string, Variant> build_hints_from_gesture (Gesture gesture, string event) {
        var hints = new GLib.HashTable<string, Variant> (str_hash, str_equal);
        hints.insert ("manual_animation", new Variant.boolean (true));
        hints.insert ("event", new Variant.string (event));
        hints.insert ("percentage", new Variant.int32 (gesture.percentage));

        if (event == "end") {
            hints.insert ("cancel_action", new Variant.boolean (gesture.percentage < SUCCESS_THRESHOLD));
        }

        return hints;
    }

    private bool is_open_workspace_gesture (Gesture gesture) {
        bool enabled = gala_settings.get_boolean ("multitasking-gesture-enabled");
        int fingers = gala_settings.get_int ("multitasking-gesture-fingers");

        return enabled
            && gesture.type == GestureType.SWIPE
            && gesture.direction == GestureDirection.UP
            && gesture.fingers == fingers;
    }

    private bool is_close_workspace_gesture (Gesture gesture) {
        bool enabled = gala_settings.get_boolean ("multitasking-gesture-enabled");
        int fingers = gala_settings.get_int ("multitasking-gesture-fingers");

        return enabled
            && gesture.type == GestureType.SWIPE
            && gesture.direction == GestureDirection.DOWN
            && gesture.fingers == fingers;
    }

    private bool is_next_desktop_gesture (Gesture gesture) {
        bool enabled = gala_settings.get_boolean ("workspaces-gesture-enabled");
        int fingers = gala_settings.get_int ("workspaces-gesture-fingers");
        bool natural_scroll = (gesture.performed_on_device_type == DeviceType.TOUCHSCREEN)
            ? true
            : touchpad_settings.get_boolean ("natural-scroll");
        var direction = natural_scroll ? GestureDirection.LEFT : GestureDirection.RIGHT;

        return enabled
            && gesture.type == GestureType.SWIPE
            && gesture.direction == direction
            && gesture.fingers == fingers;
    }

    private bool is_previous_desktop_gesture (Gesture gesture) {
        bool enabled = gala_settings.get_boolean ("workspaces-gesture-enabled");
        int fingers = gala_settings.get_int ("workspaces-gesture-fingers");
        bool natural_scroll = (gesture.performed_on_device_type == DeviceType.TOUCHSCREEN)
            ? true
            : touchpad_settings.get_boolean ("natural-scroll");
        var direction = natural_scroll ? GestureDirection.RIGHT : GestureDirection.LEFT;

        return enabled
            && gesture.type == GestureType.SWIPE
            && gesture.direction == direction
            && gesture.fingers == fingers;
    }
}


public Gala.PluginInfo register_plugin () {
    return Gala.PluginInfo () {
        name = "Touchégg",
        author = "José Expósito <jose.exposito89@gmail.com>",
        plugin_type = typeof (Gala.Plugins.Touchegg.Plugin),
        provides = Gala.PluginFunction.ADDITION,
        load_priority = Gala.LoadPriority.DEFERRED
    };
}
