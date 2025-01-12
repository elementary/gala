
// TODO: We might need to hand the old active index aka from to animate_workspace_switch etc. if the workspace_manager.get_active_workspace_index () is already updated.
public class Gala.DesktopWorkspaceSwitcher : Clutter.Actor {
    private const int WORKSPACE_GAP = 10;

    public signal void completed ();

    public Meta.Display display { get; construct; }
    public GestureTracker gesture_tracker { get; construct; }

    private Clutter.Actor workspaces;
    private GesturePropertyTransition x_transition;

    public DesktopWorkspaceSwitcher (Meta.Display display, GestureTracker gesture_tracker) {
        Object (display: display, gesture_tracker: gesture_tracker);
    }

    construct {
        background_color = { 0x2e, 0x34, 0x36, 0xff };

        workspaces = new Clutter.Actor () {
            layout_manager = new Clutter.BoxLayout () {
                orientation = HORIZONTAL,
                spacing = WORKSPACE_GAP,
            }
        };
        add_child (workspaces);

        x_transition = new GesturePropertyTransition (workspaces, gesture_tracker, "x", null, 0f);
    }

    public void switch_workspace_with_gesture (GestureDirection direction) {
        var relative_dir = direction == LEFT ? -1 : 1;

        var workspace_manager = display.get_workspace_manager ();
        var active_index = workspace_manager.get_active_workspace_index ();
        var target_index = active_index + relative_dir;

        animate_workspace_switch (active_index, target_index, true);

        GestureTracker.OnEnd on_animation_end = (percentage, completions, calculated_duration) => {
            completions = completions.clamp ((int) x_transition.overshoot_lower_clamp, (int) x_transition.overshoot_upper_clamp);
            workspace_manager.get_workspace_by_index (active_index + completions * relative_dir).activate (display.get_current_time ());
        };

        if (!AnimationsSettings.get_enable_animations ()) {
            on_animation_end (1, 1, 0);
        } else {
            gesture_tracker.connect_handlers (null, null, (owned) on_animation_end);
        }
    }

    public void animate_workspace_switch (int active_index, int target_index, bool with_gesture) {
        visible = true;

        if (workspaces.get_n_children () == 0) { //this might be > 0 if we interrupt an animation by starting a new gesture
            build_workspace_row (active_index);
        }

        unowned var workspace_manager = display.get_workspace_manager ();
        var n_workspaces = workspace_manager.n_workspaces;

        x_transition.overshoot_lower_clamp = (active_index < target_index) ? - (active_index + 0.1) : - (n_workspaces - active_index - 0.9);
        x_transition.overshoot_upper_clamp = (active_index > target_index) ? (active_index + 0.1) : (n_workspaces - active_index - 0.9);
        x_transition.to_value = calculate_x (target_index);
        x_transition.start (with_gesture, end_animation);
    }

    private void build_workspace_row (int active_index) {
        unowned var workspace_manager = display.get_workspace_manager ();
        for (int i = 0; i <= workspace_manager.n_workspaces; i++) {
            var workspace = workspace_manager.get_workspace_by_index (i);

            var workspace_clone = new DesktopWorkspaceClone (workspace);
            workspaces.add_child (workspace_clone);
        }

        workspaces.x = calculate_x (active_index);
    }

    public void end_animation () {
        workspaces.remove_all_children ();
        visible = false;
        completed ();
    }

    private inline float calculate_x (int index) {
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        return -index * (monitor_geom.width + WORKSPACE_GAP);
    }
}
