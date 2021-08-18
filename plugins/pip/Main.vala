//
//  Copyright (C) 2017 Adam Bieńkowski
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

 public class Gala.Plugins.PIP.Plugin : Gala.Plugin {
    private Gee.ArrayList<PopupWindow> windows;
    private Gala.WindowManager? wm = null;
    private SelectionArea? selection_area;

    construct {
        windows = new Gee.ArrayList<PopupWindow> ();
    }

    public override void initialize (Gala.WindowManager wm) {
        this.wm = wm;
        var display = wm.get_display ();
        var settings = new GLib.Settings (Config.SCHEMA + ".keybindings");

        display.add_keybinding ("pip", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
    }

    public override void destroy () {
        clear_selection_area ();

        foreach (var popup_window in windows) {
            untrack_window (popup_window);
        }

        windows.clear ();
    }

    [CCode (instance_pos = -1)]
    void on_initiate (Meta.Display display, Meta.Window? window, Clutter.KeyEvent event,
        Meta.KeyBinding binding) {
        var target_actor = get_active_window_actor ();
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
        clear_selection_area ();

        var active = get_active_window_actor ();
        if (active != null) {
            var window = active.get_meta_window ();
            var frame = window.get_frame_rect ();
            var popup_window = new PopupWindow (wm, active);

            // Don't clip if the entire window was selected
            if (frame.x != x || frame.y != y || frame.width != width || frame.height != height) {
                int point_x = x - (int)frame.x;
                int point_y = y - (int)frame.y;

                var rect = Graphene.Rect.alloc ();
                rect.init (point_x, point_y, width, height);

                popup_window.set_container_clip (rect);
            }

            popup_window.show.connect (on_popup_window_show);
            popup_window.hide.connect (on_popup_window_hide);
            add_window (popup_window);
        }
    }

    private void on_popup_window_show (Clutter.Actor popup_window) {
        track_actor (popup_window);
        update_region ();
    }

    private void on_popup_window_hide (Clutter.Actor popup_window) {
        untrack_actor (popup_window);
        update_region ();
    }

    private void clear_selection_area () {
        if (selection_area != null) {
            untrack_actor (selection_area);
            update_region ();

            selection_area.destroy ();
            selection_area = null;
        }
    }

    private Meta.WindowActor? get_active_window_actor () {
        unowned Meta.Display display = wm.get_display ();
        unowned List<Meta.WindowActor> actors = display.get_window_actors ();

        var copy = actors.copy ();
        copy.reverse ();

        weak Meta.WindowActor? active = null;
        actors.@foreach ((actor) => {
            if (active != null) {
                return;
            }

            var window = actor.get_meta_window ();
            if (!actor.is_destroyed () && !window.is_hidden () && !window.is_skip_taskbar () && window.has_focus ()) {
                active = actor;
            }
        });

        return active;
    }

    private void add_window (PopupWindow popup_window) {
        popup_window.closed.connect (() => remove_window (popup_window));
        windows.add (popup_window);
        wm.ui_group.add_child (popup_window);
    }

    private void remove_window (PopupWindow popup_window) {
        windows.remove (popup_window);
        untrack_window (popup_window);
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
