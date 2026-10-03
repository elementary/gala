/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Icon : Clutter.Actor {
    private class GIconSource : Object, IconSource {
        private static Gtk.IconTheme icon_theme = new Gtk.IconTheme () {
            theme_name = "elementary"
        };

        public GLib.Icon gicon { get; construct; }

        public GIconSource (GLib.Icon gicon) {
            Object (gicon: gicon);
        }

        public string? get_cache_key (int size, float scale) {
            var gicon_str = gicon.to_string ();
            return gicon_str != null ? "gicon-%s-%d-%f".printf (gicon_str, size, scale) : null;
        }

        public Gdk.Pixbuf create_pixbuf (int size, float scale) throws Error {
            var icon_paintable = icon_theme.lookup_by_gicon (gicon, size, (int) Math.ceilf (scale), NONE, 0);

            var file = icon_paintable?.file;
            if (file == null) {
                throw new IOError.FAILED ("Icon paintable has no file");
            }

            return new Gdk.Pixbuf.from_stream_at_scale (file.read (), -1, get_texture_size (size, scale), true);
        }
    }

    private class ResourceIconSource : Object, IconSource {
        public string path { get; construct; }

        public ResourceIconSource (string path) {
            Object (path: path);
        }

        public string? get_cache_key (int size, float scale) {
            return "%s-%d".printf (path, get_texture_size (size, scale));
        }

        public Gdk.Pixbuf create_pixbuf (int size, float scale) throws Error {
            return new Gdk.Pixbuf.from_resource_at_scale (path, -1, get_texture_size (size, scale), true);
        }
    }

    private interface IconSource : Object {
        public abstract string? get_cache_key (int size, float scale);
        /**
         * Should look up the icon for the given size (e.g. if there are more detailed icons
         * for larger sizes) and return a texture of size * scale.
         */
        public abstract Gdk.Pixbuf create_pixbuf (int size, float scale) throws Error;

        protected static int get_texture_size (int size, float scale) {
            return (int) Math.ceilf (size * scale);
        }
    }

    private static HashTable<string, Gdk.Pixbuf> icon_pixbufs = new HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);

    public int icon_size { get; construct set; }
    public float monitor_scale { get; construct set; }

    public string resource_path { set { source = new ResourceIconSource (value); } }
    public GLib.Icon gicon { set { source = new GIconSource (value); } }

    private IconSource _source;
    private IconSource source {
        get { return _source; }
        set {
            _source = value;
            load_pixbuf ();
        }
    }

    public Icon (int icon_size, float monitor_scale) {
        Object (icon_size: icon_size, monitor_scale: monitor_scale);
    }

    public Icon.from_resource (int icon_size, float monitor_scale, string resource_path) {
        Object (icon_size: icon_size, monitor_scale: monitor_scale, resource_path: resource_path);
    }

    construct {
        notify["icon-size"].connect (load_pixbuf);
        notify["monitor-scale"].connect (load_pixbuf);
        resource_scale_changed.connect (load_pixbuf);
    }

    private void load_pixbuf () {
        var actor_size = Utils.scale_to_int (icon_size, monitor_scale);
        set_size (actor_size, actor_size);

        var scale = monitor_scale * get_resource_scale ();

        try {
            var pixbuf = get_pixbuf (icon_size, scale);
            content = new Gala.Image.from_pixbuf_with_size (actor_size, actor_size, pixbuf);

            set_background_color (null);
        } catch (Error e) {
            critical ("Could not load icon pixbuf: %s", e.message);
            background_color = { 255, 0, 0, 255 };
        }
    }

    private Gdk.Pixbuf get_pixbuf (int size, float scale) throws Error {
        var cache_key = source.get_cache_key (size, scale);

        if (cache_key == null) {
            return source.create_pixbuf (size, scale);
        }

        if (!(cache_key in icon_pixbufs)) {
            icon_pixbufs[cache_key] = source.create_pixbuf (size, scale);
        }

        return icon_pixbufs[cache_key];
    }
}
