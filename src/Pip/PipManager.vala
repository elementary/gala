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

public class Gala.Pip.PipManager : GLib.Object {
    private const int MIN_SELECTION_SIZE = 30;

    public WindowManager wm {get; construct; }

    private static PipManager instance;

    private Gee.ArrayList<PopupWindow> windows;
    private SelectionArea? selection_area;

    public static void init (WindowManager wm) {
        if (instance == null) {
            instance = new PipManager (wm);
        }
    }

    private PipManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        windows = new Gee.ArrayList<PopupWindow> ();

        unowned var display = wm.get_display ();
        var settings = new GLib.Settings (Config.SCHEMA + ".keybindings");
        display.add_keybinding ("pip", settings, Meta.KeyBindingFlags.IGNORE_AUTOREPEAT, (Meta.KeyHandlerFunc) on_initiate);
    }

    [CCode (instance_pos = -1)]
    private void on_initiate (Meta.Display display, Meta.Window? window, Clutter.KeyEvent event,
        Meta.KeyBinding binding) {
        selection_area = new SelectionArea (wm);
        selection_area.selected.connect (on_selection_actor_selected);
        selection_area.captured.connect (on_selection_actor_captured);
        selection_area.closed.connect (clear_selection_area);

        wm.ui_group.add_child (selection_area);

        selection_area.start_selection ();
    }

    private void on_selection_actor_selected (int x, int y) {
        clear_selection_area ();
        select_window_at (x, y);
    }

    private void on_selection_actor_captured (int x, int y, int width, int height) {
        clear_selection_area ();

        if (width < MIN_SELECTION_SIZE || height < MIN_SELECTION_SIZE) {
            select_window_at (x, y);
        } else {
            var active = get_active_window_actor ();
            if (active != null) {
                int point_x = x - (int)active.x;
                int point_y = y - (int)active.y;

                // Compensate for server-side window decorations
                var input_rect = active.get_meta_window ().get_buffer_rect ();
                var outer_rect = active.get_meta_window ().get_frame_rect ();
                point_x -= outer_rect.x - input_rect.x;
                point_y -= outer_rect.y - input_rect.y;

                var rect = Graphene.Rect.alloc ();
                rect.init (point_x, point_y, width, height);

                var popup_window = new PopupWindow (wm, active);
                popup_window.set_container_clip (rect);
                add_window (popup_window);
            }
        }
    }

    private void select_window_at (int x, int y) {
        var selected = get_window_actor_at (x, y);
        if (selected != null) {
            var popup_window = new PopupWindow (wm, selected);
            add_window (popup_window);
        }
    }

    private void clear_selection_area () {
        if (selection_area != null) {
            selection_area.destroy ();
            selection_area = null;
        }
    }

    private Meta.WindowActor? get_window_actor_at (int x, int y) {
        unowned Meta.Display display = wm.get_display ();
        unowned List<Meta.WindowActor> actors = display.get_window_actors ();

        var copy = actors.copy ();
        copy.reverse ();

        weak Meta.WindowActor? selected = null;
        copy.@foreach ((actor) => {
            if (selected != null) {
                return;
            }

            var window = actor.get_meta_window ();
            var rect = window.get_frame_rect ();

            if (!actor.is_destroyed () && !window.is_hidden () && !window.is_skip_taskbar () && meta_rectangle_contains (rect, x, y)) {
                selected = actor;
            }
        });

        return selected;
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
        popup_window.destroy ();
    }

    private static inline bool meta_rectangle_contains (Meta.Rectangle rect, int x, int y) {
        return x >= rect.x && x < rect.x + rect.width
            && y >= rect.y && y < rect.y + rect.height;
    }
}
