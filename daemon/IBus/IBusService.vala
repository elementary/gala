/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.IBusService : Object {
    private ListStore _candidates;
    public ListModel candidates { get { return _candidates; } }

    public bool disable_popup { get; set; default = false; }
    public IBus.PanelService service { get; private set; }

    private IBus.Bus bus;
    private IBusCandidateWindow candidate_window;

    construct {
        _candidates = new ListStore (typeof (Candidate));

        bus = new IBus.Bus.async ();
        bus.connected.connect (on_connected);
    }

    private void on_connected () {
        bus.request_name_async.begin (
            IBus.SERVICE_PANEL, IBus.BusNameFlag.REPLACE_EXISTING, -1, null,
            on_name_acquired
        );
    }

    private void on_name_acquired (Object? obj, AsyncResult res) {
        try {
            bus.request_name_async_finish (res);
        } catch (Error e) {
            warning ("Failed to acquire bus name: %s", e.message);
            return;
        }

        /* We need to go via Object.new because we need to pass construct properties */
        service = (IBus.PanelService) Object.@new (typeof (IBus.PanelService), "connection", bus.get_connection (), "object-path", IBus.PATH_PANEL);
        candidate_window = new IBusCandidateWindow (service);
        bind_property ("disable-popup", candidate_window, "disabled", SYNC_CREATE);

        service.update_lookup_table.connect (on_update_lookup_table);
    }

    private void on_update_lookup_table (IBus.LookupTable table) {
        _candidates.remove_all ();

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
            var label = table.get_label (i)?.text;
            var candidate = table.get_candidate (i)?.text;

            _candidates.append (new Candidate (label, candidate));
        }
    }
}
