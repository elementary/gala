/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowEffects : Object {
    public WindowManager wm { private get; construct; }

    private Gee.HashSet<Meta.WindowActor> minimizing = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> maximizing = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> unmaximizing = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> mapping = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> destroying = new Gee.HashSet<Meta.WindowActor> ();
    private Gee.HashSet<Meta.WindowActor> unminimizing = new Gee.HashSet<Meta.WindowActor> ();
    private Meta.SizeChange? which_change = null;
    private Mtk.Rectangle old_rect_size_change;
    private Clutter.Actor? latest_window_snapshot;

    public async void animate_map (Meta.WindowActor actor) {
        unowned var window = actor.meta_window;

        actor.remove_all_transitions ();
        actor.show ();

        // Notifications initial animation is handled by the notification stack
        if (NotificationStack.is_notification (window) || !Meta.Prefs.get_gnome_animations ()) {
            dim_parent_window (window);
            return;
        }

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
                break;
        }

        destroying.remove (actor);
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

    // must wait for size_changed to get updated frame_rect
    // as which_change is not passed to size_changed, save it as instance variable
    public void size_change (Meta.WindowActor actor, Meta.SizeChange which_change, Mtk.Rectangle old_frame_rect, Mtk.Rectangle old_buffer_rect) {
        this.which_change = which_change;
        old_rect_size_change = old_frame_rect;

        if (Meta.Prefs.get_gnome_animations ()) {
            latest_window_snapshot = Utils.get_window_actor_snapshot (actor, old_frame_rect);
        }
    }

    // size_changed gets called after frame_rect has updated
    public void size_changed (Meta.WindowActor actor) {
        if (which_change == null) {
            return;
        }

        unowned var window = actor.get_meta_window ();
        var new_rect = window.get_frame_rect ();

        switch (which_change) {
            case Meta.SizeChange.MAXIMIZE:
            case Meta.SizeChange.FULLSCREEN:
                // don't animate resizing of two tiled windows with mouse drag
                if (window.get_tile_match () != null && !window.maximized_horizontally) {
                    var old_end = old_rect_size_change.x + old_rect_size_change.width;
                    var new_end = new_rect.x + new_rect.width;

                    // a tiled window is just resized (and not moved) if its start_x or its end_x stays the same
                    if (old_rect_size_change.x == new_rect.x || old_end == new_end) {
                        break;
                    }
                }

                maximize (actor, new_rect.x, new_rect.y, new_rect.width, new_rect.height);
                break;
            case Meta.SizeChange.UNMAXIMIZE:
            case Meta.SizeChange.UNFULLSCREEN:
                unmaximize (actor, new_rect.x, new_rect.y, new_rect.width, new_rect.height);
                break;
            default:
                break;
        }

        which_change = null;
    }


    private void maximize (Meta.WindowActor actor, int ex, int ey, int ew, int eh) {
        unowned var window = actor.get_meta_window ();

        wm.kill_window_effects (actor);

        if (!Meta.Prefs.get_gnome_animations () ||
            latest_window_snapshot == null ||
            window.window_type != Meta.WindowType.NORMAL) {
            return;
        }

        var duration = AnimationDuration.SNAP;

        maximizing.add (actor);
        latest_window_snapshot.set_position (old_rect_size_change.x, old_rect_size_change.y);

        wm.ui_group.add_child (latest_window_snapshot);

        // FIMXE that's a hacky part. There is a short moment right after maximized_completed
        //       where the texture is screwed up and shows things it's not supposed to show,
        //       resulting in flashing. Waiting here transparently shortly fixes that issue. There
        //       appears to be no signal that would inform when that moment happens.
        //       We can't spend arbitrary amounts of time transparent since the overlay fades away,
        //       about a third has proven to be a solid time. So this fix will only apply for
        //       durations >= FLASH_PREVENT_TIMEOUT*3
        const int FLASH_PREVENT_TIMEOUT = 80;
        var delay = 0;
        if (FLASH_PREVENT_TIMEOUT <= duration / 3) {
            actor.opacity = 0;
            delay = FLASH_PREVENT_TIMEOUT;
            Timeout.add (FLASH_PREVENT_TIMEOUT, () => {
                actor.opacity = 255;
                return false;
            });
        }

        var scale_x = (double) ew / old_rect_size_change.width;
        var scale_y = (double) eh / old_rect_size_change.height;

        latest_window_snapshot.save_easing_state ();
        latest_window_snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
        latest_window_snapshot.set_easing_duration (duration);
        latest_window_snapshot.set_position (ex, ey);
        latest_window_snapshot.set_scale (scale_x, scale_y);
        latest_window_snapshot.restore_easing_state ();

        // the opacity animation is special, since we have to wait for the
        // FLASH_PREVENT_TIMEOUT to be done before we can safely fade away
        latest_window_snapshot.save_easing_state ();
        latest_window_snapshot.set_easing_delay (delay);
        latest_window_snapshot.set_easing_duration (duration - delay);
        latest_window_snapshot.opacity = 0;
        latest_window_snapshot.restore_easing_state ();

        ulong maximize_old_handler_id = 0;
        maximize_old_handler_id = latest_window_snapshot.transition_stopped.connect ((snapshot, name, is_finished) => {
            snapshot.disconnect (maximize_old_handler_id);

            actor.set_translation (0.0f, 0.0f, 0.0f);

            unowned var parent = snapshot.get_parent ();
            if (parent != null) {
                parent.remove_child (snapshot);
            }
        });

        latest_window_snapshot = null;

        actor.set_pivot_point (0.0f, 0.0f);
        actor.set_translation (old_rect_size_change.x - ex, old_rect_size_change.y - ey, 0.0f);
        actor.set_scale (1.0f / scale_x, 1.0f / scale_y);

        actor.save_easing_state ();
        actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
        actor.set_easing_duration (duration);
        actor.set_scale (1.0f, 1.0f);
        actor.set_translation (0.0f, 0.0f, 0.0f);
        actor.restore_easing_state ();

        ulong handler_id = 0UL;
        handler_id = actor.transitions_completed.connect (() => {
            actor.disconnect (handler_id);
            maximizing.remove (actor);
        });
    }

    private void unmaximize (Meta.WindowActor actor, int ex, int ey, int ew, int eh) {
        unowned var window = actor.get_meta_window ();

        wm.kill_window_effects (actor);

        if (!Meta.Prefs.get_gnome_animations () ||
            latest_window_snapshot == null ||
            window.window_type != Meta.WindowType.NORMAL) {
            return;
        }

        var duration = AnimationDuration.SNAP;

        float offset_x, offset_y;
        var unmaximized_window_geometry = WindowListener.get_default ().get_unmaximized_state_geometry (window);

        if (unmaximized_window_geometry != null) {
            offset_x = unmaximized_window_geometry.outer.x - unmaximized_window_geometry.inner.x;
            offset_y = unmaximized_window_geometry.outer.y - unmaximized_window_geometry.inner.y;
        } else {
            offset_x = 0;
            offset_y = 0;
        }

        unmaximizing.add (actor);

        latest_window_snapshot.set_position (old_rect_size_change.x, old_rect_size_change.y);

        wm.ui_group.add_child (latest_window_snapshot);

        var scale_x = (float) ew / old_rect_size_change.width;
        var scale_y = (float) eh / old_rect_size_change.height;

        latest_window_snapshot.save_easing_state ();
        latest_window_snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
        latest_window_snapshot.set_easing_duration (duration);
        latest_window_snapshot.set_position (ex, ey);
        latest_window_snapshot.set_scale (scale_x, scale_y);
        latest_window_snapshot.opacity = 0U;
        latest_window_snapshot.restore_easing_state ();

        ulong unmaximize_old_handler_id = 0;
        unmaximize_old_handler_id = latest_window_snapshot.transition_stopped.connect ((snapshot, name, is_finished) => {
            snapshot.disconnect (unmaximize_old_handler_id);

            unowned var parent = snapshot.get_parent ();
            if (parent != null) {
                parent.remove_child (snapshot);
            }
        });

        latest_window_snapshot = null;

        var buffer_rect = window.get_buffer_rect ();
        var frame_rect = window.get_frame_rect ();
        var real_actor_offset_x = frame_rect.x - buffer_rect.x;
        var real_actor_offset_y = frame_rect.y - buffer_rect.y;

        actor.set_pivot_point (0.0f, 0.0f);
        actor.set_position (ex - real_actor_offset_x, ey - real_actor_offset_y);
        actor.set_translation (-ex + offset_x * (1.0f / scale_x - 1.0f) + old_rect_size_change.x, -ey + offset_y * (1.0f / scale_y - 1.0f) + old_rect_size_change.y, 0.0f);
        actor.set_scale (1.0f / scale_x, 1.0f / scale_y);

        actor.save_easing_state ();
        actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
        actor.set_easing_duration (duration);
        actor.set_scale (1.0f, 1.0f);
        actor.set_translation (0.0f, 0.0f, 0.0f);
        actor.restore_easing_state ();

        ulong handler_id = 0UL;
        handler_id = actor.transitions_completed.connect (() => {
            actor.disconnect (handler_id);
            unmaximizing.remove (actor);
        });
    }

    public void minimize (Meta.WindowActor actor) {
        if (!Meta.Prefs.get_gnome_animations () ||
            actor.get_meta_window ().window_type != Meta.WindowType.NORMAL) {
            wm.minimize_completed (actor);
            return;
        }

        wm.kill_window_effects (actor);
        minimizing.add (actor);

        Mtk.Rectangle icon = {};
        if (actor.get_meta_window ().get_icon_geometry (out icon)) {
            // Fix icon position and size according to ui scaling factor.
            var ui_scale = wm.get_display ().get_monitor_scale (wm.get_display ().get_monitor_index_for_rect (icon));
            icon.x = Utils.scale_to_int (icon.x, ui_scale);
            icon.y = Utils.scale_to_int (icon.y, ui_scale);
            icon.width = Utils.scale_to_int (icon.width, ui_scale);
            icon.height = Utils.scale_to_int (icon.height, ui_scale);

            actor.set_pivot_point (
                (actor.x - icon.x) / (icon.width - actor.width),
                (actor.y - icon.y) / (icon.height - actor.height)
            );

            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_EXPO);
            actor.set_easing_duration (AnimationDuration.HIDE);
            actor.set_scale (icon.width / actor.width, icon.height / actor.height);
            actor.opacity = 0;
            actor.restore_easing_state ();

            ulong minimize_handler_id = 0;
            minimize_handler_id = actor.transitions_completed.connect (() => {
                actor.disconnect (minimize_handler_id);
                wm.minimize_completed (actor);
                minimizing.remove (actor);
            });
        } else {
            actor.set_pivot_point (0.5f, 1.0f);

            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_EXPO);
            actor.set_easing_duration (AnimationDuration.HIDE);
            actor.set_scale (0.0, 0.0);
            actor.opacity = 0;
            actor.restore_easing_state ();

            ulong minimize_handler_id = 0;
            minimize_handler_id = actor.transitions_completed.connect (() => {
                actor.disconnect (minimize_handler_id);
                actor.set_pivot_point (0.0f, 0.0f);
                wm.minimize_completed (actor);
                minimizing.remove (actor);
            });
        }
    }

    public void unminimize (Meta.WindowActor actor) {
        if (!Meta.Prefs.get_gnome_animations ()) {
            actor.show ();
            wm.unminimize_completed (actor);
            return;
        }

        var duration = AnimationDuration.HIDE;
        unowned var window = actor.get_meta_window ();

        actor.remove_all_transitions ();
        actor.show ();

        switch (window.window_type) {
            case Meta.WindowType.NORMAL:
                unminimizing.add (actor);

                actor.set_pivot_point (0.5f, 1.0f);
                actor.set_scale (0.01f, 0.1f);
                actor.opacity = 0U;

                actor.save_easing_state ();
                actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_EXPO);
                actor.set_easing_duration (duration);
                actor.set_scale (1.0f, 1.0f);
                actor.opacity = 255U;
                actor.restore_easing_state ();

                ulong unminimize_handler_id = 0UL;
                unminimize_handler_id = actor.transitions_completed.connect (() => {
                    actor.disconnect (unminimize_handler_id);
                    unminimizing.remove (actor);
                    wm.unminimize_completed (actor);
                });

                break;
            default:
                wm.unminimize_completed (actor);
                break;
        }
    }

    public bool kill_minimize (Meta.WindowActor actor) {
        return end_animation (ref minimizing, actor);
    }

    public bool kill_unminimize (Meta.WindowActor actor) {
        return end_animation (ref unminimizing, actor);
    }

    public void kill_effects (Meta.WindowActor actor) {
        end_animation (ref mapping, actor);
        end_animation (ref destroying, actor);
        end_animation (ref maximizing, actor);
        end_animation (ref unmaximizing, actor);
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
