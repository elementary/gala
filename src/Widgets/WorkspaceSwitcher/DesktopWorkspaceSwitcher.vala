
// TODO: We might need to hand the old active index aka from to animate_workspace_switch etc. if the workspace_manager.get_active_workspace_index () is already updated.
public class Gala.DesktopWorkspaceSwitcher : Clutter.Actor {
    private const int WORKSPACE_GAP = 24;

    public Meta.Display display { get; construct; }
    public GestureTracker gesture_tracker { get; construct; }

    private Clutter.Actor workspaces;
    private GesturePropertyTransition x_transition;

    // This is the index of the workspace that from our POV is the active one (we're animating towards it).
    // This is not necessarily the same as the index of the workspace that is actually active.
    // (e.g. when the gesture animation finishes but the workspace wasn't activated yet)
    private int active_index;

    public DesktopWorkspaceSwitcher (Meta.Display display) {
        Object (display: display);
    }

    construct {
        background_color = { 0x2e, 0x34, 0x36, 0xff };
        active_index = display.get_workspace_manager ().get_active_workspace_index ();

        workspaces = new Clutter.Actor () {
            layout_manager = new Clutter.BoxLayout () {
                orientation = HORIZONTAL,
                spacing = WORKSPACE_GAP,
            }
        };
        add_child (workspaces);

        gesture_tracker = new GestureTracker (AnimationDuration.WORKSPACE_SWITCH_MIN, AnimationDuration.WORKSPACE_SWITCH);
        gesture_tracker.enable_touchpad ();
        gesture_tracker.on_gesture_detected.connect (on_gesture_detected);
        gesture_tracker.on_gesture_handled.connect (on_gesture_handled);

        x_transition = new GesturePropertyTransition (workspaces, gesture_tracker, "x", null, 0f);
    }

    private bool on_gesture_detected (Gesture gesture) {
        var action = GestureSettings.get_action (gesture);
        return action == SWITCH_WORKSPACE || action == MOVE_TO_WORKSPACE;
    }

    private void on_gesture_handled (Gesture gesture, uint32 timestamp) {
        var direction = gesture_tracker.settings.get_natural_scroll_direction (gesture);
        var relative_dir = direction == LEFT ? -1 : 1;

        var workspace_manager = display.get_workspace_manager ();
        var target_index = active_index + relative_dir;

        animate_workspace_switch (target_index, true);

        gesture_tracker.add_success_callback (true, (percentage, completions, calculated_duration) => {
            /* We can just use the active index here because it was already updated before us by the animate_workspace_switch */
            workspace_manager.get_workspace_by_index (active_index).activate (display.get_current_time ());
        });
    }

    public void animate_workspace_switch (int target_index, bool with_gesture) {
        if (active_index == target_index) { // We've already animated e.g. via the one to one gesture
            return;
        }

        visible = true;

        if (workspaces.get_n_children () == 0) { //this might be > 0 if we interrupt an animation by starting a new gesture
            build_workspace_row ();
        }

        unowned var workspace_manager = display.get_workspace_manager ();
        var n_workspaces = workspace_manager.n_workspaces;

        x_transition.overshoot_lower_clamp = (active_index < target_index) ? - (active_index + 0.1) : - (n_workspaces - active_index - 0.9);
        x_transition.overshoot_upper_clamp = (active_index > target_index) ? (active_index + 0.1) : (n_workspaces - active_index - 0.9);
        x_transition.to_value = calculate_x (target_index);
        x_transition.start (with_gesture, end_animation);

        gesture_tracker.add_success_callback (with_gesture, (percentage, completions, calculated_duration) => {
            completions = completions.clamp ((int) x_transition.overshoot_lower_clamp, (int) x_transition.overshoot_upper_clamp);
            active_index += completions * (target_index - active_index);
        });
    }

    private void build_workspace_row () {
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
    }

    private inline float calculate_x (int index) {
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        return -index * (monitor_geom.width + WORKSPACE_GAP);
    }
}
