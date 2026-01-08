/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * This class allows to make windows system modal i.e. dim
 * the desktop behind them and only allow interaction with them.
 * Not to be confused with WindowManager.push_modal which only
 * works for our own Clutter.Actors.
 * Note that windows shouldn't be added to this actor directly but
 * instead to {@link window_group}.
 */
public class Gala.ModalGroup : Clutter.Actor {
    public WindowManager wm { private get; construct; }
    public ShellClientsManager shell_clients { private get; construct; }

    public Clutter.Actor window_group { get; construct; }

    private Clutter.Actor background;
    private Gee.Set<Clutter.Actor> dimmed;
    private ModalProxy? modal_proxy = null;

    public ModalGroup (WindowManager wm, ShellClientsManager shell_clients) {
        Object (wm: wm, shell_clients: shell_clients);
    }

    class construct {
        set_layout_manager_type (typeof (Clutter.BinLayout));
    }

    construct {
        background = new Clutter.Actor () {
            background_color = { 0, 0, 0, 125 },
            x_expand = true,
            y_expand = true,
        };
        background.add_effect (new BackgroundBlurEffect (10, 0, 1));

        window_group = new Clutter.Actor () {
            x_expand = true,
            y_expand = true,
        };

        add_child (background);
        add_child (window_group);

        dimmed = new Gee.HashSet<Clutter.Actor> ();

        visible = false;
        reactive = true;
#if HAS_MUTTER46
        window_group.child_added.connect (on_child_added);
        window_group.child_removed.connect (on_child_removed);
#else
        window_group.actor_added.connect (on_child_added);
        window_group.actor_removed.connect (on_child_removed);
#endif
    }

    private void on_child_added (Clutter.Actor child) {
        if (child is Meta.WindowActor && shell_clients.is_system_modal_dimmed (child.meta_window)) {
            dimmed.add (child);
        }

        if (window_group.get_n_children () == 1) {
            assert (modal_proxy == null);

            visible = true;
            modal_proxy = wm.push_modal (this, false);
        }

        if (dimmed.size == 1) {
            background.save_easing_state ();
            background.set_easing_duration (Utils.get_animation_duration (AnimationDuration.OPEN));
            background.opacity = 255u;
            background.restore_easing_state ();
        }
    }

    private void on_child_removed (Clutter.Actor child) {
        dimmed.remove (child);

        if (dimmed.size == 0) {
            background.save_easing_state ();
            background.set_easing_duration (Utils.get_animation_duration (AnimationDuration.CLOSE));
            background.opacity = 0u;
            background.restore_easing_state ();
        }

        if (window_group.get_n_children () == 0) {
            wm.pop_modal (modal_proxy);
            modal_proxy = null;

            var transition = background.get_transition ("opacity");
            if (transition != null) {
                transition.completed.connect (() => visible = false);
            } else {
                visible = false;
            }
        }
    }
}
