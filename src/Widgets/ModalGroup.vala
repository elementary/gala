/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
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
    public bool dimmed = false;

    private int modal_dialogs = 0;

    construct {
        background_color = { 0, 0, 0, 200 };
        x = 0;
        y = 0;
        visible = false;
        reactive = true;

        child_added.connect (on_child_added);
        child_removed.connect (on_child_removed);
    }

    private void on_child_added (Clutter.Actor child) {
        modal_dialogs++;

        if (modal_dialogs == 1) {
            visible = true;

            if (dimmed) {
                save_easing_state ();
                background_color = { 0, 0, 0, 200 };
                restore_easing_state ();
            }
        }
    }

    private void on_child_removed (Clutter.Actor child) {
        modal_dialogs--;

        if (modal_dialogs == 0) {
            save_easing_state ();
            background_color = { 0, 0, 0, 0 };
            restore_easing_state ();

            var transition = get_transition ("background-color");
            if (transition != null) {
                transition.completed.connect (() => visible = false);
            } else {
                visible = false;
            }
        }
    }

    public bool is_modal () {
        return modal_dialogs > 0;
    }
}
