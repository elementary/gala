/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2014 Tom Beckmann
 */

namespace Gala {
    public enum ActionType {
        NONE = 0,
        SHOW_MULTITASKING_VIEW,
        MAXIMIZE_CURRENT,
        HIDE_CURRENT,
        OPEN_LAUNCHER,
        CUSTOM_COMMAND,
        WINDOW_OVERVIEW,
        WINDOW_OVERVIEW_ALL,
        SWITCH_TO_WORKSPACE_PREVIOUS,
        SWITCH_TO_WORKSPACE_NEXT,
        SWITCH_TO_WORKSPACE_LAST,
        START_MOVE_CURRENT,
        START_RESIZE_CURRENT,
        TOGGLE_ALWAYS_ON_TOP_CURRENT,
        TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT,
        MOVE_CURRENT_WORKSPACE_LEFT,
        MOVE_CURRENT_WORKSPACE_RIGHT,
        CLOSE_CURRENT,
        SCREENSHOT_CURRENT
    }
}
