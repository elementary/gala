/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * A container for a clone of the texture of a MetaWindow, with WindowType.Desktop.
 */
 public class Gala.DesktopWindowClone : Clutter.Actor {
    public Meta.Window window { get; construct; }

    private Clutter.Clone? clone = null;

    public DesktopWindowClone (Meta.Window window) {
        Object (window: window);
    }

    construct {
        window.unmanaged.connect (unmanaged);

        load_clone ();
    }

    ~DesktopWindowClone () {
        window.unmanaged.disconnect (unmanaged);
    }

    /**
     * Waits for the texture of a new Meta.WindowActor to be available
     * and makes a close of it. If it was already was assigned a slot
     * at this point it will animate to it. Otherwise it will just place
     * itself at the location of the original window. Also adds the shadow
     * effect and makes sure the shadow is updated on size changes.
     */
    private void load_clone () {
        var actor = (Meta.WindowActor) window.get_compositor_private ();
        if (actor == null) {
            Idle.add (() => {
                if (window.get_compositor_private () != null) {
                    load_clone ();
                }
                return Source.REMOVE;
            });

            return;
        }

        clone = new Clutter.Clone (actor);
        add_child (clone);

        var outer_rect = window.get_frame_rect ();

        var monitor_geom = window.get_display ().get_monitor_geometry (window.get_monitor ());
        var offset_x = monitor_geom.x;
        var offset_y = monitor_geom.y;

        var target_x = outer_rect.x - offset_x;
        var target_y = outer_rect.y - offset_y;

        set_position (target_x, target_y);
        set_size (outer_rect.width, outer_rect.height);
    }

    /**
     * The window unmanaged by the compositor, so we need to destroy ourselves too.
     */
    private void unmanaged () {
        remove_all_transitions ();

        if (clone != null) {
            clone.destroy ();
        }

        destroy ();
    }
}
