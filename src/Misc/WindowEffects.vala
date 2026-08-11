/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowEffects : Object {
    public Clutter.Actor ui_group { get; construct; }
    public NotificationStack notification_stack { get; construct; }

    private Gee.HashSet<Meta.WindowActor> minimizing = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> mapping = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> destroying = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> unminimizing = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> changing_size = new Gee.HashSet<Meta.WindowActor> ();

    public WindowEffects (Clutter.Actor ui_group, NotificationStack notification_stack) {
        Object (ui_group: ui_group, notification_stack: notification_stack);
    }

    public async void animate_map (Meta.WindowActor actor) {
        var window = actor.meta_window;

        mapping.add (actor);

        switch (window.window_type) {
            case Meta.WindowType.NORMAL:
                if (window.maximized_vertically || window.maximized_horizontally) {
                    var outer_rect = window.get_frame_rect ();
                    actor.set_position (outer_rect.x, outer_rect.y);
                }

                actor.set_pivot_point (0.5f, 1.0f);

                var builder = new TransitionBuilder (actor, AnimationDuration.HIDE, EASE_OUT_EXPO);
                builder.add_property_with_from ("scale-x", 0.01, 1.0);
                builder.add_property_with_from ("scale-y", 0.1, 1.0);
                builder.add_property_with_from ("opacity", 0U, 255U);
                yield builder.run ();
                break;

            case Meta.WindowType.MODAL_DIALOG:
            case Meta.WindowType.DIALOG:
                dim_parent_window (window);
                actor.set_pivot_point (0.5f, 0.5f);

                var builder = new TransitionBuilder (actor, 200, EASE_OUT_QUAD);
                builder.add_property_with_from ("scale-x", 1.05, 1.0);
                builder.add_property_with_from ("scale-y", 1.05, 1.0);
                builder.add_property_with_from ("opacity", 0U, 255U);
                yield builder.run ();
                break;

            default:
                break;
        }

        mapping.remove (actor);
    }

    private void dim_parent_window (Meta.Window window) {
        if (window.window_type != MODAL_DIALOG) {
            return;
        }

        unowned var transient = window.get_transient_for ();
        if (transient == null || transient == window) {
            warning ("No transient found");
            return;
        }

        unowned var transient_actor = (Meta.WindowActor) transient.get_compositor_private ();
        var dark_effect = new Clutter.BrightnessContrastEffect ();
        dark_effect.set_brightness (-0.4f);
        transient_actor.add_effect_with_name ("dim-parent", dark_effect);

        window.unmanaged.connect (() => {
            if (transient_actor != null && transient_actor.get_effect ("dim-parent") != null) {
                transient_actor.remove_effect_by_name ("dim-parent");
            }
        });
    }

    public async void animate_destroy (Meta.WindowActor actor) {
        var window = actor.meta_window;

        destroying.add (actor);

        switch (window.window_type) {
            case Meta.WindowType.NORMAL:
                actor.set_pivot_point (0.5f, 0.5f);
                actor.show ();

                var builder = new TransitionBuilder (actor, AnimationDuration.CLOSE, LINEAR);
                builder.add_property ("scale-x", 0.8);
                builder.add_property ("scale-y", 0.8);
                builder.add_property ("opacity", 0U);
                yield builder.run ();

                Utils.clear_window_cache (window);
                break;

            case Meta.WindowType.MODAL_DIALOG:
            case Meta.WindowType.DIALOG:
                actor.set_pivot_point (0.5f, 0.5f);

                var builder = new TransitionBuilder (actor, 150, EASE_OUT_QUAD);
                builder.add_property ("scale-x", 1.05);
                builder.add_property ("scale-y", 1.05);
                builder.add_property ("opacity", 0U);
                yield builder.run ();
                break;

            default:
                if (NotificationStack.is_notification (window)) {
                    yield notification_stack.destroy_notification (actor);
                }

                break;
        }

        destroying.remove (actor);
    }

    public async void animate_size_change (Meta.WindowActor actor, Mtk.Rectangle old_rect, Mtk.Rectangle new_rect, Clutter.Actor snapshot) {
        kill_window_effects (actor);

        changing_size.add (actor);

        snapshot.set_position (old_rect.x, old_rect.y);

        ui_group.add_child (snapshot);

        var scale_x = (double) new_rect.width / old_rect.width;
        var scale_y = (double) new_rect.height / old_rect.height;

        snapshot.save_easing_state ();
        snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
        snapshot.set_easing_duration (AnimationDuration.SNAP);
        snapshot.set_position (new_rect.x, new_rect.y);
        snapshot.set_scale (scale_x, scale_y);
        snapshot.opacity = 0;
        snapshot.restore_easing_state ();

        actor.set_pivot_point (0.0f, 0.0f);

        var actor_transition_builder = new TransitionBuilder (actor, AnimationDuration.SNAP, EASE_IN_OUT_QUAD);
        actor_transition_builder.add_property_with_from ("scale-x", 1.0 / scale_x, 1.0);
        actor_transition_builder.add_property_with_from ("scale-y", 1.0 / scale_y, 1.0);
        actor_transition_builder.add_property_with_from ("translation-x", (float) (old_rect.x - new_rect.x), 0.0f);
        actor_transition_builder.add_property_with_from ("translation-y", (float) (old_rect.y - new_rect.y), 0.0f);

        yield actor_transition_builder.run ();

        ui_group.remove_child (snapshot);
        changing_size.remove (actor);
    }

    public async void animate_minimize (Meta.WindowActor actor) {
        if (actor.get_meta_window ().window_type != NORMAL) {
            return;
        }

        kill_window_effects (actor);
        minimizing.add (actor);

        var builder = new TransitionBuilder (actor, AnimationDuration.HIDE, EASE_IN_EXPO);

        Mtk.Rectangle icon = {};
        if (actor.get_meta_window ().get_icon_geometry (out icon)) {
            var display = actor.meta_window.display;

            // Fix icon position and size according to ui scaling factor.
            var ui_scale = display.get_monitor_scale (display.get_monitor_index_for_rect (icon));
            icon.x = Utils.scale_to_int (icon.x, ui_scale);
            icon.y = Utils.scale_to_int (icon.y, ui_scale);
            icon.width = Utils.scale_to_int (icon.width, ui_scale);
            icon.height = Utils.scale_to_int (icon.height, ui_scale);

            actor.set_pivot_point (
                (actor.x - icon.x) / (icon.width - actor.width),
                (actor.y - icon.y) / (icon.height - actor.height)
            );

            builder.add_property ("scale-x", (double) (icon.width / actor.width));
            builder.add_property ("scale-y", (double) (icon.height / actor.height));
        } else {
            actor.set_pivot_point (0.5f, 1.0f);

            builder.add_property ("scale-x", 0.0);
            builder.add_property ("scale-y", 0.0);
        }

        builder.add_property ("opacity", 0u);

        yield builder.run ();

        actor.set_pivot_point (0.0f, 0.0f);
        minimizing.remove (actor);
    }

    public async void animate_unminimize (Meta.WindowActor actor) {
        actor.show ();

        if (actor.meta_window.window_type != NORMAL) {
            return;
        }

        actor.remove_all_transitions ();

        unminimizing.add (actor);

        actor.set_pivot_point (0.5f, 1.0f);

        var builder = new TransitionBuilder (actor, AnimationDuration.HIDE, EASE_OUT_EXPO);
        builder.add_property_with_from ("scale-x", 0.01, 1.0);
        builder.add_property_with_from ("scale-y", 0.1, 1.0);
        builder.add_property_with_from ("opacity", 0U, 255U);

        yield builder.run ();

        unminimizing.remove (actor);
    }

    public void kill_window_effects (Meta.WindowActor actor) {
        end_animation (ref unminimizing, actor);
        end_animation (ref minimizing, actor);
        end_animation (ref mapping, actor);
        end_animation (ref destroying, actor);
        end_animation (ref changing_size, actor);
    }

    // Cancel attached animation of an actor and reset it
    private bool end_animation (ref Gee.HashSet<Meta.WindowActor> list, Meta.WindowActor actor) {
        if (!list.contains (actor))
            return false;

        if (actor.is_destroyed ()) {
            list.remove (actor);
            return false;
        }

        actor.remove_all_transitions ();
        actor.opacity = 255U;
        actor.set_scale (1.0f, 1.0f);
        actor.rotation_angle_x = 0.0f;
        actor.set_pivot_point (0.0f, 0.0f);

        list.remove (actor);
        return true;
    }
}
