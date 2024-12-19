/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

/*
 * Sends a signal when a window actor is ready.
 * Useful when you need to use window actor when the window was created.
 */
public class Gala.WindowActorFetcher : GLib.Object {
    public signal void window_actor_ready ();

    public Meta.Window window { get; construct; }

    private uint idle_id = 0;

    public WindowActorFetcher (Meta.Window window) {
        Object (window: window);
    }

    ~WindowActorFetcher () {
        if (idle_id > 0) {
            Source.remove (idle_id);
        }
    }

    construct {
        idle_id = Idle.add (() => {
            if (window == null) {
                idle_id = 0;
                return Source.REMOVE;
            }

            unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();

            if (window_actor != null) {
                window_actor_ready ();
                idle_id = 0;

                return Source.REMOVE;
            }

            return Source.CONTINUE;
        });
    }
}
