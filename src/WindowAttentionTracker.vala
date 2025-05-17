/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.WindowAttentionTracker : GLib.Object {
    private static GLib.Settings behavior_settings;

    public static void init (Meta.Display display) {
        behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");

        display.window_demands_attention.connect (on_window_demands_attention);
        display.window_marked_urgent.connect (on_window_demands_attention);
    }

    private static void on_window_demands_attention (Meta.Window window) {
        if (behavior_settings.get_boolean ("focus-on-demands-attention")) {
            window.raise ();
            window.get_workspace ().activate_with_focus (window, window.display.get_current_time ());
        }
    }
}
