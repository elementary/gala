/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.ScreenShield : Clutter.Actor {
    public signal void user_action ();

    public delegate void OnAnimationEnd ();
    public WindowManager wm { private get; construct; }
    public bool active { get; private set; default = false; }

    private ModalProxy? modal_proxy;

    public ScreenShield (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        reactive = true;
        visible = false;
        opacity = 0;

#if HAS_MUTTER47
        background_color = Cogl.Color.from_string ("black");
#else
        background_color = Clutter.Color.from_string ("black");
#endif
    }

    public override void parent_set (Clutter.Actor? old_parent) {
        clear_constraints ();

        unowned var parent = get_parent ();
        if (parent == null) {
            return;
        }

        add_constraint (new Clutter.BindConstraint (parent, Clutter.BindCoordinate.SIZE, 0.0f));
    }

    public override bool event (Clutter.Event event) {
        switch (event.get_type ()) {
            case BUTTON_PRESS:
            case KEY_PRESS:
            case MOTION:
                user_action ();
                return Clutter.EVENT_STOP;
            default:
                return Clutter.EVENT_PROPAGATE;
        }
    }

    public void activate (uint animation_time, OnAnimationEnd callback) {
        if (visible) {
            unowned var transition = get_transition ("opacity");
            if (transition != null) {
                transition.completed.connect (() => callback ());
            } else {
                callback ();
            }

            return;
        }

        visible = true;
        grab_key_focus ();
        wm.get_display ().get_cursor_tracker ().set_pointer_visible (false);
        modal_proxy = wm.push_modal (this);

        if (animation_time > 0 && Meta.Prefs.get_gnome_animations ()) {
            save_easing_state ();
            set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            set_easing_duration (animation_time);
            opacity = 255;
            restore_easing_state ();

            get_transition ("opacity").completed.connect (() => {
                active = true;
                callback ();
            });
        } else {
            active = true;
            opacity = 255;

            callback ();
        }
    }

    public void deactivate () {
        if (!active) {
            return;
        }

        unowned var transition = get_transition ("opacity");
        if (transition != null) {
            transition.stop ();
            remove_transition ("opacity");
        }

        active = false;

        visible = false;
        opacity = 0;
        wm.get_display ().get_cursor_tracker ().set_pointer_visible (true);

        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
            modal_proxy = null;
        }
    }
}
