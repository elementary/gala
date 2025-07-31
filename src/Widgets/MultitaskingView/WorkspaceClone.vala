/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2025 elementary, Inc. (https://elementary.io)
 */

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

        add_effect (new ShadowEffect ("workspace", display.get_monitor_scale (display.get_primary_monitor ())));

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
            critical ("FramedBackground: Couldn't create texture: %s", e.message);
        }

        var color = Cogl.Color.from_4f (1.0f, 1.0f, 1.0f, 25.0f / 255.0f);
        color.premultiply ();

        pipeline.set_color (color);

        context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, width, height);
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

    public WindowManager wm { get; construct; }
    public Meta.Workspace workspace { get; construct; }
    public float monitor_scale { get; construct set; }

    public WindowCloneContainer window_container { get; private set; }

    private BackgroundManager background;
    private uint hover_activate_timeout = 0;

    public WorkspaceClone (WindowManager wm, Meta.Workspace workspace, float monitor_scale) {
        Object (wm: wm, workspace: workspace, monitor_scale: monitor_scale);
    }

    construct {
        unowned var display = workspace.get_display ();
        var monitor_geometry = display.get_monitor_geometry (display.get_primary_monitor ());

        var background_click_action = new Clutter.ClickAction ();
        background_click_action.clicked.connect (() => activate (true));
        background = new FramedBackground (display);
        background.add_action (background_click_action);

        window_container = new WindowCloneContainer (wm, monitor_scale) {
            width = monitor_geometry.width,
            height = monitor_geometry.height,
        };
        window_container.window_selected.connect ((w) => window_selected (w));
        window_container.requested_close.connect (() => activate (true));
        bind_property ("monitor-scale", window_container, "monitor-scale");

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
                    activate (false);
                    hover_activate_timeout = 0;

                    return Source.REMOVE;
                });
            }
        });

        display.window_entered_monitor.connect (window_entered_monitor);
        display.window_left_monitor.connect (window_left_monitor);
        workspace.window_added.connect (add_window);
        workspace.window_removed.connect (window_container.remove_window);

        add_child (background);
        add_child (window_container);

        // add existing windows
        foreach (var window in workspace.list_windows ()) {
            add_window (window);
        }

        var static_windows = StaticWindowContainer.get_instance (display);
        static_windows.window_changed.connect (on_window_static_changed);

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_targets);
        notify["monitor-scale"].connect (update_targets);
        update_targets ();
    }

    ~WorkspaceClone () {
        unowned var display = workspace.get_display ();

        display.window_entered_monitor.disconnect (window_entered_monitor);
        display.window_left_monitor.disconnect (window_left_monitor);
        workspace.window_added.disconnect (add_window);
        workspace.window_removed.disconnect (window_container.remove_window);

        background.destroy ();
        window_container.destroy ();
    }

    /**
     * Add a window to the WindowCloneContainer if it belongs to this workspace and this monitor.
     */
    private void add_window (Meta.Window window) {
        if (window.window_type != NORMAL ||
            window.get_workspace () != workspace ||
            StaticWindowContainer.get_instance (workspace.get_display ()).is_static (window) ||
            !window.is_on_primary_monitor ()
        ) {
            return;
        }

        foreach (var child in (GLib.List<weak WindowClone>) window_container.get_children ()) {
            if (child.window == window) {
                return;
            }
        }

        window_container.add_window (window);
    }

    private void window_entered_monitor (Meta.Display display, int monitor, Meta.Window window) {
        add_window (window);
    }

    private void window_left_monitor (Meta.Display display, int monitor, Meta.Window window) {
        if (monitor == display.get_primary_monitor ()) {
            window_container.remove_window (window);
        }
    }

    private void on_window_static_changed (Meta.Window window, bool is_static) {
        if (is_static) {
            window_container.remove_window (window);
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

        var scale = (float)(monitor.height - Utils.scale_to_int (TOP_OFFSET + BOTTOM_OFFSET, monitor_scale)) / monitor.height;
        var pivot_y = Utils.scale_to_int (TOP_OFFSET, monitor_scale) / (monitor.height - monitor.height * scale);
        background.set_pivot_point (0.5f, pivot_y);

        var initial_width = monitor.width;
        var target_width = monitor.width * scale + WorkspaceRow.WORKSPACE_GAP * 2;

        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "width", typeof (float), (float) initial_width, (float) target_width));
        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "scale-x", typeof (double), 1d, (double) scale));
        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "scale-y", typeof (double), 1d, (double) scale));

        window_container.padding_top = Utils.scale_to_int (TOP_OFFSET, monitor_scale);
        window_container.padding_left = window_container.padding_right = (int)(monitor.width - monitor.width * scale) / 2;
        window_container.padding_bottom = Utils.scale_to_int (BOTTOM_OFFSET, monitor_scale);
    }

    private void activate (bool close_view) {
        if (close_view && workspace.active) {
            wm.perform_action (SHOW_MULTITASKING_VIEW);
        } else {
            workspace.activate (Meta.CURRENT_TIME);
        }
    }
}
