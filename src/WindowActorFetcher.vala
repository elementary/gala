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

    public WindowActorFetcher (Meta.Window window) {
        Object (window: window);
    }

    construct {
        Idle.add (() => {
            if (window == null) {
                return Source.REMOVE;
            }

            unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();

            if (window_actor != null) {
                window_actor_ready ();

                return Source.REMOVE;
            }

            return Source.CONTINUE;
        });
    }
}
