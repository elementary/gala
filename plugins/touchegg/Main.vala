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

    /**
     * Percentage of the animation to be completed to apply the action.
     */
    private const int SUCCEESS_THRESHOLD = 20;

    public override void initialize (Gala.WindowManager window_manager) {
        wm = window_manager;

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
        // TODO (José Expósito) This is not being called, but I should close the socket here
    }


    private void on_handle_gesture (Gesture gesture, string event) {
        // debug (@"Gesture $(event): $(gesture.type) - $(gesture.direction) - $(gesture.fingers) fingers - $(gesture.percentage)% - $(gesture.elapsed_time) - $(gesture.performed_on_device_type)");
        var hints = build_hints_from_gesture (gesture, event);

        if (is_open_workspace_gesture (gesture)) {
            wm.workspace_view.open (hints);
        }

        if (is_close_workspace_gesture (gesture)) {
            wm.workspace_view.close (hints);
        }

        if (is_next_desktop_gesture (gesture)) {
            if (!wm.workspace_view.is_opened ()) {
                wm.switch_to_next_workspace (Meta.MotionDirection.RIGHT, hints);
            }
        }

        if (is_previous_desktop_gesture (gesture)) {
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
            hints.insert ("cancel_action", new Variant.boolean (gesture.percentage < SUCCEESS_THRESHOLD));
        }

        return hints;
    }

    // TODO (José Expósito) It'll be nice to be able to configure this from Switchboard
    // https://github.com/elementary/switchboard-plug-mouse-touchpad/issues/16

    private bool is_open_workspace_gesture (Gesture gesture) {
        return gesture.type == GestureType.SWIPE
            && gesture.direction == GestureDirection.UP
            && (gesture.fingers == 3 || gesture.fingers == 4);
    }

    private bool is_close_workspace_gesture (Gesture gesture) {
        return gesture.type == GestureType.SWIPE
            && gesture.direction == GestureDirection.DOWN
            && (gesture.fingers == 3 || gesture.fingers == 4);
    }

    // TODO (José Expósito) In addition to read this from settings, use user's natural scroll preferences
    private bool is_next_desktop_gesture (Gesture gesture) {
        return gesture.type == GestureType.SWIPE
            && gesture.direction == GestureDirection.RIGHT
            && (gesture.fingers == 3 || gesture.fingers == 4);
    }

    private bool is_previous_desktop_gesture (Gesture gesture) {
        return gesture.type == GestureType.SWIPE
            && gesture.direction == GestureDirection.LEFT
            && (gesture.fingers == 3 || gesture.fingers == 4);
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
