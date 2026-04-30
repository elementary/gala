/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Key : Object {
    public const string ACTION_GROUP_PREFIX = "keyboard";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    /* Types the keyval given as the action target */
    public const string ACTION_TYPE_KEY_VAL = "keyval";
    /* Erases the last character */
    public const string ACTION_ERASE = "erase";
    /* Latches the keyboard view with the name given as the action target */
    public const string ACTION_LATCH_VIEW = "latch-view";
    /* Sets the keyboard view with the name given as the action target */
    public const string ACTION_SET_VIEW = "set-view";

    public double left_offset { get; construct; default = 0.0; }
    public double width { get; construct; default = 1.0; }
    public double height { get; construct; default = 1.0; }

    public string detailed_action_name { get; construct; }

    public ListModel popup_keys { get; construct; }

    public string? label { get; construct; }
    public Icon? icon { get; construct; }

    public Key (double left_offset, double width, double height, string detailed_action_name, ListModel popup_keys, string? label, Icon? icon) {
        Object (
            left_offset: left_offset,
            width: width,
            height: height,
            detailed_action_name: detailed_action_name,
            popup_keys: popup_keys,
            label: label,
            icon: icon
        );
    }
}
