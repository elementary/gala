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

        add_effect (new ShadowEffect ("workspace", Utils.get_ui_scaling_factor (display, display.get_primary_monitor ())));

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
    private const int BOTTOM_OFFSET = 100;

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
    private Clutter.Actor background_container;
    private WindowListModel windows;
    private uint hover_activate_timeout = 0;

    public WorkspaceClone (WindowManager wm, Meta.Workspace workspace, float monitor_scale) {
        Object (wm: wm, workspace: workspace, monitor_scale: monitor_scale);
    }

    class construct {
        set_layout_manager_type (typeof (Clutter.BinLayout));
    }

    construct {
        unowned var display = workspace.get_display ();
        var monitor_geometry = display.get_monitor_geometry (display.get_primary_monitor ());

        var background_click_action = new Clutter.ClickAction ();
        background_click_action.clicked.connect (() => activate (true));
        background = new FramedBackground (display);
        background.add_action (background_click_action);

        // Background will always request the whole unscaled monitor size and we can't
        // force it smaller via set_size because that would cause effects to get the size wrong
        // Therefore put it into this container and force the container's size to the scaled size
        background_container = new Clutter.Actor ();
        background_container.add_child (background);

        windows = new WindowListModel (display, STACKING, true, display.get_primary_monitor (), workspace);

        window_container = new WindowCloneContainer (wm, windows, monitor_scale);
        window_container.window_selected.connect ((window) => window_selected (window));
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

        add_child (background_container);
        add_child (window_container);

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_targets);
        notify["monitor-scale"].connect (update_targets);
        update_targets ();
    }

    ~WorkspaceClone () {
        background.destroy ();
        window_container.destroy ();
    }

    private void update_targets () {
        remove_all_targets ();

        unowned var display = workspace.get_display ();
        var primary = display.get_primary_monitor ();

        windows.monitor_filter = primary;

        var monitor = display.get_monitor_geometry (primary);

        background_container.height = window_container.height = monitor.height;

        var scale = (float)(monitor.height - Utils.scale_to_int (TOP_OFFSET + BOTTOM_OFFSET, monitor_scale)) / monitor.height;
        var pivot_y = Utils.scale_to_int (TOP_OFFSET, monitor_scale) / (monitor.height - monitor.height * scale);
        background.set_pivot_point (0f, pivot_y);

        var initial_width = monitor.width;
        var target_width = (int) Math.ceilf (monitor.width * scale);

        add_target (new PropertyTarget (MULTITASKING_VIEW, background_container, "width", typeof (float), (float) initial_width, (float) target_width));
        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "scale-x", typeof (double), 1d, (double) scale));
        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "scale-y", typeof (double), 1d, (double) scale));
        add_target (new PropertyTarget (MULTITASKING_VIEW, window_container, "width", typeof (float), (float) initial_width, (float) target_width));

        window_container.area = {
            12, Utils.scale_to_int (TOP_OFFSET, monitor_scale), target_width - 24, (int) (monitor.height * scale)
        };
    }

    private void activate (bool close_view) {
        if (close_view && workspace.active) {
            wm.perform_action (SHOW_MULTITASKING_VIEW);
        } else {
            workspace.activate (Meta.CURRENT_TIME);
        }
    }
}
