/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.OSKFocusTracker : Object {
    public Meta.Display display { private get; construct; }
    public InputMethod im { private get; construct; }

    /**
     * The window that is currently actively receiving input. I.e.
     * the input panel is actually active and the window is focused.
     */
    public Meta.Window? current_focus_window { get; private set; }
    public int current_monitor { get; private set; }

    public OSKFocusTracker (Meta.Display display, InputMethod im) {
        Object (display: display, im: im);
    }

    construct {
        display.notify["focus-window"].connect (update_current_focus_window);
        display.grab_op_begin.connect (update_current_focus_window);
        display.grab_op_end.connect (update_current_focus_window);
        im.notify["input-panel-active"].connect (update_current_focus_window);
    }

    private void update_current_focus_window () {
        var new_focus_window = calculate_current_focus_window ();

        if (new_focus_window == current_focus_window) {
            return;
        }

        current_focus_window = new_focus_window;
        current_monitor = current_focus_window != null ? current_focus_window.get_monitor () : display.get_primary_monitor ();
    }

    private Meta.Window? calculate_current_focus_window () {
        if (!im.input_panel_active) {
            return null;
        }

        return display.focus_window;
    }
}
