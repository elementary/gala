public class Gala.Window : Gtk.Window {
    static construct {
        var app_provider = new Gtk.CssProvider ();
        app_provider.load_from_resource ("io/elementary/desktop/gala-daemon/gala-daemon.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), app_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public Gtk.Box content { get; construct; }

    public Window (int width, int height) {
        Object (
            default_width: width,
            default_height: height
        );
    }

    class construct {
        set_css_name ("daemon-window");
    }

    construct {
        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        input_shape_combine_region (null);
        accept_focus = false;
        skip_taskbar_hint = true;
        skip_pager_hint = true;
        type_hint = Gdk.WindowTypeHint.TOOLTIP;
        set_keep_above (true);

        child = content = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true,
            vexpand = true
        };

        set_visual (get_screen ().get_rgba_visual());

        show_all ();
        move (0, 0);

        button_press_event.connect (() => {
            close ();
            return Gdk.EVENT_STOP;
        });
    }
}