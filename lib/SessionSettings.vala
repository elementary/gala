/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

namespace Gala.SessionSettings {
    private enum SessionType {
        DESKTOP,
        GREETER,
        INSTALLER;
    }

    private static SessionType? session_type = null;

    private static SessionType get_session_type () {
        if (session_type == null) {
            var session_type_str = Environment.get_variable ("GALA_SESSION_TYPE") ?? "desktop";
            switch (session_type_str) {
                case "desktop":
                    session_type = DESKTOP;
                    break;
                case "greeter":
                    session_type = GREETER;
                    break;
                case "installer":
                    session_type = INSTALLER;
                    break;
                default:
                    warning ("Unknown session type: %s", session_type_str);
                    session_type = DESKTOP;
                    break;
            }
        }

        return session_type;
    }

    public string get_shell_clients_type () {
        switch (get_session_type ()) {
            case DESKTOP:
                return "desktop";
            case GREETER:
                return "greeter";
            case INSTALLER:
                return "installer";
        }

        return "desktop";
    }
}
