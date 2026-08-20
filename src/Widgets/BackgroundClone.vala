/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.BackgroundClone : Clutter.Actor {
    public Meta.Display display { get; construct; }
    public int monitor_index { get; construct; }

    public BackgroundClone (Meta.Display display, int monitor_index) {
        Object (display: display, monitor_index: monitor_index);
    }

    construct {
        var filter = new Gtk.CustomFilter (desktop_window_filter_func);
        var window_list_model = new WindowListModel (display, STACKING, false, false, monitor_index, null, filter);

        bind_model (window_list_model, create_child_func);
    }

    private static bool desktop_window_filter_func (Object obj) {
        var window = (Meta.Window) obj;
        return window.window_type == DESKTOP;
    }

    private static Clutter.Actor create_child_func (Object obj) {
        var window = (Meta.Window) obj;
        var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        return new Clutter.Clone (window_actor);
    }
}
