/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

 public class Gala.MonitorLabelWindow : Object {
    public WindowManager wm { get; construct; }
    public Meta.Window window { get; construct; }
    public int monitor_index { get; construct; }

    private WindowPositioner positioner;

    public MonitorLabelWindow (WindowManager wm, Meta.Window window, int monitor_index) {
        Object (wm: wm, window: window, monitor_index: monitor_index);
    }

    construct {
        window.make_above ();

        positioner = new WindowPositioner (window, wm, (ref x, ref y) => {
            var display = wm.get_display ();

            if (monitor_index >= display.get_n_monitors ()) {
                critical ("Monitor index %d of monitor label window %s went out of bounds", monitor_index, window.title ?? "Unnamed");
                return;
            }

            var monitor_geom = display.get_monitor_geometry (monitor_index);

            x = monitor_geom.x + 12;
            y = monitor_geom.y + 12;
        });
    }
}
