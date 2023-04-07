/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WorkspaceInsertThumb : Clutter.Actor {
    public const int EXPAND_DELAY = 300;

    public int workspace_index { get; construct set; }
    public bool expanded { get; set; default = false; }
    public int delay { get; set; default = EXPAND_DELAY; }
    public float scale_factor { get; construct set; }

    private uint expand_timeout = 0;

    public WorkspaceInsertThumb (int workspace_index, float scale) {
        Object (workspace_index: workspace_index, scale_factor: scale);

        width = InternalUtils.scale_to_int (IconGroupContainer.SPACING, scale);
        height = InternalUtils.scale_to_int (IconGroupContainer.GROUP_WIDTH, scale);
        y = InternalUtils.scale_to_int (IconGroupContainer.GROUP_WIDTH - IconGroupContainer.SPACING, scale) / 2;
        opacity = 0;
        set_pivot_point (0.5f, 0.5f);
        reactive = true;
        x_align = Clutter.ActorAlign.CENTER;

        var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
        drop.crossed.connect ((target, hovered) => {
            if (!Meta.Prefs.get_dynamic_workspaces () && (target != null && target is WindowClone)) {
                return;
            }

            if (!hovered) {
                if (expand_timeout != 0) {
                    Source.remove (expand_timeout);
                    expand_timeout = 0;
                }

                transform (false);
            } else {
                expand_timeout = Timeout.add (delay, expand);
            }
        });

        add_action (drop);
    }

    public void set_window_thumb (Meta.Window window) {
        destroy_all_children ();

        var icon = new WindowIcon (window, IconGroupContainer.GROUP_WIDTH, (int)Math.round (scale_factor)) {
            x = IconGroupContainer.SPACING,
            x_align = Clutter.ActorAlign.CENTER
        };
        add_child (icon);
    }

    private bool expand () {
        expand_timeout = 0;

        transform (true);

        return Source.REMOVE;
    }

    private new void transform (bool expand) {
        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        set_easing_duration (200);

        if (!expand) {
            remove_transition ("pulse");
            opacity = 0;
            width = InternalUtils.scale_to_int (IconGroupContainer.SPACING, scale_factor);
            expanded = false;
        } else {
            add_pulse_animation ();
            opacity = 200;
            width = InternalUtils.scale_to_int (IconGroupContainer.GROUP_WIDTH + IconGroupContainer.SPACING * 2, scale_factor);
            expanded = true;
        }

        restore_easing_state ();
    }

    private void add_pulse_animation () {
        var transition = new Clutter.TransitionGroup () {
            duration = 800,
            auto_reverse = true,
            repeat_count = -1,
            progress_mode = Clutter.AnimationMode.LINEAR
        };

        var scale_x_transition = new Clutter.PropertyTransition ("scale-x");
        scale_x_transition.set_from_value (0.8);
        scale_x_transition.set_to_value (1.1);
        scale_x_transition.auto_reverse = true;

        var scale_y_transition = new Clutter.PropertyTransition ("scale-y");
        scale_y_transition.set_from_value (0.8);
        scale_y_transition.set_to_value (1.1);
        scale_y_transition.auto_reverse = true;

        transition.add_transition (scale_x_transition);
        transition.add_transition (scale_y_transition);

        add_transition ("pulse", transition);
    }
}
