public class WindowSwitcherIcon : Gtk.FlowBoxChild {
    public uint64 uid { get; construct; }
    public string title { get; construct; }
    public string app_id { get; construct; }

    public WindowSwitcherIcon (uint64 uid, string title, string app_id) {
        Object (
            uid: uid,
            title: title,
            app_id: app_id
        );
    }

    construct {
        var desktop_app_info = new DesktopAppInfo (app_id);

        var image = new Gtk.Image.from_gicon (desktop_app_info.get_icon ()) {
            pixel_size = 64,
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };

        child = image;

        var hover_controller = new Gtk.EventControllerMotion ();
        hover_controller.enter.connect (() => grab_focus ());
        add_controller (hover_controller);
    }
}
