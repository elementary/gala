/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2025 elementary, Inc. (https://elementary.io)
 */

/**
 * A clone for a MetaWindowActor that will guard against the
 * meta_window_appears_focused crash by disabling painting the clone
 * as soon as it gets unavailable.
 */
public class Gala.SafeWindowClone : Clutter.Clone {
    public Meta.Window window { get; construct; }

    /**
     * If set to true, the SafeWindowClone will destroy itself when the connected
     * window is unmanaged
     */
    public bool destroy_on_unmanaged { get; construct set; default = false; }

    /**
     * Creates a new SafeWindowClone
     *
     * @param window               The window to clone from
     * @param destroy_on_unmanaged see destroy_on_unmanaged property
     */
    public SafeWindowClone (Meta.Window window, bool destroy_on_unmanaged = false) {
        var actor = (Meta.WindowActor) window.get_compositor_private ();

        Object (window: window,
                source: actor,
                destroy_on_unmanaged: destroy_on_unmanaged);
    }

    construct {
        if (source != null)
            window.unmanaged.connect (reset_source);
    }

    ~SafeWindowClone () {
        window.unmanaged.disconnect (reset_source);
    }

    private void reset_source () {
        // actually destroying the clone will be handled somewhere else (unless we were
        // requested to destroy it), we just need to make sure the clone doesn't attempt
        // to draw a clone of a window that has been destroyed
        source = null;

        if (destroy_on_unmanaged)
            destroy ();
    }
}
