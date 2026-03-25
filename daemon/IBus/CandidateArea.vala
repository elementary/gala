/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.CandidateArea : Granite.Bin {
    private const string[] DEFAULT_LABELS = {
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "a", "b", "c", "d", "e", "f"
    };

    public IBus.PanelService service { get; construct; }

    private ListStore model;
    private Gtk.SingleSelection selection_model;
    private Gtk.ListView list_view;

    private Gtk.Button prev_page_button;
    private Gtk.Button next_page_button;
    private Granite.Box button_box;

    private Granite.Box content_box;

    public CandidateArea (IBus.PanelService service) {
        Object (service: service);
    }

    construct {
        model = new ListStore (typeof (Candidate));

        selection_model = new Gtk.SingleSelection (model);

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect (on_setup);
        factory.bind.connect (on_bind);

        list_view = new Gtk.ListView (selection_model, factory);

        prev_page_button = new Gtk.Button ();
        prev_page_button.clicked.connect (service.page_up);

        next_page_button = new Gtk.Button ();
        next_page_button.clicked.connect (service.page_down);

        button_box = new Granite.Box (HORIZONTAL, LINKED) {
            hexpand = true
        };
        button_box.append (prev_page_button);
        button_box.append (next_page_button);

        content_box = new Granite.Box (VERTICAL);
        content_box.append (list_view);
        content_box.append (button_box);

        child = content_box;
    }

    private void on_setup (Object obj) {
        var item = (Gtk.ListItem) obj;
        item.child = new CandidateBox (service, item);
    }

    private void on_bind (Object obj) {
        var item = (Gtk.ListItem) obj;
        var candidate = (Candidate) item.item;

        var box = (CandidateBox) item.child;
        box.set_candidate (candidate);
    }

    public void update (IBus.LookupTable table) {
        model.remove_all ();

        if (table.get_orientation () == IBus.Orientation.HORIZONTAL) {
            update_orientation (HORIZONTAL);
        } else { /* VERTICAL or SYSTEM */
            update_orientation (VERTICAL);
        }

        var n_candidates = table.get_number_of_candidates ();
        var page_size = table.get_page_size ();

        if (page_size == 0) {
            /* I don't think 0 is intended to happen so print a warning */
            warning ("LookupTable page size is 0, using 5");
            page_size = 5;
        }

        var cursor_pos = table.get_cursor_pos ();
        var page = (uint) (cursor_pos / page_size);

        var start_index = page * page_size;
        var end_index = uint.min (start_index + page_size, n_candidates);

        for (uint i = start_index; i < end_index; i++) {
            var ibus_label = table.get_label (i)?.text;
            var label = ibus_label != null && ibus_label.strip () != "" ? ibus_label : (
                i - start_index < DEFAULT_LABELS.length ? DEFAULT_LABELS[i - start_index] : null
            );

            var candidate = table.get_candidate (i)?.text;

            model.append (new Candidate (label, candidate));
        }

        selection_model.selected = table.get_cursor_in_page ();

        update_buttons (table.is_round (), page, (uint) ((n_candidates + page_size - 1) / page_size));
    }

    private void update_orientation (Gtk.Orientation orientation) {
        content_box.orientation = orientation;
        list_view.orientation = orientation;

        if (orientation == HORIZONTAL) {
            prev_page_button.icon_name = "go-previous";
            next_page_button.icon_name = "go-next";
        } else {
            prev_page_button.icon_name = "go-up";
            next_page_button.icon_name = "go-down";
        }
    }

    private void update_buttons (bool wraps_around, uint page, uint n_pages) {
        button_box.visible = n_pages > 1;

        prev_page_button.sensitive = wraps_around || page > 0;
        next_page_button.sensitive = wraps_around || page < n_pages - 1;
    }
}
