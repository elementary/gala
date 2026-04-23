/*
 * Copyright 2015 Corentin Noël
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
#if !HAS_MUTTER46
public class Gala.Image : Clutter.Image, Clutter.Content {
    private int width;
    private int height;

    public Image.from_pixbuf_with_size (int width, int height, Gdk.Pixbuf pixbuf) {
        Object ();

        this.width = width;
        this.height = height;

        Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
        try {
            set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
        } catch (Error e) {}
    }

    public Image.from_pixbuf (Gdk.Pixbuf pixbuf) {
        Object ();

        Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
        try {
            set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
        } catch (Error e) {}
    }

    public override bool get_preferred_size (out float width, out float height) {
        width = this.width;
        height = this.height;
        return true;
    }
}
#else
public class Gala.Image : GLib.Object, Clutter.Content {
    public int width { get; construct; }
    public int height { get; construct; }
    public Gdk.Pixbuf pixbuf { get; construct; }

    private Cogl.Texture? texture;

    public Image.from_pixbuf_with_size (int width, int height, Gdk.Pixbuf pixbuf) {
        Object (width: width, height: height, pixbuf: pixbuf);
    }

    public Image.from_pixbuf (Gdk.Pixbuf pixbuf) {
        Object (width: pixbuf.width, height: pixbuf.height, pixbuf: pixbuf);
    }

    public bool get_preferred_size (out float width, out float height) {
        if (texture == null) {
            width = 0;
            height = 0;
            return false;
        }

        width = this.width;
        height = this.height;
        return true;
    }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode node, Clutter.PaintContext paint_context) {
        if (pixbuf != null && texture == null) {
#if HAS_MUTTER48
            var cogl_context = actor.context.get_backend ().get_cogl_context ();
#else
            var cogl_context = Clutter.get_default_backend ().get_cogl_context ();
#endif
            Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
            try {
                texture = new Cogl.Texture2D.from_data (cogl_context, pixbuf.width, pixbuf.height, pixel_format, pixbuf.rowstride, pixbuf.get_pixels ());
            } catch (Error e) {
                critical (e.message);
            }
        }

        if (texture == null)
            return;

        var content_node = actor.create_texture_paint_node (texture);

#if HAS_MUTTER48
        content_node.set_static_name ("Image Content");
#endif
        node.add_child (content_node);
    }

    public void invalidate () { }

    public void invalidate_size () { }
}
#endif
