// TODO: copyright

class Gala.CloseButton : Clutter.Actor {
    construct {
        reactive = true;

        if ((var pixbuf = get_close_button_pixbuf (scale)) != null) {
            try {
                var image = new Clutter.Image ();
                Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
                image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
                texture.set_content (image);
                texture.set_size (pixbuf.width, pixbuf.height);
            } catch (Error e) {}
        } else {
            // we'll just make this red so there's at least something as an
            // indicator that loading failed. Should never happen and this
            // works as good as some weird fallback-image-failed-to-load pixbuf
            texture.set_size (scale_to_int (36, scale), scale_to_int (36, scale));
            texture.background_color = { 255, 0, 0, 255 };
        }
    }
}