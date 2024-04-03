public class Gala.HideTracker : Object {
    private const uint UPDATE_TIMEOUT = 200;

    public bool should_hide { get; private set; default = false; }

    public Meta.Display display { get; construct; }
    public PanelWindow panel { get; construct; }
    public PanelWindow.HideMode hide_mode { get; construct set; }

    private bool overlap = false;
    private bool focus_overlap = false;
    private bool focus_maximized_overlap = false;

    private uint update_timeout_id = 0;

    public HideTracker (Meta.Display display, PanelWindow panel, PanelWindow.HideMode hide_mode) {
        Object (display: display, panel: panel, hide_mode: hide_mode);
    }

    construct {
        var current_focus_window = display.focus_window;
        track_focus_window (current_focus_window);
        display.notify["focus-window"].connect (() => {
            untrack_focus_window (current_focus_window);
            current_focus_window = display.focus_window;
            track_focus_window (current_focus_window);
        });

        display.window_created.connect (() => {
            schedule_update ();
        });
    }

    private void track_focus_window (Meta.Window window) {
        window.position_changed.connect (schedule_update);
        window.size_changed.connect (schedule_update);
        schedule_update ();
    }

    private void untrack_focus_window (Meta.Window window) {
        window.position_changed.disconnect (schedule_update);
        window.size_changed.disconnect (schedule_update);
        schedule_update ();
    }

    private void schedule_update () {
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
        if (panel.static_region == null) {
            warning ("No static region available, panel visibility might be wrong.");
            return;
        }

        overlap = false;
        focus_overlap = false;
        focus_maximized_overlap = false;

        foreach (var window in display.list_all_windows ()) {
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

            if (!panel.static_region.overlap (window.get_frame_rect ())) {
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
                should_hide = false;
                break;

            case MAXIMIZED_FOCUS_WINDOW:
                should_hide = focus_maximized_overlap;
                break;

            case OVERLAPPING_FOCUS_WINDOW:
                should_hide = focus_overlap;
                break;

            case OVERLAPPING_WINDOW:
                should_hide = overlap;
                break;

            case ALWAYS:
                should_hide = true;
                break;
        }
    }
}