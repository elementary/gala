/*
 * Copyright 2021-2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Gala.NamedColor : Object {
    public string name { get; construct set; }
    public string theme { get; construct set; }
    public Drawing.Color color { get; construct set; }

    public NamedColor (string name, string theme, Drawing.Color color) {
        Object (
            name: name,
            theme: theme,
            color: color
        );
    }
}
