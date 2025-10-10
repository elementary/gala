/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellWindow : PositionedWindow, GestureTarget {
    public bool restore_previous_x11_region { private get; set; default = false; }
    public bool visible_in_multitasking_view { get; set; default = false; }

    private Meta.WindowActor window_actor;
    private double custom_progress = 0;
    private double multitasking_view_progress = 0;

    private int animations_ongoing = 0;

    private PropertyTarget property_target;

    public ShellWindow (Meta.Window window, Position position, Variant? position_data = null) {
        base (window, position, position_data);
    }

    construct {
        window_actor = (Meta.WindowActor) window.get_compositor_private ();

        window_actor.notify["width"].connect (update_clip);
        window_actor.notify["height"].connect (update_clip);
        window_actor.notify["translation-y"].connect (update_clip);
        notify["position"].connect (update_clip);

        window.size_changed.connect (update_target);
        notify["position"].connect (update_target);
        update_target ();
    }

    private void update_target () {
        property_target = new PropertyTarget (
            CUSTOM, window_actor,
            get_animation_property (),
            get_property_type (),
            calculate_value (false),
            calculate_value (true)
        );
    }

    private double get_hidden_progress () {
        if (visible_in_multitasking_view) {
            return double.min (custom_progress, 1 - multitasking_view_progress);
        } else {
            return double.max (custom_progress, multitasking_view_progress);
        }
    }

    private void update_property () {
        property_target.propagate (UPDATE, CUSTOM, get_hidden_progress ());
    }

    public override void propagate (UpdateType update_type, GestureAction action, double progress) {
        switch (update_type) {
            case START:
                animations_ongoing++;
                update_visibility ();
                break;

            case UPDATE:
                on_update (action, progress);
                break;

            case END:
                animations_ongoing--;
                update_visibility ();
                break;

            default:
                break;
        }
    }

    private void on_update (GestureAction action, double progress) {
        switch (action) {
            case MULTITASKING_VIEW:
                multitasking_view_progress = progress;
                break;

            case CUSTOM:
                custom_progress = progress;
                break;

            default:
                break;
        }

        update_property ();
    }

    private void update_visibility () {
        var visible = get_hidden_progress () < 0.1;
        var animating = animations_ongoing > 0;

        window_actor.visible = animating || visible;

        if (window_actor.visible) {
#if HAS_MUTTER48
            window.display.get_compositor ().disable_unredirect ();
#else
            window.display.disable_unredirect ();
#endif
        } else {
#if HAS_MUTTER48
            window.display.get_compositor ().enable_unredirect ();
#else
            window.display.enable_unredirect ();
#endif
        }

        if (!Meta.Util.is_wayland_compositor ()) {
            if (window_actor.visible) {
                Utils.x11_unset_window_pass_through (window, restore_previous_x11_region);
            } else {
                Utils.x11_set_window_pass_through (window);
            }
        }

        unowned var manager = ShellClientsManager.get_instance ();
        window.foreach_transient ((transient) => {
            if (manager.is_itself_positioned (transient)) {
                return true;
            }

            unowned var window_actor = (Meta.WindowActor) transient.get_compositor_private ();

            window_actor.visible = visible && !animating;

            return true;
        });
    }

    private string get_animation_property () {
        switch (position) {
            case TOP:
            case BOTTOM:
                return "translation-y";
            default:
                return "opacity";
        }
    }

    private Type get_property_type () {
        switch (position) {
            case TOP:
            case BOTTOM:
                return typeof (float);
            default:
                return typeof (uint);
        }
    }

    private Value calculate_value (bool hidden) {
        var custom_rect = get_custom_window_rect ();

        switch (position) {
            case TOP:
                return hidden ? -custom_rect.height : 0f;
            case BOTTOM:
                return hidden ? custom_rect.height : 0f;
            default:
                return hidden ? 0u : 255u;
        }
    }

    private void update_clip () {
        if (position != TOP && position != BOTTOM) {
            window_actor.remove_clip ();
            return;
        }

        var monitor_geom = window.display.get_monitor_geometry (window.get_monitor ());

        var y = window_actor.y + window_actor.translation_y;

        if (y + window_actor.height > monitor_geom.y + monitor_geom.height) {
            window_actor.set_clip (0, 0, window_actor.width, monitor_geom.y + monitor_geom.height - y);
        } else if (y < monitor_geom.y) {
            window_actor.set_clip (0, monitor_geom.y - y, window_actor.width, window_actor.height);
        } else {
            window_actor.remove_clip ();
        }
    }
}
