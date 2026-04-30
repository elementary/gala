/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Drawing.StyleManager : Object {
    private const string DBUS_DESKTOP_NAME = "org.freedesktop.portal.Desktop";
    private const string DBUS_DESKTOP_PATH = "/org/freedesktop/portal/desktop";

    public enum ColorScheme {
        NO_PREFERENCE,
        DARK,
        LIGHT
    }

    [DBus (name = "org.freedesktop.portal.Settings")]
    private interface SettingsPortal : Object {
        public abstract HashTable<string, HashTable<string, Variant>> read_all (string[] namespaces) throws DBusError, IOError;
        public abstract Variant read (string namespace, string key) throws DBusError, IOError;

        public signal void setting_changed (string namespace, string key, Variant value);
    }

    private const uint8 ACCENT_COLOR_ALPHA = 64;

    private static GLib.Once<StyleManager> instance;
    public static unowned StyleManager get_instance () {
        return instance.once (() => new StyleManager ());
    }

    public ColorScheme prefers_color_scheme { get; private set; default = LIGHT; }
#if !HAS_MUTTER47
    public Clutter.Color theme_accent_color { get; private set; default = Clutter.Color.from_string ("#3689e6"); }
#else
    public Cogl.Color theme_accent_color { get; private set; default = Cogl.Color.from_string ("#3689e6"); }
#endif

    private SettingsPortal? settings_portal = null;

    construct {
        Bus.watch_name (
            SESSION, DBUS_DESKTOP_NAME, NONE,
            () => connect_to_settings_portal.begin (),
            () => settings_portal = null
        );
    }

    private async void connect_to_settings_portal () {
        try {
            settings_portal = yield Bus.get_proxy<SettingsPortal> (SESSION, DBUS_DESKTOP_NAME, DBUS_DESKTOP_PATH);
        } catch {
            warning ("Could not connect to settings portal. Default accent color will be used");
            return;
        }

        try {
            update_color_scheme (settings_portal.read ("org.freedesktop.appearance", "color-scheme").get_uint32 ());
            update_color (settings_portal.read ("org.freedesktop.appearance", "accent-color").get_variant ());
        } catch (Error e) {
            warning (e.message);
        }

        settings_portal.setting_changed.connect ((scheme, key, variant) => {
            if (scheme != "org.freedesktop.appearance") {
                return;
            }

            switch (key) {
                case "color-scheme":
                    update_color_scheme (variant.get_uint32 ());
                    break;
                case "accent-color":
                    update_color (variant);
                    break;
            }
        });
    }

    private void update_color_scheme (uint32 color_scheme) {
        prefers_color_scheme = (ColorScheme) color_scheme;
    }

    private void update_color (Variant color) {
        double r, g, b;
        color.get ("(ddd)", out r, out g, out b);

        theme_accent_color = { (uint8) (r * 255), (uint8) (g * 255), (uint8) (b * 255), ACCENT_COLOR_ALPHA };
    }
}
