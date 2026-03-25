/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.CandidateBox : Granite.Bin {
    public IBus.PanelService service { get; construct; }
    public unowned Gtk.ListItem list_item { get; construct; }

    private Gtk.Label label_label;
    private Gtk.Label candidate_label;

    public CandidateBox (IBus.PanelService service, Gtk.ListItem list_item) {
        Object (service: service, list_item: list_item);
    }

    construct {
        label_label = new Gtk.Label (null);
        label_label.add_css_class (Granite.CssClass.DIM);

        candidate_label = new Gtk.Label (null);

        var content_box = new Granite.Box (HORIZONTAL, HALF);
        content_box.append (label_label);
        content_box.append (candidate_label);

        child = content_box;

        var gesture_click = new Gtk.GestureClick ();
        gesture_click.released.connect (on_clicked);
        add_controller (gesture_click);
    }

    private void on_clicked (Gtk.GestureClick gesture, int n_press, double x, double y) {
        service.candidate_clicked (list_item.position, gesture.get_current_button (), gesture.get_current_event_state ());
    }

    public void bind_candidate (Candidate candidate) {
        label_label.label = candidate.label;
        candidate_label.label = candidate.candidate;
    }
}
