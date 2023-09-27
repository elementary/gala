/*
 * Copyright 2021 Aral Balkan <mail@ar.al>
 * Copyright 2020 Mark Story <mark@mark-story.com>
 * Copyright 2017 Popye <sailor3101@gmail.com>
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowMenu : Clutter.Actor {
    public const int ICON_SIZE = 64;
    public const int WRAPPER_PADDING = 12;
    private const string CAPTION_FONT_NAME = "Inter";
    private const int MIN_OFFSET = 64;
    private const int ANIMATION_DURATION = 200;

    public bool opened { get; private set; default = false; }

    public Gala.WindowManager? wm { get; construct; }
    private Gala.ModalProxy modal_proxy = null;

    private Granite.Settings granite_settings;
    private Clutter.Canvas canvas;

    private Gtk.WidgetPath widget_path;
    private Gtk.StyleContext style_context;
    private unowned Gtk.CssProvider? dark_style_provider = null;

    private bool first_release = true;
    private bool drawn = false;

    private float scaling_factor = 1.0f;

    public WindowMenu (Gala.WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        unowned var gtk_settings = Gtk.Settings.get_default ();
        granite_settings = Granite.Settings.get_default ();

        unowned var display = wm.get_display ();
        scaling_factor = display.get_monitor_scale (display.get_current_monitor ());

        canvas = new Clutter.Canvas ();
        canvas.scale_factor = scaling_factor;
        set_content (canvas);

        opacity = 0;

        layout_manager = new Clutter.BoxLayout () {
            orientation = VERTICAL
        };

        // Carry out the initial draw
        create_components ();

        var effect = new ShadowEffect (40) {
            shadow_opacity = 200,
            css_class = "window-switcher",
            scale_factor = scaling_factor
        };
        add_effect (effect);

        // Redraw the components if the colour scheme changes.
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            canvas.invalidate ();
            create_components ();
        });

        gtk_settings.notify["gtk-theme-name"].connect (() => {
            canvas.invalidate ();
            create_components ();
        });

        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            var cur_scale = display.get_monitor_scale (display.get_current_monitor ());
            if (cur_scale != scaling_factor) {
                scaling_factor = cur_scale;
                canvas.scale_factor = scaling_factor;
                effect.scale_factor = scaling_factor;
                create_components ();
            }
        });

        notify["allocation"].connect (() => canvas.set_size ((int) width, (int) height));

        canvas.draw.connect (draw);

        motion_event.connect (on_motion_event);
    }

    private bool draw (Cairo.Context ctx, int width, int height) {
        if (style_context == null) { // gtk is not initialized yet
            create_gtk_objects ();
        }

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
            unowned var gtksettings = Gtk.Settings.get_default ();
            dark_style_provider = Gtk.CssProvider.get_named (gtksettings.gtk_theme_name, "dark");
            style_context.add_provider (dark_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } else if (dark_style_provider != null) {
            style_context.remove_provider (dark_style_provider);
            dark_style_provider = null;
        }

        ctx.set_operator (Cairo.Operator.OVER);
        style_context.render_background (ctx, 0, 0, width, height);
        style_context.render_frame (ctx, 0, 0, width, height);
        ctx.restore ();

        return true;
    }

    private void create_components () {
        // We've already been constructed once, start again
        if (drawn) {
            destroy_all_children ();
        }

        drawn = true;

        var margin = InternalUtils.scale_to_int (WRAPPER_PADDING, scaling_factor);
    }

    private void create_gtk_objects () {
        var window = new Gtk.Window ();

        style_context = window.get_style_context ();
        style_context.add_class ("csd");
        style_context.add_class ("unified");
    }

    public void open_menu () {
        if (opened) {
            return;
        }

        opacity = 0;

        canvas.invalidate ();

        toggle_display (true);
    }

    public void toggle_display (bool show) {
        if (opened == show) {
            return;
        }

        opened = show;
        if (show) {
            push_modal ();
        } else {
            wm.pop_modal (modal_proxy);
        }

        save_easing_state ();
        set_easing_duration (wm.enable_animations ? ANIMATION_DURATION : 0);
        opacity = show ? 255 : 0;
        restore_easing_state ();
    }

    private void push_modal () {
        modal_proxy = wm.push_modal (this);
        modal_proxy.set_keybinding_filter ((binding) => {
            var action = Meta.Prefs.get_keybinding_action (binding.get_name ());

            switch (action) {
                case Meta.KeyBindingAction.NONE:
                case Meta.KeyBindingAction.LOCATE_POINTER_KEY:
                case Meta.KeyBindingAction.SWITCH_APPLICATIONS:
                case Meta.KeyBindingAction.SWITCH_APPLICATIONS_BACKWARD:
                case Meta.KeyBindingAction.SWITCH_WINDOWS:
                case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
                case Meta.KeyBindingAction.SWITCH_GROUP:
                case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
                    return false;
                default:
                    break;
            }

            return true;
        });

    }

    public override void key_focus_out () {
        toggle_display (false);
    }

    public override bool button_release_event (Clutter.ButtonEvent event) {
        if (first_release) {
            first_release = false;
            return true;
        }

        toggle_display (false);
        first_release = true;
        return true;
    }

#if HAS_MUTTER45
    private bool on_motion_event (Clutter.Event event) {
#else
    private bool on_motion_event (Clutter.MotionEvent event) {
#endif
        // float x, y;
        // event.get_coords (out x, out y);
        // var actor = container.get_stage ().get_actor_at_pos (Clutter.PickMode.ALL, (int)x, (int)y);
        // if (actor == null) {
        //     return true;
        // }

        // var selected = actor as WindowSwitcherIcon;
        // if (selected == null) {
        //     return true;
        // }

        // if (current_icon != selected) {
        //     current_icon = selected;
        // }

        return true;
    }

#if HAS_MUTTER45
    public override bool key_press_event (Clutter.Event event) {
#else
    public override bool key_press_event (Clutter.KeyEvent event) {
#endif
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Right:
                // next_window (false);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Left:
                // next_window (true);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Escape:
                toggle_display (false);
                return Clutter.EVENT_PROPAGATE;
            case Clutter.Key.Return:
                toggle_display (false);
                return Clutter.EVENT_PROPAGATE;
        }

        return Clutter.EVENT_PROPAGATE;
    }
}
