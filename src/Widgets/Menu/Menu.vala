/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Menu : Clutter.Actor {
    public Gala.WindowManager? wm { get; construct; }

    private Gala.ModalProxy modal_proxy = null;

    private Clutter.Actor container;
    private ShadowEffect shadow_effect;
    private Clutter.Canvas canvas;

    private Gtk.StyleContext style_context;
    private unowned Gtk.CssProvider? dark_style_provider = null;

    private MenuItem? _selected = null;
    private MenuItem? selected {
        get {
            return _selected;
        }
        set {
            if (_selected != null) {
                _selected.selected = false;
            }

            _selected = value;
            if (_selected != null) {
                _selected.selected = true;
            }
        }
    }

    public Menu (Gala.WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        var box_layout = new Clutter.BoxLayout () {
            orientation = VERTICAL
        };

        container = new Clutter.Actor () {
            layout_manager = box_layout
        };

        shadow_effect = new ShadowEffect (40) {
            shadow_opacity = 200,
            css_class = "window-switcher"
        };

        canvas = new Clutter.Canvas ();

        layout_manager = new Clutter.BinLayout ();
        add_child (container);
        add_effect (shadow_effect);
        set_content (canvas);

        Granite.Settings.get_default ().notify["prefers-color-scheme"].connect (() => canvas.invalidate ());
        Gtk.Settings.get_default ().notify["gtk-theme-name"].connect (() => canvas.invalidate ());

        unowned var display = wm.get_display ();
        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            scale (display.get_monitor_scale (display.get_current_monitor ()));
        });
        scale (display.get_monitor_scale (display.get_current_monitor ()));

        notify["allocation"].connect (() => canvas.set_size ((int) width, (int) height));

        canvas.draw.connect (draw);
    }

    public void add_menuitem (MenuItem menuitem) {
        container.add_child (menuitem);
        menuitem.scale (wm.get_display ().get_monitor_scale (wm.get_display ().get_current_monitor ()));
        menuitem.activated.connect (() => close_menu ());

        menuitem.enter_event.connect (() => {
            selected = menuitem;
            return false;
        });

        menuitem.leave_event.connect (() => {
            selected = null;
            return false;
        });
    }

    public void add_separator () {
        var separator = new SeparatorMenuItem ();
        container.add_child (separator);
        separator.scale (wm.get_display ().get_monitor_scale (wm.get_display ().get_current_monitor ()));
    }

    public void open_menu () {
        base.show ();

#if HAS_MUTTER45
        //TODO: I think that's correct but didn't test it
        Mtk.Rectangle rect;
        wm.get_display ().get_monitor_geometry (wm.get_display ().get_current_monitor (), out rect);
#else
        var rect = wm.get_display ().get_monitor_geometry (wm.get_display ().get_current_monitor ());
#endif

        if (width + x > rect.x + rect.width) {
            x = rect.x + rect.width - width;
        }

        if (height + y > rect.y + rect.height) {
            y = rect.y + rect.height - height;
        }

        modal_proxy = wm.push_modal (this);
    }

    public void close_menu () {
        selected = null;
        wm.pop_modal (modal_proxy);

        base.hide ();
    }

    private void scale (float scale_factor) {
        canvas.scale_factor = scale_factor;
        shadow_effect.scale_factor = scale_factor;

        container.margin_top = container.margin_bottom = InternalUtils.scale_to_int (6, scale_factor);

        foreach (var child in container.get_children ()) {
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

        if (Granite.Settings.get_default ().prefers_color_scheme == DARK) {
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

    public override bool button_release_event (Clutter.ButtonEvent event) {
        close_menu ();
        return true;
    }

#if HAS_MUTTER45
    public override bool key_press_event (Clutter.Event event) {
#else
    public override bool key_press_event (Clutter.KeyEvent event) {
#endif
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Up:
                cycle_menuitems (true);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Down:
                cycle_menuitems (false);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Escape:
                close_menu ();
                return Clutter.EVENT_PROPAGATE;
            case Clutter.Key.Return:
                if (selected != null) {
                    selected.activated ();
                }
                close_menu ();
                return Clutter.EVENT_PROPAGATE;
        }

        return Clutter.EVENT_PROPAGATE;
    }

    private void cycle_menuitems (bool backwards) {
        Clutter.Actor child;
        if (selected != null) {
            if (backwards) {
                child = selected.get_previous_sibling () != null ? selected.get_previous_sibling () : container.last_child;
            } else {
                child = selected.get_next_sibling () != null ? selected.get_next_sibling () : container.first_child;
            }
        } else {
            child = backwards ? container.last_child : container.first_child;
        }

        while (child != null) {
            if (child is MenuItem) {
                selected = (MenuItem) child;
                break;
            }

            child = backwards ? child.get_previous_sibling () : child.get_next_sibling ();
        }
    }
}
