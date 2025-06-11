/*
 * Copyright 2015 Corentin Noël
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#if !HAS_MUTTER48
public class Gala.Image : Clutter.Image {
    public Image.from_pixbuf (Gdk.Pixbuf pixbuf) {
        Object ();

        Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
        try {
            set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
        } catch (Error e) {}
    }
}
#else
public class Gala.Image : GLib.Object, Clutter.Content {
    Gdk.Pixbuf? pixbuf;
    Cogl.Texture? texture;
    uint width;
    uint height;

    public Image.from_pixbuf (Gdk.Pixbuf pixbuf) {
        this.pixbuf = pixbuf;
        width = pixbuf.width;
        height = pixbuf.height;
        invalidate ();
    }

    public bool get_preferred_size (out float width, out float height) {
        if (texture == null) {
            width = 0;
            height = 0;
            return false;
        }

        width = texture.get_width ();
        height = texture.get_height ();
        return true;
    }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode node, Clutter.PaintContext paint_context) {
        if (pixbuf != null && texture == null) {
            var cogl_context = actor.context.get_backend ().get_cogl_context ();
            Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
            try {
                texture = new Cogl.Texture2D.from_data (cogl_context, pixbuf.width, pixbuf.height, pixel_format, pixbuf.rowstride, pixbuf.get_pixels ());
                if (width != texture.get_width () || height != texture.get_height ()) {
                    width = texture.get_width ();
                    height = texture.get_height ();
                    invalidate_size ();
                }
            } catch (Error e) {
                critical (e.message);
            }
        }

        if (texture == null)
            return;

        var content_node = actor.create_texture_paint_node (texture);
        content_node.set_static_name ("Image Content");
        node.add_child (content_node);
    }

    public void invalidate () {
        texture = null;
    }

    public void invalidate_size () {
    }
}
#endif
