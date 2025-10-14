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
 */
public class Gala.ModalGroup : Clutter.Actor {
    public WindowManager wm { private get; construct; }
    public ShellClientsManager shell_clients { private get; construct; }

    private Gee.Set<Clutter.Actor> dimmed;
    private ModalProxy? modal_proxy = null;

    public ModalGroup (WindowManager wm, ShellClientsManager shell_clients) {
        Object (wm: wm, shell_clients: shell_clients);
    }

    construct {
        dimmed = new Gee.HashSet<Clutter.Actor> ();

        visible = false;
        reactive = true;
#if HAS_MUTTER46
        child_added.connect (on_child_added);
        child_removed.connect (on_child_removed);
#else
        actor_added.connect (on_child_added);
        actor_removed.connect (on_child_removed);
#endif
    }

    private void on_child_added (Clutter.Actor child) {
        if (child is Meta.WindowActor && shell_clients.is_system_modal_dimmed (child.meta_window)) {
            dimmed.add (child);
        }

        if (get_n_children () == 1) {
            assert (modal_proxy == null);

            visible = true;
            modal_proxy = wm.push_modal (this, false);
        }

        if (dimmed.size == 1) {
            save_easing_state ();
            set_easing_duration (Utils.get_animation_duration (AnimationDuration.OPEN));
            background_color = { 0, 0, 0, 200 };
            restore_easing_state ();
        }
    }

    private void on_child_removed (Clutter.Actor child) {
        dimmed.remove (child);

        if (dimmed.size == 0) {
            save_easing_state ();
            set_easing_duration (Utils.get_animation_duration (AnimationDuration.CLOSE));
            background_color = { 0, 0, 0, 0 };
            restore_easing_state ();
        }

        if (get_n_children () == 0) {
            wm.pop_modal (modal_proxy);
            modal_proxy = null;

            var transition = get_transition ("background-color");
            if (transition != null) {
                transition.completed.connect (() => visible = false);
            } else {
                visible = false;
            }
        }
    }
}
