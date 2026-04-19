/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Suggestions : Granite.Bin {
    public IBusService ibus_service { private get; construct; }

    public Suggestions (IBusService ibus_service) {
        Object (ibus_service: ibus_service);
    }

    construct {
        var selection_model = new Gtk.NoSelection (ibus_service.candidates);

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect (on_setup);
        factory.bind.connect (on_bind);

        var list_view = new Gtk.ListView (selection_model, factory) {
            orientation = HORIZONTAL,
        };
        child = list_view;
        halign = CENTER;
    }

    private void on_setup (Object obj) {
        var item = (Gtk.ListItem) obj;
        item.child = new CandidateBox (ibus_service.service, item);
    }

    private void on_bind (Object obj) {
        var item = (Gtk.ListItem) obj;
        var candidate = (Candidate) item.item;

        var box = (CandidateBox) item.child;
        box.set_candidate (candidate);
    }
}
