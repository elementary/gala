// TODO: copyright

public class Gala.CloseButton : Clutter.Actor {
    private const uint ANIMATION_DURATION = 100;

    private static Gee.HashMap<int, Gdk.Pixbuf?> close_pixbufs;

    public float scale { get; construct set; }

    public CloseButton (float scale) {
        Object (scale: scale);
    }

    static construct {
        close_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf?> ();
    }

    construct {
        reactive = true;
        pivot_point = { 0.5f, 0.5f };

        var pixbuf = get_close_button_pixbuf (scale);
        if (pixbuf != null) {
            try {
                var image = new Clutter.Image ();
                Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
                image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);

                set_content (image);
                set_size (pixbuf.width, pixbuf.height);
            } catch (Error e) {
                create_error_texture ();
            }
        } else {
            create_error_texture ();
        }
    }

    private static Gdk.Pixbuf? get_close_button_pixbuf (float scale) {
        var height = Utils.scale_to_int (36, scale);

        if (close_pixbufs[height] == null) {
            try {
                close_pixbufs[height] = new Gdk.Pixbuf.from_resource_at_scale (
                    Config.RESOURCEPATH + "/buttons/close.svg",
                    -1,
                    height,
                    true
                );
            } catch (Error e) {
                critical (e.message);
                return null;
            }
        }

        return close_pixbufs[height];
    }

    private void create_error_texture () {
        // we'll just make this red so there's at least something as an
        // indicator that loading failed. Should never happen and this
        // works as good as some weird fallback-image-failed-to-load pixbuf
        critical ("Could not create close button");

        var size = Utils.scale_to_int (36, scale);
        set_size (size, size);
        background_color = { 255, 0, 0, 255 };
    }

#if HAS_MUTTER45
    public override bool button_press_event (Clutter.Event e) {
#else
    public override bool button_press_event (Clutter.ButtonEvent e) {
#endif
        var estimated_duration = (uint) (ANIMATION_DURATION * (scale_x - 0.8) / 0.2);

        warning ("Here %u", estimated_duration);

        save_easing_state ();
        set_easing_duration (estimated_duration);
        set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT);
        set_scale (0.8, 0.8);
        restore_easing_state ();

        return Clutter.EVENT_STOP;
    }

#if HAS_MUTTER45
    public override bool button_release_event (Clutter.Event e) {
#else
    public override bool button_release_event (Clutter.ButtonEvent e) {
#endif
        var estimated_duration = (uint) (ANIMATION_DURATION * (1.0 - scale_x) / 0.2);

        warning ("Here 2 %u", estimated_duration);

        save_easing_state ();
        set_easing_duration (estimated_duration);
        set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT);
        set_scale (1.0, 1.0);
        restore_easing_state ();

        return Clutter.EVENT_STOP;
    }
}