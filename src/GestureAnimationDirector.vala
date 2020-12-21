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

public class Gala.GestureAnimationDirector : Object {
    public bool running { get; set; default = false; }
    public bool canceling { get; set; default = false; }

    public signal void on_animation_begin (int percentage);
    public signal void on_animation_update (int percentage);
    public signal void on_animation_end (int percentage, bool cancel_action);

    public delegate void OnBegin (int percentage);
    public delegate void OnUpdate (int percentage);
    public delegate void OnEnd (int percentage, bool cancel_action);

    private Gee.ArrayList<ulong> handlers;

    construct {
        handlers = new Gee.ArrayList<ulong> ();
    }

    public void connect_handlers (owned OnBegin? on_begin, owned OnUpdate? on_update, owned OnEnd? on_end) {
        if (on_begin != null) {
            ulong handler_id = on_animation_begin.connect ((percentage) => on_begin (percentage));
            handlers.add (handler_id);
        }

        if (on_update != null) {
            ulong handler_id = on_animation_update.connect ((percentage) => on_update (percentage));
            handlers.add (handler_id);
        }

        if (on_end != null) {
            ulong handler_id = on_animation_end.connect ((percentage, cancel_action) => on_end (percentage, cancel_action));
            handlers.add (handler_id);
        }
    }

    public void disconnect_all_handlers () {
        foreach (var handler in handlers) {
            disconnect (handler);
        }

        handlers.clear ();
    }

    public void update_animation (HashTable<string,Variant> hints) {
        string event = hints.get ("event").get_string ();
        int32 percentage = hints.get ("percentage").get_int32 ();

        switch (event) {
            case "begin":
                on_animation_begin (percentage);
                break;
            case "update":
                on_animation_update (percentage);
                break;
            case "end":
            default:
                var cancel_action = hints.get ("cancel_action").get_boolean ();
                on_animation_end (percentage, cancel_action);
                break;
        }
    }

    public static float animation_value (float initial_value, float target_value, int percentage) {
        return (((target_value - initial_value) * percentage) / 100) + initial_value;
    }
}
