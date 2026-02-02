// TODO: copyright

public class Gala.WindowAnimationsManager : GLib.Object {
    private const int MAX_TRANSLATION = 20;

    public WindowManager wm { private get; construct; }

    private Meta.Window? current_window;
    private Meta.GrabOp current_op;
    private int current_offset_x;
    private int current_offset_y;
    private Mtk.Rectangle previous_frame_rect;
    private Graphene.Point previous_cursor_position;

    public WindowAnimationsManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        unowned var display = wm.get_display ();

        display.grab_op_begin.connect (on_grab_op_begin);
        display.grab_op_end.connect (on_grab_op_end);
    }

    private void on_grab_op_begin (Meta.Window window, Meta.GrabOp op) {
        if (op == NONE || op == WINDOW_BASE || op == MOVING || op == MOVING_UNCONSTRAINED || op == KEYBOARD_MOVING) {
            return;
        }

        unowned var laters = wm.get_display ().get_compositor ().get_laters ();
        laters.add (BEFORE_REDRAW, () => {
            if (current_window == null) {
                return false;
            }

            check_window_size ();
            return true;
        });

#if HAS_MUTTER48
        unowned var cursor_tracker = wm.get_display ().get_compositor ().get_backend ().get_cursor_tracker ();
#else
        unowned var cursor_tracker = wm.get_display ().get_cursor_tracker ();
#endif
        Graphene.Point cursor_coords;
        cursor_tracker.get_pointer (out cursor_coords, null);

        var frame_rect = window.get_frame_rect ();

        current_window = window;
        current_op = op;
        previous_frame_rect = frame_rect;
        previous_cursor_position = cursor_coords;

        var start_x = frame_rect.x;
        if (current_op == RESIZING_E ||
            current_op == RESIZING_NE ||
            current_op == RESIZING_SE
        ) {
            start_x += frame_rect.width;
        }

        var start_y = frame_rect.y;
        if (current_op == RESIZING_S ||
            current_op == RESIZING_SW ||
            current_op == RESIZING_SE
        ) {
            start_y += frame_rect.height;
        }

        current_offset_x = start_x - (int) cursor_coords.x;
        current_offset_y = start_y - (int) cursor_coords.y;
    }

    private void on_grab_op_end (Meta.Window window, Meta.GrabOp op) requires (current_window != null) {
        unowned var window_actor = (Meta.WindowActor) current_window.get_compositor_private ();
        window_actor.set_translation (0.0f, 0.0f, 0.0f);

        current_window = null;
    }

    private void check_window_size () requires (current_window != null) {
        var frame_rect = current_window.get_frame_rect ();

#if HAS_MUTTER48
        unowned var cursor_tracker = wm.get_display ().get_compositor ().get_backend ().get_cursor_tracker ();
#else
        unowned var cursor_tracker = wm.get_display ().get_cursor_tracker ();
#endif
        Graphene.Point cursor_coords;
        cursor_tracker.get_pointer (out cursor_coords, null);

        var offset_x = frame_rect.x - (int) cursor_coords.x;
        if (current_op == RESIZING_E ||
            current_op == RESIZING_NE ||
            current_op == RESIZING_SE
        ) {
            offset_x += frame_rect.width;
        }

        var offset_y = frame_rect.y - (int) cursor_coords.y;
        if (current_op == RESIZING_S ||
            current_op == RESIZING_SW ||
            current_op == RESIZING_SE
        ) {
            offset_y += frame_rect.height;
        }

        var x_multiplier = 1;
        if (current_op == RESIZING_N || current_op == RESIZING_S || frame_rect.width >= previous_frame_rect.width) {
            x_multiplier = 0;
        }

        var y_multiplier = 1;
        if (current_op == RESIZING_W || current_op == RESIZING_E || frame_rect.height >= previous_frame_rect.width) {
            y_multiplier = 0;
        }

        var diff_x = (current_offset_x - offset_x) * x_multiplier;
        var diff_y = (current_offset_y - offset_y) * y_multiplier;

        var translation_x = Math.nearbyintf (MAX_TRANSLATION * ((float) diff_x / frame_rect.width).clamp (-1.0f, 1.0f));
        var translation_y = Math.nearbyintf (MAX_TRANSLATION * ((float) diff_y / frame_rect.height).clamp (-1.0f, 1.0f));

        unowned var window_actor = (Meta.WindowActor) current_window.get_compositor_private ();
        window_actor.set_translation (translation_x, translation_y, 0.0f);

        previous_cursor_position = cursor_coords;
    }
}
