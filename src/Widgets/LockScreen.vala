/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.LockScreen : Clutter.Actor {
    private const WindowGroup[] ALLOWED_WINDOW_GROUPS = { LOCK_SCREEN, LOCK_SCREEN_SHELL, OVERLAY };

    public WindowManager wm { get; construct; }

    public Clutter.Actor window_group { get; private set; }
    public Clutter.Actor shell_group { get; private set; }

    private bool active;
    private ModalProxy? modal_proxy;

    public LockScreen (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        var background = new BackgroundContainer (wm.get_display ());
        background.add_effect (new BlurEffect (background, 18));

        window_group = new Clutter.Actor ();
        shell_group = new Clutter.Actor ();

        add_child (background);
        add_child (window_group);
        add_child (shell_group);

        reactive = true;
        visible = true;

        active = true;
        update_modal ();
    }

    public async void set_active (bool active) {
        if (this.active == active) {
            return;
        }

        this.active = active;
        update_modal ();

        /* We can and should add a transition here */

        visible = active;
    }

    private void update_modal () {
        if (active) {
            assert (modal_proxy == null);

            modal_proxy = wm.push_modal (this, false);
            modal_proxy.allow_actions (MEDIA_KEYS | ZOOM | LOCATE_POINTER);
            modal_proxy.allow_window_groups (ALLOWED_WINDOW_GROUPS);
        } else {
            assert (modal_proxy != null);

            wm.pop_modal (modal_proxy);
            modal_proxy = null;
        }
    }
}
