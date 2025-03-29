/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "org.freedesktop.login1.Manager")]
public interface Gala.LoginManager : Object {
    public signal void prepare_for_sleep (bool about_to_suspend);
    public signal void prepare_for_shutdown (bool about_to_shutdown);

    public abstract GLib.ObjectPath get_session (string session_id) throws GLib.Error;
    public abstract UnixInputStream inhibit (string what, string who, string why, string mode) throws GLib.Error;
}
