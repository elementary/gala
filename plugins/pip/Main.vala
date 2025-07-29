/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017 Adam Bieńkowski
 *                         2024-2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.Plugins.PIP.Plugin : Gala.Plugin {
    private Gee.ArrayList<PopupWindow> windows = new Gee.ArrayList<PopupWindow> ();
    private WindowManager wm;
    private SelectionArea? selection_area;

    public override void initialize (Gala.WindowManager _wm) {
        wm = _wm;

        var settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
        wm.get_display ().add_keybinding ("pip", settings, IGNORE_AUTOREPEAT, on_initiate);
    }

    public override void destroy () {
        clear_selection_area ();

        foreach (var popup_window in windows) {
            untrack_window (popup_window);
        }

        windows.clear ();
    }

    private void on_initiate (Meta.Display display, Meta.Window? window, Clutter.KeyEvent? event, Meta.KeyBinding binding) {
        unowned var target_window = display.focus_window;
        if (target_window == null || !Utils.get_window_is_normal (target_window) || target_window.skip_taskbar) {
            return;
        }

        var target_frame = target_window.get_frame_rect ();
        if (target_frame.width < SelectionArea.MIN_SELECTION || target_frame.height < SelectionArea.MIN_SELECTION) {
            return;
        }

        unowned var target_actor = (Meta.WindowActor) target_window.get_compositor_private ();
        if (target_actor == null) {
            return;
        }

        selection_area = new SelectionArea (wm, target_actor);
        selection_area.captured.connect (on_selection_actor_captured);
        selection_area.closed.connect (clear_selection_area);

        track_actor (selection_area);
        wm.ui_group.add_child (selection_area);

        selection_area.start_selection ();
    }

    private void on_selection_actor_captured (int x, int y, int width, int height) {
        var popup_window = new PopupWindow (wm.get_display (), selection_area.target_actor);
        windows.add (popup_window);
        wm.ui_group.add_child (popup_window);

        popup_window.show.connect ((_popup_window) => {
            track_actor (_popup_window);
            update_region ();
        });
        popup_window.hide.connect ((_popup_window) => {
            untrack_actor (_popup_window);
            update_region ();
        });
        popup_window.closed.connect ((_popup_window) => {
            windows.remove (_popup_window);
            untrack_window (_popup_window);
        });

        var frame = selection_area.target_actor.meta_window.get_frame_rect ();

        // Don't clip if the entire window was selected
        if (frame.x != x || frame.y != y || frame.width != width || frame.height != height) {
            var point_x = x - frame.x;
            var point_y = y - frame.y;

            popup_window.set_container_clip ({ { point_x, point_y }, { width, height } });
        }

        clear_selection_area ();
    }

    private void clear_selection_area () {
        if (selection_area == null) {
            return;
        }

        untrack_actor (selection_area);
        update_region ();

        selection_area.destroy ();
        selection_area = null;
    }

    private void untrack_window (PopupWindow popup_window) {
        untrack_actor (popup_window);
        update_region ();
        popup_window.destroy ();
    }
}

public Gala.PluginInfo register_plugin () {
    return Gala.PluginInfo () {
        name = "Popup Window",
        author = "Adam Bieńkowski <donadigos159@gmail.com>",
        plugin_type = typeof (Gala.Plugins.PIP.Plugin),
        provides = Gala.PluginFunction.ADDITION,
        load_priority = Gala.LoadPriority.IMMEDIATE
    };
}
