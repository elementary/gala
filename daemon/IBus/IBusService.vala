/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.IBusService : Object {
    private IBus.Bus bus;
    private IBus.PanelService service;
    private IBusCandidateWindow candidate_window;

    construct {
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

        /* We need to go over Object.new because we need to pass construct properties */
        service = (IBus.PanelService) Object.@new (typeof (IBus.PanelService), "connection", bus.get_connection (), "object-path", IBus.PATH_PANEL);
        service.focus_in.connect (() => warning ("Focus in"));
        service.update_lookup_table.connect (() => warning ("Update lookup table"));
        candidate_window = new IBusCandidateWindow (service);
    }
}
