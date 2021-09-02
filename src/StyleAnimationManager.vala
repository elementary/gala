/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Utility class to draw a Cairo.Surface in a Clutter.Actor.
 */
private class Gala.CairoImageActor : Clutter.Actor {
    public Cairo.Surface? image { get; construct; }

    public CairoImageActor (Cairo.Surface image, int x, int y, int width, int height) {
        Object (image: image);
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;

        var canvas = new Clutter.Canvas ();
        canvas.set_size (width, height);
        canvas.draw.connect (draw_image);
        set_content (canvas);

        canvas.invalidate ();
    }

    private bool draw_image (Cairo.Context ctx) {
        Clutter.cairo_clear (ctx);

        ctx.set_source_surface (image, 0.0, 0.0);
        ctx.rectangle (0.0, 0.0, width, height);
        ctx.paint ();

        return true;
    }
}

/**
 * Watch for style transitions (default to dark or or vice versa) and performs
 * an animation.
 */
public class Gala.StyleAnimationManager : Object {
    public WindowManager wm { get; construct; }

    /**
     * Time to wait displaying the CairoImageActor before starting
     * the fade animation.
     */
    private const int WAIT_BEFORE_ANIMATE = 700;

    public StyleAnimationManager (WindowManager wm) {
        Object (wm: wm);
    }

    public void watch_style_transitions () {
        var granite_settings = Granite.Settings.get_default ();
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            if (wm.enable_animations) {
                animate ();
            }
        });
    }

    private void animate () {
        unowned var workspace_manager = wm.get_display ().get_workspace_manager ();
        unowned var workspace = workspace_manager.get_active_workspace ();

        foreach (unowned Meta.Window window in workspace.list_windows ()) {
            unowned var window_actor = window.get_compositor_private () as Meta.WindowActor;
            var rect = window.get_frame_rect ();
            int x = rect.x - (int) window_actor.x;
            int y = rect.y - (int) window_actor.y;
            int width = rect.width;
            int height = rect.height;

            var image = window_actor.get_image ({ x, y, width, height });
            var image_actor = new CairoImageActor (image, x, y, width, height);
            window_actor.add_child (image_actor);

            Timeout.add (WAIT_BEFORE_ANIMATE, () => {
                image_actor.set_easing_duration (AnimationDuration.STYLE);
                image_actor.set_easing_mode (Clutter.AnimationMode.LINEAR);
                image_actor.opacity = 0;

                ulong signal_id = 0U;
                signal_id = image_actor.transitions_completed.connect (() => {
                    image_actor.disconnect (signal_id);
                    window_actor.remove_child (image_actor);
                    image_actor.destroy ();
                });

                return Source.REMOVE;
            });
        }
    }
}
