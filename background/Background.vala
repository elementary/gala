/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.Background.Background : Object, Gdk.Paintable {
    public struct ColorInformation {
        double average_red;
        double average_green;
        double average_blue;
        double mean_luminance;
        double luminance_variance;
        double mean_acutance;
    }

    public static Background get_for_color (Gdk.RGBA color) {
        return new SolidColor (color);
    }

    public static Background? get_for_file (File file) {
        Gdk.Texture texture;
        try {
            texture = Gdk.Texture.from_file (file);
        } catch (Error e) {
            warning ("Failed to load texture: %s", e.message);
            return null;
        }

        return new ImageBackground (texture);
    }

    public static Background get_dimmed (Background other) {
        return new DimBackground (other);
    }

    public abstract ColorInformation? get_color_information (int height);

    private class SolidColor : Object, Gdk.Paintable, Background {
        public Gdk.RGBA color { get; construct; }

        public SolidColor (Gdk.RGBA color) {
            Object (color: color);
        }

        public ColorInformation? get_color_information (int height) {
            var r = color.red * 255;
            var g = color.green * 255;
            var b = color.blue * 255;

            return {r, g, b, (0.3 * r + 0.59 * g + 0.11 * b), 0, 0};
        }

        public void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height) {
            if (!(gdk_snapshot is Gtk.Snapshot)) {
                critical ("No Gtk Snapshot provided can't render solid color");
                return;
            }

            var snapshot = (Gtk.Snapshot) gdk_snapshot;

            var rect = Graphene.Rect ().init (0, 0, (float) width, (float) height);

            snapshot.append_color (color, rect);
        }
    }

    private class DimBackground : Object, Gdk.Paintable, Background {
        public Background texture { get; construct; }

        public DimBackground (Background texture) {
            Object (texture: texture);
        }

        public ColorInformation? get_color_information (int height) {
            var info = texture.get_color_information (height);
            if (info == null) {
                return null;
            }

            info.average_red *= 0.55;
            info.average_green *= 0.55;
            info.average_blue *= 0.55;
            info.mean_luminance *= 0.55;
            info.luminance_variance *= 0.55;

            return info;
        }

        public override double get_intrinsic_aspect_ratio () {
            return texture.get_intrinsic_aspect_ratio ();
        }

        public void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height) {
            if (!(gdk_snapshot is Gtk.Snapshot)) {
                critical ("No Gtk Snapshot provided can't render brightness changed");
                texture.snapshot (gdk_snapshot, width, height);
                return;
            }

            var snapshot = (Gtk.Snapshot) gdk_snapshot;

            float[] matrix_values = {
                0.55f, 0, 0, 0,
                0, 0.55f, 0, 0,
                0, 0, 0.55f, 0,
                0, 0, 0, 1,
            };

            var brightness_matrix = Graphene.Matrix ().init_from_float (matrix_values);

            snapshot.push_color_matrix (brightness_matrix, Graphene.Vec4.zero ());

            texture.snapshot (gdk_snapshot, width, height);

            snapshot.pop ();
        }
    }

    private class ImageBackground : Object, Gdk.Paintable, Background {
        public Gdk.Texture texture { get; construct; }

        public ImageBackground (Gdk.Texture texture) {
            Object (texture: texture);
        }

        public ColorInformation? get_color_information (int height) {
            return Utils.get_background_color_information (texture, height);
        }

        public override double get_intrinsic_aspect_ratio () {
            return texture.get_intrinsic_aspect_ratio ();
        }

        public void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height) {
            texture.snapshot (gdk_snapshot, render_width, render_height);
        }
    }
}
