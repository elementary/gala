/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.KeyboardModel : Object {
    public ListModel views { get; construct; }

    public KeyboardModel (ListModel views) {
        Object (views: views);
    }

    public KeyboardView? get_view_by_name (string name) {
        for (uint i = 0; i < views.get_n_items (); i++) {
            var view = (KeyboardView) views.get_item (i);
            if (view.name == name) {
                return view;
            }
        }

        return null;
    }

    public KeyboardView? find_default_view () {
        for (uint i = 0; i < views.get_n_items (); i++) {
            var view = (KeyboardView) views.get_item (i);
            if (view.is_default) {
                return view;
            }
        }

        return (KeyboardView?) views.get_item (0);
    }
}
