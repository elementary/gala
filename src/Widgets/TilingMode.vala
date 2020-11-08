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

public class Gala.TilingMode : Clutter.Actor, ActivatableComponent {
    const int DEFAULT_GAP = 12;
    const int ICON_SIZE = 64;

    public WindowManager wm { get; construct; }
    public bool is_shrinked = false;
    private Meta.Display display;
    private ModalProxy? modal_proxy;
    private Clutter.Actor window_icon;
    private int animation_duration = 250;
    private int scale;
    private bool _is_opened = false;
    private Meta.Window? current_window = null;
    private int current_monitor;
    private int pos_x;
    private int pos_y;
    private int _grid[2];
    private int grid_x {
        get { 
            var wa = current_window.get_work_area_for_monitor (current_monitor);
            return int.min (_grid[0], scale * wa.width / 600);
        }
    }
    private int grid_y {
        get { 
            var wa = current_window.get_work_area_for_monitor (current_monitor);
            return int.min (_grid[1], scale * wa.height / 400);
        }
    }
    private Meta.Rectangle tile_rect;
    private int col;
    private int row;
    private int max_col { get { return 2 * (grid_x - 1); } }
    private int max_row { get { return 2 * (grid_y - 1); } }
    private int gap = DEFAULT_GAP;
    private bool order = true;

    public TilingMode (WindowManager wm) {
        Object (wm : wm);
    }

    construct {
        reactive = true;
        _grid[0] = 2;
        _grid[1] = 2;
        display = wm.get_display ();
        scale = InternalUtils.get_ui_scaling_factor ();
        int screen_width, screen_height;
        display.get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;
    }

    public void open (HashTable<string,Variant>? hints = null) {
        order = true;
        current_window = display.get_focus_window ();
        if (("mouse" in hints)) {
            current_monitor = display.get_current_monitor ();
            int pointer_x, pointer_y;
            display.get_cursor_tracker ().get_pointer (out pointer_x, out pointer_y, null);
            pos_x = pointer_x;
            pos_y = pointer_y;
        } else {
            current_monitor = current_window.get_monitor ();
            Meta.Rectangle wa = current_window.get_work_area_for_monitor (current_monitor);
            pos_x = wa.x + wa.width / 2;
            pos_y = wa.y + wa.height / 2;
        }

        set_col_row_from_x_y (pos_x, pos_y);
        calculate_tile_rect ();
        update_preview ();

        visible = true;
        _is_opened = true;
        grab_key_focus ();
        modal_proxy = wm.push_modal ();
    }

    public void close () {
        if (current_window != null) {
            tile ();
            hide_preview ();
            current_window = null;
        }

        visible = false;
        _is_opened = false;
        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }
    }

    public bool is_opened () {
        return _is_opened;
    }

    public override bool button_press_event (Clutter.ButtonEvent event) {
        if (event.button == 1) {
            close ();
            return true;
        } 
        return false;
    }

    public override bool button_release_event (Clutter.ButtonEvent event) {
        if (event.button == 1) {
            close ();
            return true;
        } 
        return false;
    }

    public override bool motion_event (Clutter.MotionEvent event) {
        update_state_from_motion ((int)event.x, (int)event.y);
        return true;
    }

    private void update_state_from_motion (int x, int y) {
        pos_x = x;
        pos_y = y;
        current_monitor = display.get_current_monitor ();
        set_col_row_from_x_y (pos_x, pos_y);
        calculate_tile_rect ();
        update_preview ();
    }

    public override bool key_press_event (Clutter.KeyEvent event) {
        switch (event.keyval) {
            case Clutter.Key.Escape:
            case Clutter.Key.Return:
            case Clutter.Key.KP_Enter:
            case Clutter.Key.space:
                close ();
                break;
            case Clutter.Key.Left:
            case Clutter.Key.a:
            case Clutter.Key.h:
                update_state_from_direction (Meta.MotionDirection.LEFT);
                break;
            case Clutter.Key.Right:
            case Clutter.Key.d:
            case Clutter.Key.l:
                update_state_from_direction (Meta.MotionDirection.RIGHT);
                break;
            case Clutter.Key.Up:
            case Clutter.Key.w:
            case Clutter.Key.k:
                update_state_from_direction (Meta.MotionDirection.UP);
                break;
            case Clutter.Key.Down:
            case Clutter.Key.s:
            case Clutter.Key.j:
                update_state_from_direction (Meta.MotionDirection.DOWN);
                break;
            case Clutter.Key.G:
            case Clutter.Key.g:
                gap = gap == 0 ? DEFAULT_GAP : 0;
                calculate_tile_rect ();
                update_preview ();
                break;
            case Clutter.Key.@1:
                _grid[(int)order] = 1;
                order = !order;
                break;
            case Clutter.Key.@2:
                _grid[(int)order] = 2;
                order = !order;
                break;
            case Clutter.Key.@3:
                _grid[(int)order] = 3;
                order = !order;
               order = !order;
                break;
            case Clutter.Key.@4:
                _grid[(int)order] = 4;
                order = !order;
                break;
            default:
                return false;
        }

        return true;
    }

    private void tile () {
        if (current_window.maximized_horizontally || current_window.maximized_vertically) {
            current_window.unmaximize (Meta.MaximizeFlags.BOTH);
        }

        current_window.move_resize_frame (true, tile_rect.x, tile_rect.y, tile_rect.width, tile_rect.height);
    }

    private void set_col_row_from_direction (Meta.MotionDirection? direction) {
        switch (direction) {
            case Meta.MotionDirection.LEFT:
                if (col > 0) {
                    col -= 1; 
                } else {
                    var neighbor = display.get_monitor_neighbor_index (current_monitor, Meta.DisplayDirection.LEFT);
                    if (neighbor != -1) {
                        var old_max_row = max_row;
                        current_monitor = neighbor;
                        col = max_col;
                        row = (row + (max_row - old_max_row) / 2).clamp (0, max_row);
                    }
                }
                break;
            case Meta.MotionDirection.RIGHT:
                if (col < max_col) {
                    col += 1; 
                } else {
                    var neighbor = display.get_monitor_neighbor_index (current_monitor, Meta.DisplayDirection.RIGHT);
                    if (neighbor != -1) {
                        var old_max_row = max_row;
                        current_monitor = neighbor;
                        col = 0;
                        row = (row + (max_row - old_max_row) / 2).clamp (0, max_row);
                    }
                }
                break;
            case Meta.MotionDirection.UP:
                if (row > 0) {
                    row -= 1; 
                } else {
                    var neighbor = display.get_monitor_neighbor_index (current_monitor, Meta.DisplayDirection.UP);
                    if (neighbor != -1) {
                        var old_max_col = max_col;
                        current_monitor = neighbor;
                        col = (col + (max_col - old_max_col) / 2).clamp (0, max_col);
                        row = max_row;
                    }
                }
                break;
            case Meta.MotionDirection.DOWN:
                if (row < max_row) {
                    row += 1; 
                } else {
                    var neighbor = display.get_monitor_neighbor_index (current_monitor, Meta.DisplayDirection.DOWN);
                    if (neighbor != -1) {
                        var old_max_col = max_col;
                        current_monitor = neighbor;
                        col = (col + (max_col - old_max_col) / 2).clamp (0, max_col);
                        row = 0;
                    }
                }
                break;
            default:
                return;
        }
    }

    private void update_state_from_direction (Meta.MotionDirection direction) {
        set_col_row_from_direction (direction);
        calculate_tile_rect ();
        pos_x = tile_rect.x + tile_rect.width / 2;
        pos_y = tile_rect.y + tile_rect.height / 2;
        window_icon.set_position ((float)(pos_x - ICON_SIZE / 2), (float)(pos_y - ICON_SIZE / 2));
        wm.show_tile_preview (current_window, tile_rect, current_monitor);
    }

    private void update_preview () {
        if (!is_shrinked){
            is_shrinked = true;
            shrink_window (current_window, (float) pos_x, (float) pos_y);
        }

        window_icon.set_position ((float)(pos_x - ICON_SIZE / 2), (float)(pos_y - ICON_SIZE / 2));
        wm.show_tile_preview (current_window, tile_rect, current_monitor);
    }

    private void hide_preview () {
        if (is_shrinked) {
            is_shrinked = false;
            unshrink_window (current_window);
            wm.hide_tile_preview ();
        }
    }

    private void calculate_tile_rect () {
        Meta.Rectangle wa = current_window.get_work_area_for_monitor (current_monitor);
        int gap = gap * scale;
        int tile_width = (wa.width - (grid_x + 1) * gap) / grid_x;
        int tile_height = (wa.height - (grid_y + 1) * gap) / grid_y;
        tile_rect = {
            wa.x + gap + (col >> 1) * (tile_width + gap),
            wa.y + gap + (row >> 1) * (tile_height + gap),
            tile_width + (col & 1) * (tile_width + gap),
            tile_height + (row & 1) * (tile_height + gap),
        };
    }

    private void set_col_row_from_x_y (int x, int y) {
        Meta.Rectangle wa = current_window.get_work_area_for_monitor (current_monitor);
        col = ((int)(((3 * grid_x - 1) * (x - wa.x) / wa.width) / 1.5)).clamp (0, max_col);
        row = ((int)(((3 * grid_y - 1) * (y - wa.y) / wa.height) / 1.5)).clamp (0, max_row);
    }

    private void shrink_window (Meta.Window? window, float x, float y) {
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

        var scale = InternalUtils.get_ui_scaling_factor ();
        window_icon = new WindowIcon (window, ICON_SIZE, scale);
        window_icon.opacity = 255;
        window_icon.set_pivot_point (0.5f, 0.5f);
        add_child (window_icon);
    }

    private void unshrink_window (Meta.Window? window) {
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
        remove_child (window_icon);
    }

    //  private void show_grid () {
    //      debug ("show_grid: Not implemented yet!");
    //  }
}
