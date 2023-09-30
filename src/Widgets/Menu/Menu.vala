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
    public const int WRAPPER_PADDING = 5;
    private const string CAPTION_FONT_NAME = "Inter";
    private const int MIN_OFFSET = 64;
    private const int ANIMATION_DURATION = 200;

    public bool opened { get; private set; default = false; }

    public Gala.WindowManager? wm { get; construct; }
    private Gala.ModalProxy modal_proxy = null;

    private Granite.Settings granite_settings;
    private Clutter.Canvas canvas;
    private Clutter.Actor container;
    private ShadowEffect shadow_effect;

    private Gtk.StyleContext style_context;
    private unowned Gtk.CssProvider? dark_style_provider = null;

    private bool first_release = true;

    public WindowMenu (Gala.WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        unowned var gtk_settings = Gtk.Settings.get_default ();
        granite_settings = Granite.Settings.get_default ();

        canvas = new Clutter.Canvas ();

        shadow_effect = new ShadowEffect (40) {
            shadow_opacity = 200,
            css_class = "window-switcher"
        };
        add_effect (shadow_effect);

        var box_layout = new Clutter.BoxLayout () {
            orientation = VERTICAL
        };

        container = new Clutter.Actor () {
            layout_manager = box_layout
        };

        layout_manager = new Clutter.BinLayout ();
        opacity = 0;
        add_child (container);
        set_content (canvas);

        // Redraw the components if the colour scheme changes.
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            canvas.invalidate ();
        });

        gtk_settings.notify["gtk-theme-name"].connect (() => {
            canvas.invalidate ();
        });

        unowned var display = wm.get_display ();
        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            var cur_scale = display.get_monitor_scale (display.get_current_monitor ());
            scale (cur_scale);
        });
        scale (display.get_monitor_scale (display.get_current_monitor ()));

        notify["allocation"].connect (() => canvas.set_size ((int) width, (int) height));

        canvas.draw.connect (draw);

        add_menuitem (new MenuItem ("Change Wallpaper..."));
        add_menuitem (new MenuItem ("Display Settings..."));
        var sep = new SeparatorMenuItem ();
        container.add_child (sep);
        sep.scale (wm.get_display ().get_monitor_scale (wm.get_display ().get_current_monitor ()));
        add_menuitem (new MenuItem ("System Settings..."));
    }

    public void add_menuitem (MenuItem menuitem) {
        container.add_child (menuitem);
        menuitem.scale (wm.get_display ().get_monitor_scale (wm.get_display ().get_current_monitor ()));
    }

    public void scale (float scale_factor) {
        canvas.scale_factor = scale_factor;
        shadow_effect.scale_factor = scale_factor;

        container.margin_top = container.margin_bottom = InternalUtils.scale_to_int (6, scale_factor);

        foreach (var child in get_children ()) {
            if (child is MenuItem) {
                ((MenuItem) child).scale (scale_factor);
                continue;
            }

            if (child is SeparatorMenuItem) {
                ((SeparatorMenuItem) child).scale (scale_factor);
                continue;
            }
        }
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
    public override bool key_press_event (Clutter.Event event) {
#else
    public override bool key_press_event (Clutter.KeyEvent event) {
#endif
        switch (event.get_key_symbol ()) {
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
