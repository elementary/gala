/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public abstract class Gala.ShellWindow : PositionedWindow, GestureTarget {
    public bool restore_previous_x11_region { private get; set; default = false; }

    /**
     * A gesture target that will receive a CUSTOM update every time a gesture
     * is propagated, with the progress gotten via {@link get_hidden_progress()}
     */
    private GestureTarget? _hide_target = null;
    public GestureTarget? hide_target {
        private get { return _hide_target; }
        construct set {
            _hide_target = value;
            _hide_target?.propagate (UPDATE, CUSTOM, get_hidden_progress ());
        }
    }

    private double multitasking_view_progress = 0;
    private int animations_ongoing = 0;

    public virtual void propagate (UpdateType update_type, GestureAction action, double progress) {
        switch (update_type) {
            case START:
                animations_ongoing++;
                update_visibility ();
                break;

            case UPDATE:
                if (action == MULTITASKING_VIEW) {
                    multitasking_view_progress = progress;
                }

                hide_target?.propagate (UPDATE, CUSTOM, get_hidden_progress ());
                break;

            case END:
                animations_ongoing--;
                update_visibility ();
                break;

            default:
                break;
        }
    }

    protected virtual double get_hidden_progress () {
        return multitasking_view_progress;
    }

    private void update_visibility () {
        unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();

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

            unowned var transient_window_actor = (Meta.WindowActor) transient.get_compositor_private ();

            transient_window_actor.visible = visible && !animating;

            return true;
        });
    }
}
