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
    public int grid_x = 2;
    public int grid_y = 2;
    public int[] tile_widths;
    public int[] tile_heights;

    public AreaTiling (WindowManager wm) {
        Object (wm : wm);
    }

    construct {
        display = wm.get_display ();
        int screen_width, screen_height;
        display.get_size (out screen_width, out screen_height);
        int tile_width = screen_width / grid_x;
        int tile_height = screen_height / grid_y;
        tile_widths = {tile_width, tile_width};
        tile_heights = {tile_height, tile_height};
    }

    public void tile (Meta.Window window, int x, int y) {
        Meta.Rectangle tile_rect;
        calculate_tile_rect (out tile_rect, window, x, y);
        window.move_resize_frame (true, tile_rect.x, tile_rect.y, tile_rect.width, tile_rect.height);
        wm.hide_tile_preview ();
    }

    public void show_preview (Meta.Window window, int x, int y) {
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

    public void calculate_tile_rect (out Meta.Rectangle rect, Meta.Window window, int x, int y) {
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

public class Gala.TilingGrid : Clutter.Actor, ActivatableComponent {
    public WindowManager wm { get; construct; }
    public AreaTiling area_tiling { get; construct; }
    private Meta.Display display;
    private ModalProxy? modal_proxy;
    private Gdk.Point start_point;
    private Clutter.Canvas canvas;

    public TilingGrid (WindowManager wm, AreaTiling area_tiling) {
        Object (wm: wm, area_tiling: area_tiling);
    }

    construct {
        visible = false;
        reactive = true;
        display = wm.get_display ();

        int screen_width, screen_height;
        display.get_size (out screen_width, out screen_height);

        width = screen_width;
        height = screen_height;

        canvas = new Clutter.Canvas ();
        canvas.set_size (screen_width, screen_height);
        canvas.draw.connect (draw_grid);
        set_content (canvas);
        canvas.invalidate ();
    }

    public bool is_opened () {
        return visible;
    }

    public void open (HashTable<string,Variant>? hints = null) {
        debug("open Tiling Grid!");
        visible = true;
        wm.get_display ().set_cursor (Meta.Cursor.CROSSHAIR);
        grab_key_focus ();
        modal_proxy = wm.push_modal ();
        modal_proxy.keybinding_filter = binding => binding.get_name () != "show-grid";
    }

    public void close () {
        debug("close Tiling Grid!");
        visible = false;
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);
        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }
    }

    public override bool key_press_event (Clutter.KeyEvent e) {
        debug("presss key!");
        if (e.keyval == Clutter.Key.Escape) {
            close ();
            return true;
        }
        content.invalidate ();
        return false;
    }

    public override bool button_press_event (Clutter.ButtonEvent e) {
        area_tiling.tile_widths[0] = (int) e.x;
        area_tiling.tile_heights[0] = (int) e.y;
        content.invalidate ();
        return true;
    }

    //  public override bool motion_event (Clutter.MotionEvent e) {
    //      debug("motion event!!");
    //      start_point.x = (int) e.x;
    //      start_point.y = (int) e.y;
    //      content.invalidate ();
    //      return true;
    //  }

    private bool draw_grid (Cairo.Context ctx) {
        debug("draw grid!");
        Clutter.cairo_clear (ctx);
        int line_width = 5;
        int grid_x = area_tiling.grid_x;
        int grid_y = area_tiling.grid_y;
        //  ctx.translate (0.5, 0.5);


        for (var monitor = 0; monitor < display.get_n_monitors (); monitor++) {
            var geometry = display.get_monitor_geometry (monitor);
            debug (@"x $(geometry.x), y $(geometry.y), width $(geometry.width), height $(geometry.height)");

            
            int start_x = geometry.x + line_width;
            for (int i = 0; i < grid_x; i ++) {
                int width = area_tiling.tile_widths[i];
                int start_y = geometry.y + line_width;
                for (int j = 0; j < grid_y; j ++) {
                    int height = area_tiling.tile_heights[j];
                    debug(@"hieght: $(height);");
                    ctx.rectangle (start_x, start_y, width - 2 * line_width, height - 2 * line_width);
                    ctx.set_source_rgba (0.1, 0.1, 0.1, 0.8);
                    ctx.fill ();
                    //  ctx.rectangle (x + i * width, y + j * height, width - 2 * line_width, height - 2 * line_width);
                    //  ctx.set_source_rgba (1.0, 1.0, 1.0, 0.8);
                    //  ctx.set_line_width (line_width);
                    //  ctx.set_dash ({5.0}, 5.0);
                    //  ctx.stroke ();
                    start_y += height;
                }
                start_x += width;
            }
        }
        return true;
    }
}
