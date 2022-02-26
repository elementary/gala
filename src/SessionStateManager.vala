/*
 * Copyright 2022 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Gala.SessionStateManager : Object {
    [DBus (name = "org.gnome.SessionManager")]
    private interface SessionManagerInterface : Object {
        public abstract signal void session_running ();
    }

    private SessionManagerInterface session_manager;

    public signal void session_running ();

    async construct {
        init.begin ();
    }

    private async void init () {
        try {
            session_manager = yield Bus.get_proxy (BusType.SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager");

            session_manager.session_running.connect (() => {
                session_running ();
            });
        } catch (Error e) {
            warning ("Could not connect to system bus: %s", e.message);
        }
    }
}
