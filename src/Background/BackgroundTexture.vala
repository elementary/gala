/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Denis Garaev <garaevdi@yandex.ru>
 */

#if HAS_MUTTER51
public errordomain TextureLoadError {
    UNSUPPOERTED_FORMAT,
    FAILED_TO_SET_TEXTURE_DATA
}

public class Gala.BackgroundTexture : Object {
    public Cogl.Texture? texture { get; private set; default = null; }
    public signal void loaded ();

    public bool is_loaded () {
        return texture != null;
    }

    // This function is a port of gnome-shell's method of loading textures with glycin
    // https://gitlab.gnome.org/GNOME/gnome-shell/-/blob/2177bdf9624b2d285de7c1d34274073d3769d6b8/js/ui/background.js#L240
    public async void load_texture (File file, Meta.Display display) throws Error {
        var stream = yield file.read_async (Priority.DEFAULT_IDLE, null);

        var loader = new Gly.Loader.for_stream (stream);

        loader.set_accepted_memory_formats (
            Gly.MemoryFormatSelection.B8G8R8A8_PREMULTIPLIED |
            Gly.MemoryFormatSelection.A8R8G8B8_PREMULTIPLIED |
            Gly.MemoryFormatSelection.R8G8B8A8_PREMULTIPLIED |
            Gly.MemoryFormatSelection.B8G8R8A8 |
            Gly.MemoryFormatSelection.A8R8G8B8 |
            Gly.MemoryFormatSelection.R8G8B8A8 |
            Gly.MemoryFormatSelection.A8B8G8R8 |
            Gly.MemoryFormatSelection.R8G8B8 |
            Gly.MemoryFormatSelection.B8G8R8 |
            Gly.MemoryFormatSelection.R16G16B16A16_PREMULTIPLIED |
            Gly.MemoryFormatSelection.R16G16B16A16 |
            Gly.MemoryFormatSelection.R16G16B16A16_FLOAT |
            Gly.MemoryFormatSelection.R32G32B32A32_FLOAT_PREMULTIPLIED |
            Gly.MemoryFormatSelection.R32G32B32A32_FLOAT
        );

        var image = yield loader.load_async (null);

        var frame = image.next_frame ();

        var width = (int) frame.get_width ();
        var height = (int) frame.get_height ();
        var bytes = frame.get_buf_bytes ();
        var format = frame.get_memory_format ();

        var components = format.has_alpha () ? Cogl.TextureComponents.RGBA : Cogl.TextureComponents.RGB;
        var ctx = Utils.get_clutter_backend_from_display (display).get_cogl_context ();

        Cogl.Texture texture = new Cogl.Texture2D.with_size (ctx, width, height);
        texture.set_components (components);

        try {
            texture.allocate ();
        } catch {
            texture = new Cogl.Texture2DSliced.with_size (ctx, width, height, Cogl.TEXTURE_MAX_WASTE);
            texture.set_components (components);
        }

        var cogl_format = gly_to_cogl_format (frame.get_memory_format ());

        if (!texture.set_data (cogl_format, (int) frame.get_stride (), bytes.get_data (), 0)) {
            throw (new TextureLoadError.FAILED_TO_SET_TEXTURE_DATA ("Failed to set texture data"));
        }

       this.texture = texture;
       loaded ();
    }

    private Cogl.PixelFormat gly_to_cogl_format (Gly.MemoryFormat format) throws Error {
        switch (format) {
        case Gly.MemoryFormat.B8G8R8A8_PREMULTIPLIED:
            return Cogl.PixelFormat.BGRA_8888_PRE;
        case Gly.MemoryFormat.A8R8G8B8_PREMULTIPLIED:
            return Cogl.PixelFormat.ARGB_8888_PRE;
        case Gly.MemoryFormat.R8G8B8A8_PREMULTIPLIED:
            return Cogl.PixelFormat.RGBA_8888_PRE;
        case Gly.MemoryFormat.B8G8R8A8:
            return Cogl.PixelFormat.BGRA_8888;
        case Gly.MemoryFormat.A8R8G8B8:
            return Cogl.PixelFormat.ARGB_8888;
        case Gly.MemoryFormat.R8G8B8A8:
            return Cogl.PixelFormat.RGBA_8888;
        case Gly.MemoryFormat.A8B8G8R8:
            return Cogl.PixelFormat.ABGR_8888;
        case Gly.MemoryFormat.R8G8B8:
            return Cogl.PixelFormat.RGB_888;
        case Gly.MemoryFormat.B8G8R8:
            return Cogl.PixelFormat.BGR_888;
        case Gly.MemoryFormat.R16G16B16A16_PREMULTIPLIED:
            return Cogl.PixelFormat.RGBA_16161616_PRE;
        case Gly.MemoryFormat.R16G16B16A16:
            return Cogl.PixelFormat.RGBA_16161616;
        case Gly.MemoryFormat.R16G16B16A16_FLOAT:
            return Cogl.PixelFormat.RGBA_FP_16161616;
        case Gly.MemoryFormat.R32G32B32A32_FLOAT_PREMULTIPLIED:
            return Cogl.PixelFormat.RGBA_FP_32323232_PRE;
        case Gly.MemoryFormat.R32G32B32A32_FLOAT:
            return Cogl.PixelFormat.RGBA_FP_32323232;
        default:
            throw (new TextureLoadError.UNSUPPOERTED_FORMAT ("Unsupported color format"));
        }
    }
}
#endif
