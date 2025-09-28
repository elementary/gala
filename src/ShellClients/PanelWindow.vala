/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelWindow : ShellWindow {
    public PanelWindow (WindowManager wm, Meta.Window window, Pantheon.Desktop.Anchor anchor) {
        Object (wm: wm, anchor: anchor, window: window, position: Position.from_anchor (anchor));
    }

    construct {
        notify["anchor"].connect (() => position = Position.from_anchor (anchor));

        unowned var workspace_manager = window.display.get_workspace_manager ();
        workspace_manager.workspace_added.connect (update_strut);
        workspace_manager.workspace_removed.connect (update_strut);

        window.size_changed.connect (update_strut);
        window.position_changed.connect (update_strut);
        notify["width"].connect (update_strut);
        notify["height"].connect (update_strut);
    }

    public void request_visible_in_multitasking_view () {
        visible_in_multitasking_view = true;
        actor.add_action (new DragDropAction (DESTINATION, "multitaskingview-window"));
    }
}
