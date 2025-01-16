/*
 * Copyright 2015 Corentin Noël
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#if !HAS_MUTTER46
public class Gala.Image : Clutter.Image {
    public Image.from_pixbuf (Gdk.Pixbuf pixbuf) {
        Object ();

        Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
        set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
    }
}
#else
public class Gala.Image : GLib.Object, Clutter.Content {
    Cogl.Texture? texture;
    int width;
    int height;

    public Image.from_pixbuf (Gdk.Pixbuf pixbuf) {
        Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
        //image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
    }

    public bool get_preferred_size (out float width, out float height) {
        if (texture == null)
            return false;

        width = texture.get_width ();
        height = texture.get_height ();
        return true;
    }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode node, Clutter.PaintContext paint_context) {
        if (texture == null)
            return;

        var content_node = actor.create_texture_paint_node (texture);
        content_node.set_static_name ("Image Content");
        node.add_child (content_node);
    }

    public void invalidate () {
        
    }

    public void invalidate_size () {
        
    }
/*
    gboolean
    st_image_content_set_data (StImageContent   *content,
                               const guint8     *data,
                               CoglPixelFormat   pixel_format,
                               guint             width,
                               guint             height,
                               guint             row_stride,
                               GError          **error)
    {
      g_return_val_if_fail (ST_IS_IMAGE_CONTENT (content), FALSE);
      g_return_val_if_fail (data != NULL, FALSE);

      if (content->texture != NULL)
        g_object_unref (content->texture);

      content->texture = create_texture_from_data (width,
                                                   height,
                                                   pixel_format,
                                                   row_stride,
                                                   data,
                                                   error);

      if (content->texture == NULL)
        return FALSE;

      clutter_content_invalidate (CLUTTER_CONTENT (content));
      update_image_size (content);

      return TRUE;
    }


    set_data (this, data, pixel_format, width, height, row_stride) throws {
        backend = Clutter.Backend.get_default();
        cogl_context = backend.get_cogl_context ();
        this.texture = Cogl.Texture2D.new_from_data (cogl_context, width, height, pixel_format, row_stride, data, error);

        if (!this.texture)
            return;
        
        this.content_invalidate ();

        int width = this.texture.get_width();
        int height = this.texture.get_height();

        if (this.width == width && this.height == height)
            return;

        this.width = width;
        this.height = height;    
        this.invalidate_size();
    }*/
}
#endif
