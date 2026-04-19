/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.OSKWindow : Gtk.Window {
    public ModelManager model_manager { get; construct; }
    public InputManager input_manager { get; construct; }
    public IBusService ibus_service { get; construct; }

    public OSKWindow (ModelManager model_manager, InputManager input_manager, IBusService ibus_service) {
        Object (model_manager: model_manager, input_manager: input_manager, ibus_service: ibus_service);
    }

    construct {
        var suggestions = new Suggestions (ibus_service);

        var keyboard = new Keyboard (model_manager, input_manager);

        var box = new Granite.Box (VERTICAL);
        box.append (suggestions);
        box.append (keyboard);

        child = box;
        titlebar = new Gtk.Grid () { visible = false };
        title = "OSK";

        ((Gtk.Widget) this).realize.connect (update_size);
    }

    private void update_size () {
        var display = Gdk.Display.get_default ();
        var monitor = display.get_monitor_at_surface (get_surface ());
        var monitor_geom = monitor.geometry;

        default_width = monitor_geom.width;
        default_height = monitor_geom.height / 3;
    }
}
