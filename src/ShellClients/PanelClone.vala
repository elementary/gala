public class Gala.PanelClone : Object {
    private const int ANIMATION_DURATION = 250;

    public WindowManager wm { get; construct; }
    public PanelWindow panel { get; construct; }

    public PanelWindow.HideMode hide_mode {
        get {
            return hide_tracker.hide_mode;
        }
        set {
            hide_tracker.hide_mode = value;
        }
    }

    public bool panel_hidden { get; private set; default = false; }

    private SafeWindowClone clone;
    private Meta.WindowActor actor;
    private HideTracker hide_tracker;

    private int visible = 0;

    public PanelClone (WindowManager wm, PanelWindow panel) {
        Object (wm: wm, panel: panel);
    }

    construct {
        clone = new SafeWindowClone (panel.window, true);
        wm.ui_group.add_child (clone);

        actor = (Meta.WindowActor) panel.window.get_compositor_private ();
        // WindowActor position and Window position aren't necessarily the same.
        // The clone needs the actor position
        actor.notify["x"].connect (update_clone_position);
        actor.notify["y"].connect (update_clone_position);

        notify["panel-hidden"].connect (() => {
            update_visible ();
            hide_tracker.schedule_update ();
        });

        hide_tracker = new HideTracker (wm.get_display (), panel.window);
        hide_tracker.hide.connect (hide);
        hide_tracker.show.connect (show);

        update_visible ();
        update_clone_position ();
    }

    private void update_visible () {
        clone.visible = visible > 0;
        actor.visible = !clone.visible && !panel_hidden;
    }

    private void increase_visible () {
        visible++;
        update_visible ();
    }

    private void decrease_visible () {
        visible--;
        update_visible ();
    }

    private void increase_visible_timed (uint timeout) {
        increase_visible ();
        Timeout.add (timeout, () => {
            decrease_visible ();
            return Source.REMOVE;
        });
    }

    private void update_clone_position () {
        if (!clone.visible) {
            clone.set_position (calculate_clone_x (panel_hidden), calculate_clone_y (panel_hidden));
        }
    }

    private float calculate_clone_x (bool hidden) {
        switch (panel.anchor) {
            case TOP:
            case BOTTOM:
                return actor.x;
            default:
                return 0;
        }
    }

    private float calculate_clone_y (bool hidden) {
        switch (panel.anchor) {
            case TOP:
                return hidden ? actor.y - actor.height : actor.y;
            case BOTTOM:
                return hidden ? actor.y + actor.height : actor.y;
            default:
                return 0;
        }
    }

    public void hide () {
        if (panel_hidden) {
            return;
        }

        panel_hidden = true;

        if (panel.anchor != TOP && panel.anchor != BOTTOM) {
            warning ("Animated hide not supported for side yet.");
            return;
        }

        var animation_duration = wm.enable_animations && !wm.workspace_view.is_opened () ? ANIMATION_DURATION : 0;

        increase_visible_timed (animation_duration);

        clone.save_easing_state ();
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_easing_duration (animation_duration);
        clone.y = calculate_clone_y (true);
        clone.restore_easing_state ();
    }

    public void show () {
        if (!panel_hidden) {
            return;
        }

        var animation_duration = wm.enable_animations && !wm.workspace_view.is_opened () ? ANIMATION_DURATION : 0;

        increase_visible_timed (animation_duration);

        clone.save_easing_state ();
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_easing_duration (animation_duration);
        clone.y = calculate_clone_y (false);
        clone.restore_easing_state ();

        Timeout.add (animation_duration, () => {
            panel_hidden = false;
            return Source.REMOVE;
        });
    }
}
