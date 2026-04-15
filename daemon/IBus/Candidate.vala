/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Candidate : Object {
    public string? label { get; construct; }
    public string? candidate { get; construct; }

    public Candidate (string? label, string? candidate) {
        Object (label: label, candidate: candidate);
    }
}
