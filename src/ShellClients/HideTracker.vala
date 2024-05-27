/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.HideTracker : Object {
    private const uint UPDATE_TIMEOUT = 200;

    public signal void hide ();
    public signal void show ();

    public Meta.Display display { get; construct; }
    public PanelWindow panel { get; construct; }
    public Pantheon.Desktop.HideMode hide_mode { get; set; default = NEVER; }

    private bool hovered = false;

    private bool overlap = false;
    private bool focus_overlap = false;
    private bool focus_maximized_overlap = false;

    private Meta.Window current_focus_window;

    private uint update_timeout_id = 0;

    public HideTracker (Meta.Display display, PanelWindow panel) {
        Object (display: display, panel: panel);
    }

    construct {
        // Can't be local otherwise we get a memory leak :(
        // See https://gitlab.gnome.org/GNOME/vala/-/issues/1548
        current_focus_window = display.focus_window;
        track_focus_window (current_focus_window);
        display.notify["focus-window"].connect (() => {
            untrack_focus_window (current_focus_window);
            current_focus_window = display.focus_window;
            track_focus_window (current_focus_window);
        });

        display.window_created.connect ((window) => {
            schedule_update ();
            window.unmanaged.connect (schedule_update);
        });

        var cursor_tracker = display.get_cursor_tracker ();
        cursor_tracker.position_invalidated.connect (() => {
#if HAS_MUTTER45
            var has_pointer = panel.window.has_pointer ();
#else
            var has_pointer = window_has_pointer ();
#endif

            if (hovered != has_pointer) {
                hovered = has_pointer;
                schedule_update ();
            }
        });

        display.get_workspace_manager ().active_workspace_changed.connect (schedule_update);
    }

    //Can be removed with mutter > 45
    private bool window_has_pointer () {
        var cursor_tracker = display.get_cursor_tracker ();
        Graphene.Point pointer_pos;
        cursor_tracker.get_pointer (out pointer_pos, null);

        var window_rect = panel.get_custom_window_rect ();
        Graphene.Rect graphene_window_rect = {
            {
                window_rect.x,
                window_rect.y
            },
            {
                window_rect.width,
                window_rect.height
            }
        };
        return graphene_window_rect.contains_point (pointer_pos);
    }

    private void track_focus_window (Meta.Window? window) {
        if (window == null) {
            return;
        }

        window.position_changed.connect (schedule_update);
        window.size_changed.connect (schedule_update);
        schedule_update ();
    }

    private void untrack_focus_window (Meta.Window? window) {
        if (window == null) {
            return;
        }

        window.position_changed.disconnect (schedule_update);
        window.size_changed.disconnect (schedule_update);
        schedule_update ();
    }

    public void schedule_update () {
        if (update_timeout_id != 0) {
            return;
        }

        update_timeout_id = Timeout.add (UPDATE_TIMEOUT, () => {
            update_overlap ();
            update_timeout_id = 0;
            return Source.REMOVE;
        });
    }

    private void update_overlap () {
        overlap = false;
        focus_overlap = false;
        focus_maximized_overlap = false;

        foreach (var window in display.get_workspace_manager ().get_active_workspace ().list_windows ()) {
            if (window == panel.window) {
                continue;
            }

            if (window.minimized) {
                continue;
            }

            var type = window.get_window_type ();
            if (type == DESKTOP || type == DOCK || type == MENU || type == SPLASHSCREEN) {
                continue;
            }

            if (!panel.get_custom_window_rect ().overlap (window.get_frame_rect ())) {
                continue;
            }

            overlap = true;

            if (window != display.focus_window) {
                continue;
            }

            focus_overlap = true;
            focus_maximized_overlap = window.get_maximized () == BOTH;
        }

        update_hidden ();
    }

    private void update_hidden () {
        switch (hide_mode) {
            case NEVER:
                toggle_display (false);
                break;

            case MAXIMIZED_FOCUS_WINDOW:
                toggle_display (focus_maximized_overlap);
                break;

            case OVERLAPPING_FOCUS_WINDOW:
                toggle_display (focus_overlap);
                break;

            case OVERLAPPING_WINDOW:
                toggle_display (overlap);
                break;

            case ALWAYS:
                toggle_display (true);
                break;
        }
    }

    private void toggle_display (bool should_hide) {
#if HAS_MUTTER45
        hovered = panel.window.has_pointer ();
#else
        hovered = window_has_pointer ();
#endif

        if (should_hide && !hovered) {
            // Don't hide if we have transients, e.g. an open popover, dialog, etc.
            var has_transients = false;
            panel.window.foreach_transient (() => {
                has_transients = true;
                return false;
            });

            if (has_transients) {
                return;
            }

            hide ();
        } else {
            show ();
        }
    }
}
