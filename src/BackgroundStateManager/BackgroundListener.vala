// TODO: Copyright

public class Gala.BackgroundListener : GLib.Object {
    private const int WALLPAPER_TRANSITION_DURATION = 150;

    public signal void state_changed (BackgroundState state, uint animation_duration);

    public WindowManager wm { private get; construct; }

    private unowned Meta.Workspace? current_workspace = null;
    private BackgroundState current_bg_state = TRANSLUCENT_LIGHT;
    private BackgroundState current_real_state = TRANSLUCENT_LIGHT;

    public BackgroundListener (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        connect_signals ();
        update_current_workspace ();
    }

    private void connect_signals () {
        unowned var manager = wm.get_display ().get_workspace_manager ();
        manager.workspace_switched.connect (update_current_workspace);

        ((BackgroundContainer) wm.background_group).color_information_updated.connect (update_state);
    }

    private void update_state (BackgroundState new_state) {
        if (new_state != current_bg_state) {
            current_bg_state = new_state;
            check_for_state_change (WALLPAPER_TRANSITION_DURATION);
        }

    }

    private void update_current_workspace () {
        unowned Meta.WorkspaceManager manager = wm.get_display ().get_workspace_manager ();
        unowned var workspace = manager.get_active_workspace ();

        if (current_workspace != null) {
            current_workspace.window_added.disconnect (on_window_added);
            current_workspace.window_removed.disconnect (on_window_removed);
        }

        current_workspace = workspace;

        foreach (unowned Meta.Window window in current_workspace.list_windows ()) {
            if (window.is_on_primary_monitor ()) {
                register_window (window);
            }
        }

        current_workspace.window_added.connect (on_window_added);
        current_workspace.window_removed.connect (on_window_removed);

        check_for_state_change (AnimationDuration.WORKSPACE_SWITCH_MIN);
    }

    private void register_window (Meta.Window window) {
        window.notify["maximized-vertically"].connect (() => {
            check_for_state_change (AnimationDuration.SNAP);
        });

        window.notify["minimized"].connect (() => {
            check_for_state_change (AnimationDuration.HIDE);
        });

        window.workspace_changed.connect (() => {
            check_for_state_change (AnimationDuration.WORKSPACE_SWITCH_MIN);
        });
    }

    private void on_window_added (Meta.Window window) {
        register_window (window);

        check_for_state_change (AnimationDuration.SNAP);
    }

    private void on_window_removed (Meta.Window window) {
        check_for_state_change (AnimationDuration.SNAP);
    }

    private void check_for_state_change (uint animation_duration) {
        bool has_maximized_window = false;

        foreach (unowned Meta.Window window in current_workspace.list_windows ()) {
            if (window.is_on_primary_monitor ()) {
                if (!window.minimized && window.maximized_vertically) {
                    has_maximized_window = true;
                    break;
                }
            }
        }

        var new_state = has_maximized_window ? BackgroundState.MAXIMIZED : current_bg_state;

        if (new_state != current_real_state) {
            current_real_state = new_state;
            state_changed (new_state, animation_duration);
        }
    }
}
