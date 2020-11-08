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

public class Gala.AreaTiling : Clutter.Actor, ActivatableComponent {
    const int DEFAULT_GAP = 6;
    const int ICON_SIZE = 64;

    public WindowManager wm { get; construct; }
    public bool is_shrinked = false;
    private Meta.Display display;
    private ModalProxy? modal_proxy;
    private Clutter.Actor window_icon;
    private bool _is_opened = false;
    public int pos_x;
    public int pos_y;
    private Meta.Window? current_window = null;
    private int animation_duration = 250;
    private int grid_x = 2;
    private int grid_y = 2;
    private Meta.Rectangle tile_rect;
    //  private int start_x;
    //  private int start_y;
    //  private Meta.MaximizeFlags maximize_flags;
    private int col;
    private int row;
    private int gap = DEFAULT_GAP;
    private bool order = true;
    //  private Clutter.Canvas canvas;

    public AreaTiling (WindowManager wm) {
        Object (wm : wm);
    }

    construct {
        visible = false;
        reactive = true;
        display = wm.get_display ();
        int screen_width, screen_height;
        display.get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;

        //  canvas = new Clutter.Canvas ();
        //  canvas.set_size (screen_width, screen_height);
        //  set_content (canvas);

        //  display.grab_op_begin.connect ((display, window) => {
        //      int x, y;
        //      Clutter.ModifierType type;
        //      display.get_cursor_tracker ().get_pointer (out x, out y, out type);
        //      if ((type & Gdk.ModifierType.CONTROL_MASK) != 0) {
        //          if (!_is_opened) {
        //              display.end_grab_op (display.get_current_time ());
        //              open ();
        //          }
        //      } 
        //  });
        //  display.grab_op_end.connect (on_grab_op_end);
    }

    public void open (HashTable<string,Variant>? hints = null) {
        order = true;
        current_window = display.get_focus_window ();
        if (!("mouse" in hints)) {
            Meta.Rectangle wa = current_window.get_work_area_for_monitor (display.get_current_monitor ());
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
        pos_x = (int)event.x;
        pos_y = (int)event.y;
        set_col_row_from_x_y (pos_x, pos_y);
        calculate_tile_rect ();
        update_preview ();
        return true;
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
                col = int.max(col - 1, 0);
                update_preview_keyboard ();
                break;
            case Clutter.Key.Right:
            case Clutter.Key.d:
            case Clutter.Key.l:
                col = int.min(col + 1, 2 * (grid_x - 1));
                update_preview_keyboard ();
                break;
            case Clutter.Key.Up:
            case Clutter.Key.w:
            case Clutter.Key.k:
                row = int.max(row - 1, 0);
                update_preview_keyboard ();
                break;
            case Clutter.Key.Down:
            case Clutter.Key.s:
            case Clutter.Key.j:
                row = int.min(row + 1, 2 * (grid_y - 1));
                update_preview_keyboard ();
                break;
            case Clutter.Key.G:
            case Clutter.Key.g:
                gap = gap == 0 ? DEFAULT_GAP : 0;
                update_preview ();
                break;
            case Clutter.Key.@1:
                if (order) {
                    grid_x = 1;
                } else {
                    grid_y = 1;
                }
                order = !order;
                break;
            case Clutter.Key.@2:
                if (order) {
                    grid_x = 2;
                } else {
                    grid_y = 2;
                }
                order = !order;
                break;
            case Clutter.Key.@3:
                if (order) {
                    grid_x = 3;
                } else {
                    grid_y = 3;
                }
                order = !order;
                break;
            case Clutter.Key.@4:
                if (order) {
                    grid_x = 4;
                } else {
                    grid_y = 4;
                }
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

    private void update_preview_keyboard () {
        calculate_tile_rect ();
        pos_x = tile_rect.x + tile_rect.width / 2;
        pos_y = tile_rect.y + tile_rect.height / 2;
        window_icon.set_position((float)(pos_x - ICON_SIZE / 2), (float)(pos_y - ICON_SIZE / 2));
        wm.show_tile_preview (current_window, tile_rect, display.get_current_monitor ());
    }

    private void update_preview () {
        if (!is_shrinked){
            is_shrinked = true;
            shrink_window (current_window, (float) pos_x, (float) pos_y);
        }

        //  window_icon.set_position((float) pos_x - 48.0f, (float) pos_y - 48.0f);
        window_icon.set_position((float)(pos_x - ICON_SIZE / 2), (float)(pos_y - ICON_SIZE / 2));
        wm.show_tile_preview (current_window, tile_rect, display.get_current_monitor ());
    }

    private void hide_preview () {
        if (is_shrinked) {
            is_shrinked = false;
            unshrink_window (current_window);
            wm.hide_tile_preview ();
        }
    }

    private void calculate_tile_rect () {
        Meta.Rectangle wa = current_window.get_work_area_for_monitor (display.get_current_monitor ());
        var scale = InternalUtils.get_ui_scaling_factor ();
        int grid_x = int.min(grid_x, scale * wa.width / 600);
        int grid_y = int.min(grid_y, scale * wa.height / 400);
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
        Meta.Rectangle wa = current_window.get_work_area_for_monitor (display.get_current_monitor ());
        var scale = InternalUtils.get_ui_scaling_factor ();
        // TODO: make grid_xy property
        int grid_x = int.min(grid_x, scale * wa.width / 600);
        int grid_y = int.min(grid_y, scale * wa.height / 400);
        col = int.min((int)(((3 * grid_x - 1) * (x - wa.x) / wa.width) / 1.5), 2 * (grid_x - 1));
        row = int.min((int)(((3 * grid_y - 1) * (y - wa.y) / wa.height) / 1.5), 2 * (grid_y - 1));
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
