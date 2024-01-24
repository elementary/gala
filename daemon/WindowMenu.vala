public class WindowMenu : Gtk.Popover {
    private static GLib.Settings gala_keybind_settings = new GLib.Settings ("org.pantheon.desktop.gala.keybindings");
    private static GLib.Settings keybind_settings = new GLib.Settings ("org.gnome.desktop.wm.keybindings");

    public signal void perform_action (Gala.ActionType type);

    private Granite.AccelLabel screenshot_accellabel;
    private Granite.AccelLabel close_accellabel;
    private Gtk.Button close;
    private Gtk.Button screenshot;

    construct {
        screenshot_accellabel = new Granite.AccelLabel (_("Take Screenshot"));

        screenshot = new Gtk.Button () {
            child = screenshot_accellabel
        };
        screenshot.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
        screenshot.clicked.connect (() => {
            perform_action (Gala.ActionType.SCREENSHOT_CURRENT);
        });

        close_accellabel = new Granite.AccelLabel (_("Close"));

        close = new Gtk.Button () {
            child = close_accellabel
        };
        close.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
        close.clicked.connect (() => {
            perform_action (Gala.ActionType.CLOSE_CURRENT);
        });

        var content = new Gtk.Box (VERTICAL, 0);
        content.add (screenshot);
        content.add (new Gtk.Separator (HORIZONTAL));
        content.add (close);

        child = content;
    }

    public void update (Gala.WindowFlags flags) {
        screenshot_accellabel.accel_string = gala_keybind_settings.get_strv ("window-screenshot")[0];

        close.visible = Gala.WindowFlags.CAN_CLOSE in flags;
        if (close.visible) {
            close_accellabel.accel_string = keybind_settings.get_strv ("close")[0];
        }
    }
}