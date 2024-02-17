/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Drawing.ColorManager : Object {
    private static GLib.Once<ColorManager> instance;
    public static ColorManager get_instance () {
        return instance.once (() => {return new ColorManager ();});
    }


    [DBus (name="org.freedesktop.portal.Settings")]
    private interface SettingsPortal : Object {
        public signal void setting_changed (string @namespace, string key, Variant val);
        public abstract async Variant read (string @namespace, string key) throws IOError, DBusError;
    }

    private const double ACCENT_COLOR_ALPHA = 0.25;
    private const Gdk.RGBA DEFAULT_ACCENT_COLOR = { 0, 0, 0, ACCENT_COLOR_ALPHA };

    public Gdk.RGBA theme_accent_color { get; private set; default = DEFAULT_ACCENT_COLOR; }

    private SettingsPortal? settings_portal_proxy;

    construct {
        Bus.watch_name (SESSION, "org.freedesktop.portal.Desktop", NONE, () => portal_appeared.begin (), () => settings_portal_proxy = null);
    }

    private async void portal_appeared () {
        try {
            settings_portal_proxy = yield Bus.get_proxy<SettingsPortal> (SESSION, "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop", 0, null);
        } catch (Error e) {
            warning ("Failed to get portal proxy: %s", e.message);
            return;
        }

        try {
            var variant = yield settings_portal_proxy.read ("org.freedesktop.appearance", "accent-color");

            //For some reason when reading the variant we need it is itself packed into a variant
            GLib.Variant color;
            variant.get ("v", out color);
            update_color (color);

            settings_portal_proxy.setting_changed.connect ((@namespace, key, val) => {
                if (@namespace == "org.freedesktop.appearance" && key == "accent-color") {
                    update_color (val);
                }
            });
        } catch (Error e) {
            warning ("Failed to read color key: %s", e.message);
        }
    }

    private void update_color (GLib.Variant color) {
        double red, green, blue;
        color.get ("(ddd)", out red, out green, out blue);

        theme_accent_color = {
            red,
            green,
            blue,
            ACCENT_COLOR_ALPHA
        };
    }
}
