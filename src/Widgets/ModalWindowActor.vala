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
public class Gala.ModalWindowActor : Clutter.Actor {
    public Meta.Display display { get; construct; }

    private int modal_dialogs = 0;

    public ModalWindowActor (Meta.Display display) {
        Object (display: display);
    }

    construct {
        background_color = { 0, 0, 0, 200 };
        x = 0;
        y = 0;
        width = 10000;
        height = 10000;
        visible = false;
        reactive = true;
    }

    public void make_modal (Meta.Window window) {
        modal_dialogs++;
        window.unmanaged.connect (unmake_modal);

        var actor = (Meta.WindowActor) window.get_compositor_private ();
        InternalUtils.clutter_actor_reparent (actor, this);

        check_visible ();
    }

    public void unmake_modal (Meta.Window window) {
        modal_dialogs--;
        window.unmanaged.disconnect (unmake_modal);

        check_visible ();
    }

    private void check_visible () {
        visible = modal_dialogs > 0;
    }

    public bool is_modal () {
        return modal_dialogs > 0;
    }
}
