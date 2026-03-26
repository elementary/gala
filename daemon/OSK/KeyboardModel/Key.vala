/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Key : Object {
    public const string ACTION_GROUP_PREFIX = "keyboard";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    /* Types the keyval given as the action target in a single combination of pressed + released */
    public const string ACTION_TYPE_KEY_VAL = "keyval";
    /* Sends a keyval pressed event */
    public const string ACTION_PRESS_KEY_VAL = "keyval-press";
    /* Sends a keyval released event */
    public const string ACTION_RELEASE_KEY_VAL = "keyval-release";
    /* Latches the keyboard view with the name given as the action target */
    public const string ACTION_LATCH_VIEW = "latch-view";
    /* Sets the keyboard view with the name given as the action target */
    public const string ACTION_SET_VIEW = "set-view";
    /* Hides the keyboard */
    public const string ACTION_HIDE = "hide";

    public double left_offset { get; construct; default = 0.0; }
    public double width { get; construct; default = 1.0; }
    public double height { get; construct; default = 1.0; }

    /**
     * Action triggered on release.
     */
    public string detailed_action_name { get; construct; }

    /**
     * Additional optional action triggered on press.
     */
    public string? press_detailed_action_name { get; construct; }

    public ListModel popup_keys { get; construct; }

    public string? label { get; construct; }
    public Icon? icon { get; construct; }

    public Key (double left_offset, double width, double height, string detailed_action_name, string? press_detailed_action_name, ListModel popup_keys, string? label, Icon? icon) {
        Object (
            left_offset: left_offset,
            width: width,
            height: height,
            detailed_action_name: detailed_action_name,
            press_detailed_action_name: press_detailed_action_name,
            popup_keys: popup_keys,
            label: label,
            icon: icon
        );
    }
}
