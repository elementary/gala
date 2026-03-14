/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.IBusCandidateWindow : Gtk.Window {
    public IBus.PanelService service { get; construct; }

    private Gtk.Label preedit_text;
    private Gtk.Label auxiliary_text;

    public IBusCandidateWindow (IBus.PanelService service) {
        Object (service: service);
    }

    construct {
        preedit_text = new Gtk.Label (null) {
            visible = false,
        };

        auxiliary_text = new Gtk.Label (null) {
            visible = false,
        };

        var content_box = new Granite.Box (VERTICAL);
        content_box.append (preedit_text);
        content_box.append (auxiliary_text);

        default_width = 200;
        default_height = 200;

        child = content_box;
        title = "IBUS_CANDIDATE";

        service.show_preedit_text.connect (on_show_preedit_text);
        service.hide_preedit_text.connect (on_hide_preedit_text);
        service.update_preedit_text.connect (on_update_preedit_text);
        service.show_auxiliary_text.connect (on_show_auxiliary_text);
        service.hide_auxiliary_text.connect (on_hide_auxiliary_text);
        service.update_auxiliary_text.connect (on_update_auxiliary_text);
        service.set_cursor_location.connect ((x, y, width, height) => {
            warning ("Set location: %d, %d, %d, %d", x, y, width, height);
        });
        service.set_cursor_location_relative.connect ((x, y, width, height) => {
            warning ("Set location: %d, %d, %d, %d", x, y, width, height);
        });
    }

    private void update_visibility () {
        var is_visible = preedit_text.visible || auxiliary_text.visible;

        if (is_visible) {
            present ();
        } else {
            hide ();
        }
    }

    private void on_show_preedit_text () {
        preedit_text.visible = true;
        update_visibility ();
    }

    private void on_hide_preedit_text () {
        preedit_text.visible = false;
        update_visibility ();
    }

    private void on_update_preedit_text (IBus.Text text, uint cursor_pos, bool visible) {
        preedit_text.visible = visible;
        preedit_text.label = text.text;

        update_visibility ();
    }

    private void on_show_auxiliary_text () {
        auxiliary_text.visible = true;
        update_visibility ();
    }

    private void on_hide_auxiliary_text () {
        auxiliary_text.visible = false;
        update_visibility ();
    }

    private void on_update_auxiliary_text (IBus.Text text, bool visible) {
        auxiliary_text.visible = visible;
        auxiliary_text.label = text.text;

        update_visibility ();
    }
}
