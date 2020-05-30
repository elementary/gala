/*
* Copyright 2020 Felix Andreas
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
*
*/

public class Gala.AreaTiling : Object {
    public WindowManager wm { get; construct; }
    public weak Meta.Display display { get; construct; }
    private Clutter.Actor window_icon;
    public bool is_active = false;
    int animation_duration = 250;
    private int grid_x = 2;
    private int grid_y = 2;

    public AreaTiling (WindowManager wm, Meta.Display display) {
        Object (wm : wm, display : display);
    }

    public void tile(Meta.Window window, int x, int y) {
        Meta.Rectangle tile_rect;
        calculate_tile_rect (out tile_rect, window, x, y);
        window.move_resize_frame (true, tile_rect.x, tile_rect.y, tile_rect.width, tile_rect.height);
        wm.hide_tile_preview ();
    }

    public void show_preview(Meta.Window window, int x, int y) {
        if (is_active){
            window_icon.set_position((float) x - 48.0f, (float) y - 48.0f);
        } else {
            is_active = true;
            shrink_window (window, (float) x, (float) y);
        }

        Meta.Rectangle tile_rect;
        calculate_tile_rect (out tile_rect, window, x, y);
        wm.show_tile_preview (window, tile_rect, display.get_current_monitor ());
    }

    public void hide_preview (Meta.Window window) {
        if (is_active) {
            is_active = false;
            unshrink_window (window);
            wm.hide_tile_preview ();
        }
    }

    private void calculate_tile_rect(out Meta.Rectangle rect, Meta.Window window, int x, int y) {
        Meta.Rectangle wa = window.get_work_area_for_monitor (display.get_current_monitor ());
        int monitor_width = wa.width, monitor_height = wa.height;
        int monitor_x = x - wa.x, monitor_y = y - wa.y;
        int n_cols = 3 * grid_x - 1;
        int n_rows = 3 * grid_y - 1;
        int col = (int)((n_cols * monitor_x / monitor_width) / 1.5);
        int row = (int)((n_rows * monitor_y / monitor_height) / 1.5);
        rect = {
            wa.x + col / 2 * monitor_width / grid_x,
            wa.y + row / 2 * monitor_height / grid_y,
            (1 + col % 2) * monitor_width / grid_x,
            (1 + row % 2) * monitor_height / grid_y,
        };
    }

    public void shrink_window (Meta.Window? window, float x, float y) {
        float abs_x, abs_y;
        var actor = (Meta.WindowActor)window.get_compositor_private ();
        actor.get_transformed_position (out abs_x, out abs_y);
        actor.set_pivot_point ((x - abs_x) / actor.width, (y - abs_y) / actor.height);
        actor.save_easing_state ();
        actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_EXPO);
        actor.set_easing_duration (animation_duration);
        actor.set_scale (0.0f, 0.0f);
        actor.opacity = 0U;
        actor.restore_easing_state ();

        var scale_factor = InternalUtils.get_ui_scaling_factor ();
        window_icon = new WindowIcon (window, 64, scale_factor);
        window_icon.opacity = 255;
        window_icon.set_pivot_point (0.5f, 0.5f);
        var stage = actor.get_stage ();
        stage.add_child (window_icon);
    }

    public void unshrink_window (Meta.Window? window) {
        var actor = (Meta.WindowActor)window.get_compositor_private ();
        actor.set_pivot_point (0.5f, 1.0f);
        actor.set_scale (0.01f, 0.1f);
        actor.opacity = 0U;
        actor.save_easing_state ();
        actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_EXPO);
        actor.set_easing_duration (animation_duration);
        actor.set_scale (1.0f, 1.0f);
        actor.opacity = 255U;
        actor.restore_easing_state ();
        window_icon.opacity = 0;
    }
}
