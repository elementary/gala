/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2014 Tom Beckmann
 *
 * Note: These enums are shared with the daemon
 */

namespace Gala {
    public enum WindowMenuItemType {
        BUTTON,
        TOGGLE,
        SEPARATOR
    }

    public struct DaemonWindowMenuItem {
        WindowMenuItemType type;
        bool sensitive;
        bool toggle_state;
        string display_name;
        string keybinding;
    }

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

    [Flags]
    public enum WindowFlags {
        NONE = 0,
        CAN_HIDE,
        CAN_MAXIMIZE,
        IS_MAXIMIZED,
        ALLOWS_MOVE,
        ALLOWS_RESIZE,
        ALWAYS_ON_TOP,
        ON_ALL_WORKSPACES,
        CAN_CLOSE,
        IS_TILED,
        ALLOWS_MOVE_LEFT,
        ALLOWS_MOVE_RIGHT
    }
}
