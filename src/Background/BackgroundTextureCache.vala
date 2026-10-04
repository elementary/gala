/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Denis Garaev <garaevdi@yandex.ru>
 */

#if HAS_MUTTER51
public class Gala.BackgroundTextureCache : Object {
    public Meta.Display display { private get; construct; }

    private static GLib.Once<BackgroundTextureCache> instance;
    public static unowned BackgroundTextureCache get_default (Meta.Display display) {
        return instance.once (() => new BackgroundTextureCache (display));
    }

    private Gee.HashMap<string, BackgroundTexture> textures;

    private BackgroundTextureCache (Meta.Display display) {
        Object (display: display);
    }

    construct {
        textures = new Gee.HashMap<string, BackgroundTexture> ();
    }

    public BackgroundTexture load (File file) throws Error {
        var uri = file.get_uri ();

        if (textures.has_key (uri)) {
            return textures.get (uri);
        }

        var background_texture = new BackgroundTexture ();
        background_texture.load_texture.begin (file, display);
        textures.set (uri, background_texture);
        return background_texture;
    }

    public Cogl.Texture? get_texture (string path) {
        var file = File.new_for_path (path);
        var uri = file.get_uri ();
        if (textures.has_key (uri)) {
            return textures.get (uri).texture;
        }

        return null;
    }

    public void purge (File file) {
        var uri = file.get_uri ();
        if (textures.has_key (uri)) {
            textures.unset (uri, null);
        }
    }
}
#endif
