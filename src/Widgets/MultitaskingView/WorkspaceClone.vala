//
//  Copyright (C) 2014 Tom Beckmann
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

/**
 * Utility class which adds a border and a shadow to a Background
 */
private class Gala.FramedBackground : BackgroundManager {
    private Cogl.Pipeline pipeline;
    private Cairo.ImageSurface cached_surface;
    private Cairo.Context cached_context;
    private Cogl.Texture2D cached_texture;
    private int last_width;
    private int last_height;

    public FramedBackground (Meta.Display display) {
        Object (
            display: display,
            monitor_index: display.get_primary_monitor (),
            control_position: false,
            rounded_corners: true
        );
    }

    construct {
#if HAS_MUTTER47
        unowned var ctx = context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif
        pipeline = new Cogl.Pipeline (ctx);
        var primary = display.get_primary_monitor ();
        var monitor_geom = display.get_monitor_geometry (primary);

        var effect = new ShadowEffect ("workspace");
        add_effect (effect);

        reactive = true;
    }

    public override void paint (Clutter.PaintContext context) {
        base.paint (context);

        if (cached_surface == null || last_width != (int) width || last_height != (int) height) {
            cached_texture = null;

            cached_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) width, (int) height);
            cached_context = new Cairo.Context (cached_surface);
            last_width = (int) width;
            last_height = (int) height;
        }

        var surface = cached_surface;
        var ctx = cached_context;

        ctx.set_source_rgba (255, 255, 255, 255);
        Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, 9);
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.stroke ();
        ctx.restore ();
        ctx.paint ();

        try {
            if (cached_texture == null) {
                var texture = new Cogl.Texture2D.from_data (
                    context.get_framebuffer ().get_context (),
                    (int) width, (int) height,
                    Cogl.PixelFormat.BGRA_8888_PRE,
                    surface.get_stride (), surface.get_data ()
                );

                pipeline.set_layer_texture (0, texture);
                cached_texture = texture;
            }
        } catch (Error e) {
            debug (e.message);
        }

        var color = Cogl.Color.from_4f (1.0f, 1.0f, 1.0f, 25.0f / 255.0f);
        color.premultiply ();

        pipeline.set_color (color);

        unowned var fb = context.get_framebuffer ();
        fb.draw_rectangle (pipeline, 0, 0, width, height);
    }
}

/**
 * This is the container which manages a clone of the background which will
 * be scaled and animated inwards, a WindowCloneContainer for the windows on
 * this workspace and also holds the instance for this workspace's IconGroup.
 * The latter is not added to the WorkspaceClone itself though but to a container
 * of the MultitaskingView.
 */
public class Gala.WorkspaceClone : ActorTarget {
    /**
     * The offset of the scaled background to the bottom of the monitor bounds
     */
    public const int BOTTOM_OFFSET = 100;

    /**
     * The offset of the scaled background to the top of the monitor bounds
     */
    private const int TOP_OFFSET = 20;

    /**
     * The amount of time a window has to be over the WorkspaceClone while in drag
     * before we activate the workspace.
     */
    private const int HOVER_ACTIVATE_DELAY = 400;

    /**
     * A window has been selected, the MultitaskingView should consider activating
     * and closing the view.
     */
    public signal void window_selected (Meta.Window window);

    /**
     * The background has been selected. Switch to that workspace.
     *
     * @param close_view If the MultitaskingView should also consider closing itself
     *                   after switching.
     */
    public signal void selected (bool close_view);

    public WindowManager wm { get; construct; }
    public Meta.Workspace workspace { get; construct; }
    public IconGroup icon_group { get; private set; }
    public WindowCloneContainer window_container { get; private set; }

    private float _scale_factor = 1.0f;
    public float scale_factor {
        get {
            return _scale_factor;
        }
        set {
            if (value != _scale_factor) {
                _scale_factor = value;
                reallocate ();
                update_targets ();
            }
        }
    }

    private BackgroundManager background;
    private bool opened;

    private uint hover_activate_timeout = 0;

    public WorkspaceClone (WindowManager wm, Meta.Workspace workspace, float scale) {
        Object (wm: wm,workspace: workspace, scale_factor: scale);
    }

    construct {
        opened = false;

        unowned Meta.Display display = workspace.get_display ();
        var primary_monitor = display.get_primary_monitor ();
        var monitor_geometry = display.get_monitor_geometry (primary_monitor);

        var background_click_action = new Clutter.ClickAction ();
        background_click_action.clicked.connect (() => {
            selected (true);
        });
        background = new FramedBackground (display);
        background.add_action (background_click_action);

        window_container = new WindowCloneContainer (wm, scale_factor) {
            width = monitor_geometry.width,
            height = monitor_geometry.height,
        };
        window_container.window_selected.connect ((w) => { window_selected (w); });
        window_container.requested_close.connect (() => selected (true));

        icon_group = new IconGroup (display, workspace, scale_factor);
        icon_group.selected.connect (() => selected (true));

        var icons_drop_action = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
        icon_group.add_action (icons_drop_action);

        var background_drop_action = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
        background.add_action (background_drop_action);
        background_drop_action.crossed.connect ((target, hovered) => {
            if (!hovered && hover_activate_timeout != 0) {
                Source.remove (hover_activate_timeout);
                hover_activate_timeout = 0;
                return;
            }

            if (hovered && hover_activate_timeout == 0) {
                hover_activate_timeout = Timeout.add (HOVER_ACTIVATE_DELAY, () => {
                    selected (false);
                    hover_activate_timeout = 0;
                    return false;
                });
            }
        });

        display.window_entered_monitor.connect (window_entered_monitor);
        display.window_left_monitor.connect (window_left_monitor);
        workspace.window_added.connect (add_window);
        workspace.window_removed.connect (remove_window);

        add_child (background);
        add_child (window_container);

        // add existing windows
        var windows = workspace.list_windows ();
        foreach (var window in windows) {
            if (window.window_type == Meta.WindowType.NORMAL
                && !window.on_all_workspaces
                && window.is_on_primary_monitor ()) {
                window_container.add_window (window);
                icon_group.add_window (window, true);
            }
        }

        var static_windows = StaticWindowContainer.get_instance (display);
        static_windows.window_changed.connect (on_window_static_changed);

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_targets);

        update_targets ();
    }

    ~WorkspaceClone () {
        unowned Meta.Display display = workspace.get_display ();

        display.window_entered_monitor.disconnect (window_entered_monitor);
        display.window_left_monitor.disconnect (window_left_monitor);
        workspace.window_added.disconnect (add_window);
        workspace.window_removed.disconnect (remove_window);

        background.destroy ();
        window_container.destroy ();
        icon_group.destroy ();
    }

    private void reallocate () {
        icon_group.scale_factor = scale_factor;
        window_container.monitor_scale = scale_factor;
    }

    /**
     * Add a window to the WindowCloneContainer and the IconGroup if it really
     * belongs to this workspace and this monitor.
     */
    private void add_window (Meta.Window window) {
        if (window.window_type != Meta.WindowType.NORMAL
            || window.get_workspace () != workspace
            || StaticWindowContainer.get_instance (workspace.get_display ()).is_static (window)
            || !window.is_on_primary_monitor ())
            return;

        foreach (var child in window_container.get_children ())
            if (((WindowClone) child).window == window)
                return;

        window_container.add_window (window);
        icon_group.add_window (window);
    }

    /**
     * Remove a window from the WindowCloneContainer and the IconGroup
     */
    private void remove_window (Meta.Window window) {
        window_container.remove_window (window);
        icon_group.remove_window (window, opened);
    }

    private void window_entered_monitor (Meta.Display display, int monitor, Meta.Window window) {
        add_window (window);
    }

    private void window_left_monitor (Meta.Display display, int monitor, Meta.Window window) {
        if (monitor == display.get_primary_monitor ())
            remove_window (window);
    }

    private void on_window_static_changed (Meta.Window window, bool is_static) {
        if (is_static) {
            remove_window (window);
        } else {
            add_window (window);
        }
    }

    public void update_size (Mtk.Rectangle monitor_geometry) {
        if (window_container.width != monitor_geometry.width || window_container.height != monitor_geometry.height) {
            window_container.set_size (monitor_geometry.width, monitor_geometry.height);
            background.set_size (window_container.width, window_container.height);
        }
    }

    private void update_targets () {
        remove_all_targets ();

        unowned var display = workspace.get_display ();

        var monitor = display.get_monitor_geometry (display.get_primary_monitor ());

        var scale = (float)(monitor.height - InternalUtils.scale_to_int (TOP_OFFSET + BOTTOM_OFFSET, scale_factor)) / monitor.height;
        var pivot_y = InternalUtils.scale_to_int (TOP_OFFSET, scale_factor) / (monitor.height - monitor.height * scale);
        background.set_pivot_point (0.5f, pivot_y);

        var initial_width = monitor.width;
        var target_width = monitor.width * scale + WorkspaceRow.WORKSPACE_GAP * 2;

        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "width", typeof (float), (float) initial_width, (float) target_width));
        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "scale-x", typeof (double), 1d, (double) scale));
        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "scale-y", typeof (double), 1d, (double) scale));

        window_container.padding_top = InternalUtils.scale_to_int (TOP_OFFSET, scale_factor);
        window_container.padding_left =
            window_container.padding_right = (int)(monitor.width - monitor.width * scale) / 2;
        window_container.padding_bottom = InternalUtils.scale_to_int (BOTTOM_OFFSET, scale_factor);
    }

    public override void update_progress (GestureAction action, double progress) {
        if (action == SWITCH_WORKSPACE) {
            icon_group.backdrop_opacity = 1 - (float) (workspace.index () + progress).abs ().clamp (0, 1);
        }
    }
}
