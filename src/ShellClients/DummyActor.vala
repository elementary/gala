/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

/* This class is used to workaround https://github.com/elementary/gala/issues/2101 */
public class Gala.DummyActor : GLib.Object {
    public const int OUT_OF_BOUNDS = 1000000;

    public Meta.WindowActor actor { get; construct; }
    
    /* Current window actor position or position before the window was moved out of bounds */
    public float x { get; private set; default = 0.0f; }
    public float y { get; private set; default = 0.0f; }

    /* Current window position or position before it was moved out of bounds */
    public int actual_x { get; private set; default = 0; }
    public int actual_y { get; private set; default = 0; }

    public DummyActor (Meta.WindowActor actor) {
        Object (actor: actor);
    }

    construct {
        actor.meta_window.position_changed.connect ((_window) => {
            var rect = _window.get_frame_rect ();
            warning ("Position changed %d %d", rect.x, rect.y);

            if (rect.x != OUT_OF_BOUNDS) {
                actual_x = rect.x;
                Idle.add_once (() => {
                    x = actor.x;
                });
            }
            if (rect.y != OUT_OF_BOUNDS) {
                actual_y = rect.y;
                Idle.add_once (() => {
                    y = actor.y;
                });
            }
        });
    }
}
