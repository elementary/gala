/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellClientsManager : Object {
    public Meta.Display display { get; construct; }

    private NotificationsClient notifications_client;

    public ShellClientsManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        notifications_client = new NotificationsClient (display);
    }
}
