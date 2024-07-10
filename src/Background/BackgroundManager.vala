/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 *                         2014 Tom Beckmann
 */

public class Gala.BackgroundManager : Meta.BackgroundGroup, Gala.BackgroundManagerInterface {
    private const double DIM_OPACITY = 0.55;
    private const int FADE_ANIMATION_TIME = 1000;

    public signal void changed ();

    public WindowManager wm { get; construct; }
    public int monitor_index { get; construct; }
    public bool control_position { get; construct; }
    public Meta.BackgroundActor newest_background_actor {
        get {
            return (new_background_actor != null) ? new_background_actor : background_actor;
        }
    }

    private BackgroundSource background_source;
    private Meta.BackgroundActor? background_actor;
    private Meta.BackgroundActor? new_background_actor = null;

    public BackgroundManager (WindowManager wm, int monitor_index, bool control_position = true) {
        Object (wm: wm, monitor_index: monitor_index, control_position: control_position);
    }

    construct {
        background_source = BackgroundCache.get_default ().get_background_source (wm.get_display ());
        update_background_actor (false);

        destroy.connect (on_destroy);
    }

    private void on_destroy () {
        BackgroundCache.get_default ().release_background_source ();
        background_source = null;

        if (new_background_actor != null) {
            new_background_actor.destroy ();
            new_background_actor = null;
        }

        if (background_actor != null) {
            background_actor.destroy ();
            background_actor = null;
        }
    }

    private void swap_background_actor (bool animate) requires (new_background_actor != null) {
        var old_background_actor = background_actor;
        background_actor = new_background_actor;
        new_background_actor = null;

        changed ();

        if (old_background_actor == null) {
            return;
        }

        if (animate && wm.enable_animations) {
            var transition = new Clutter.PropertyTransition ("opacity");
            transition.set_from_value (255);
            transition.set_to_value (0);
            transition.duration = FADE_ANIMATION_TIME;
            transition.progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD;
            transition.remove_on_complete = true;
            transition.completed.connect (() => {
                old_background_actor.destroy ();
            });

            old_background_actor.add_transition ("fade-out", transition);
        } else {
            old_background_actor.destroy ();
        }

    }

    private void update_background_actor (bool animate = true) {
        if (new_background_actor != null) {
            // Skip displaying existing background queued for load
            new_background_actor.destroy ();
            new_background_actor = null;
        }

        new_background_actor = create_background_actor ();
        var new_content = (Meta.BackgroundContent)new_background_actor.content;

        var background = new_content.background.get_data<unowned Background> ("delegate");

        if (background.is_loaded) {
            new_content.rounded_clip_radius = Utils.scale_to_int (6, wm.get_display ().get_monitor_scale (monitor_index));
            swap_background_actor (animate);
            return;
        }

        ulong handler = 0;
        handler = background.loaded.connect (() => {
            background.disconnect (handler);
            background.set_data<ulong> ("background-loaded-handler", 0);

            swap_background_actor (animate);
            new_content.rounded_clip_radius = Utils.scale_to_int (6, wm.get_display ().get_monitor_scale (monitor_index));
        });
        background.set_data<ulong> ("background-loaded-handler", handler);
    }

    public new void set_size (float width, float height) {
        if (width != background_actor.width || height != background_actor.height) {
            update_background_actor (false);
        }
    }

    private Meta.BackgroundActor create_background_actor () {
        unowned var display = wm.get_display ();

        var background = background_source.get_background (monitor_index);
        var background_actor = new Meta.BackgroundActor (display, monitor_index);

        unowned var content = (Meta.BackgroundContent) background_actor.content;
        content.background = background.background;

        var monitor = display.get_monitor_geometry (monitor_index);

        if (background_source.should_dim) {
            content.vignette = true;
            content.brightness = DIM_OPACITY;
        }

        insert_child_below (background_actor, null);

        background_actor.set_size (monitor.width, monitor.height);

        if (control_position) {
            background_actor.set_position (monitor.x, monitor.y);
        }

        ulong changed_handler = 0;
        changed_handler = background.changed.connect (() => {
            background.disconnect (changed_handler);
            changed_handler = 0;
            update_background_actor ();
        });

        background_actor.destroy.connect (() => {
            if (changed_handler != 0) {
                background.disconnect (changed_handler);
                changed_handler = 0;
            }

            var loaded_handler = background.get_data<ulong> ("background-loaded-handler");
            if (loaded_handler != 0) {
                background.disconnect (loaded_handler);
                background.set_data<ulong> ("background-loaded-handler", 0);
            }
        });

        return background_actor;
    }
}
