/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.IBusCandidateWindow : Gtk.Window {
    public IBus.PanelService service { get; construct; }

    public bool disabled { get; set; default = false; }

    private Gtk.Label preedit_text;
    private Gtk.Label auxiliary_text;
    private CandidateArea candidate_area;

    public IBusCandidateWindow (IBus.PanelService service) {
        Object (service: service);
    }

    construct {
        preedit_text = new Gtk.Label (null) {
            halign = START,
            visible = false,
        };

        auxiliary_text = new Gtk.Label (null) {
            halign = START,
            visible = false,
        };

        candidate_area = new CandidateArea (service) {
            hexpand = true,
            visible = false,
        };

        var content_box = new Granite.Box (VERTICAL) {
            margin_start = 6,
            margin_end = 6,
            margin_top = 6,
            margin_bottom = 6,
        };
        content_box.append (preedit_text);
        content_box.append (auxiliary_text);
        content_box.append (candidate_area);

        titlebar = new Gtk.Grid () { visible = false };
        child = content_box;
        /* Used to identify the window for correct positioning in the wm */
        title = "IBUS_CANDIDATE";
        resizable = false;

        service.show_preedit_text.connect (on_show_preedit_text);
        service.hide_preedit_text.connect (on_hide_preedit_text);
        service.update_preedit_text.connect (on_update_preedit_text);
        service.show_auxiliary_text.connect (on_show_auxiliary_text);
        service.hide_auxiliary_text.connect (on_hide_auxiliary_text);
        service.update_auxiliary_text.connect (on_update_auxiliary_text);
        service.show_lookup_table.connect (on_show_lookup_table);
        service.hide_lookup_table.connect (on_hide_lookup_table);
        service.update_lookup_table.connect (on_update_lookup_table);
        service.focus_out.connect (hide);
    }

    private void update_visibility () {
        var is_visible = !disabled && (preedit_text.visible || auxiliary_text.visible || candidate_area.visible);

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

    private void on_show_lookup_table () {
        candidate_area.visible = true;
        update_visibility ();
    }

    private void on_hide_lookup_table () {
        candidate_area.visible = false;
        update_visibility ();
    }

    private void on_update_lookup_table (IBus.LookupTable table, bool visible) {
        candidate_area.visible = visible;
        update_visibility ();

        candidate_area.update (table);
    }
}
