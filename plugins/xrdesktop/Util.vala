/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
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
*/

namespace Gala.Plugins.XRDesktop.Util {

    void ensure_meta_window_is_focused (Meta.Window window) {
        /* mutter asserts that we don't mess with override_redirect windows */
        if (window.is_override_redirect ()) {
            return;
        }
        window.raise ();
        if (!window.has_focus ()) {
            window.focus (window.get_display ().get_current_time ());
        }
    }

    void ensure_meta_window_is_on_workspace (Meta.Window window) {
        if (window.on_all_workspaces) {
            return;
        }

        unowned Meta.Display display = window.get_display ();
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        unowned Meta.Workspace current_workspace = manager.get_active_workspace ();
        unowned Meta.Workspace window_workspace = window.get_workspace ();

        if (window_workspace == null || current_workspace == null) {
            return;
        }

        window_workspace.activate_with_focus (window, display.get_current_time ());
    }

    Graphene.Point meta_window_to_desktop_coords (Meta.Window window, Graphene.Point pixels) {
        var rect = window.get_buffer_rect ();

        return Graphene.Point () {
            x = rect.x + pixels.x,
            y = rect.y + pixels.y
        };
    }

    Meta.Window? get_validated_meta_window (Meta.WindowActor? window_actor) {
        if (window_actor == null) {
            warning ("xrdesktop: Actor for move cursor not available.");
            return null;
        }

        var window = window_actor.get_meta_window ();
        if (window == null) {
            warning ("xrdesktop: No window to move");
            return null;
        }

        if (window.get_display () == null) {
            warning ("xrdesktop: Window has no display?!");
            return null;
        }

        return window;
    }

    bool is_meta_window_excluded_from_mirroring (Meta.Window window) {
        var window_type = window.get_type ();

        return window_type == Meta.WindowType.DESKTOP ||
            window_type == Meta.WindowType.DOCK ||
            window_type == Meta.WindowType.DND;
    }

    bool is_child_meta_window (Meta.Window window) {
        var window_type = window.get_type ();

        return window_type == Meta.WindowType.POPUP_MENU ||
            window_type == Meta.WindowType.DROPDOWN_MENU ||
            window_type == Meta.WindowType.TOOLTIP ||
            window_type == Meta.WindowType.MODAL_DIALOG ||
            window_type == Meta.WindowType.COMBO;
    }

    Graphene.Point get_meta_window_offset (Meta.Window parent, Meta.Window child) {
        var parent_rect = parent.get_buffer_rect ();
        var child_rect = child.get_buffer_rect ();

        var parent_center_x = parent_rect.x + parent_rect.width / 2;
        var parent_center_y = parent_rect.y + parent_rect.height / 2;

        var child_center_x = child_rect.x + child_rect.width / 2;
        var child_center_y = child_rect.y + child_rect.height / 2;

        var offset_x = child_center_x - parent_center_x;
        var offset_y = child_center_y - parent_center_y;

        debug ("xrdesktop: child at %d,%d to parent at %d,%d, offset %d,%d",
            child_center_x,
            child_center_y,
            parent_center_x,
            parent_center_y,
            offset_x,
            offset_y);

        return Graphene.Point () {
            x = offset_x,
            y = - offset_y
        };
    }
}