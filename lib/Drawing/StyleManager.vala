/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Drawing.StyleManager : Object {
    public enum ColorScheme {
        NO_PREFERENCE,
        DARK,
        LIGHT
    }

    public enum ReducedMotion {
        NO_PREFERENCE,
        REDUCE,
    }

    [DBus (name="org.freedesktop.Accounts")]
    private interface Accounts : Object {
        public abstract async string find_user_by_name (string name) throws IOError, DBusError;
    }

    [DBus (name="io.elementary.pantheon.AccountsService")]
    private interface PantheonAccountsService : DBusProxy {
        public abstract int prefers_color_scheme { get; set; }
        public abstract int prefers_accent_color { get; set; }
    }

    [DBus (name="io.elementary.SettingsDaemon.AccountsService")]
    private interface SettingsDaemonAccountsService : DBusProxy {
        public abstract int accent_color { get; set; }
    }

    [DBus (name = "org.freedesktop.portal.Settings")]
    interface Portal : Object {
        public signal void setting_changed (string namespace, string key, Variant value);
        public abstract async Variant read_one (string namespace, string key) throws DBusError, IOError;
    }

    private const string FDO_ACCOUNTS_NAME = "org.freedesktop.Accounts";
    private const string FDO_ACCOUNTS_PATH = "/org/freedesktop/Accounts";
    private const string PORTAL_NAME = "org.freedesktop.portal.Desktop";
    private const string PORTAL_PATH = "/org/freedesktop/portal/desktop";
    private const uint8 ACCENT_COLOR_ALPHA = 64;

    private static GLib.Once<StyleManager> instance;
    public static unowned StyleManager get_instance () {
        return instance.once (() => new StyleManager ());
    }

    public ColorScheme prefers_color_scheme { get; private set; default = LIGHT; }
#if !HAS_MUTTER47
    public Clutter.Color theme_accent_color { get; private set; default = { 0, 0, 0, ACCENT_COLOR_ALPHA }; }
#else
    public Cogl.Color theme_accent_color { get; private set; default = { 0, 0, 0, ACCENT_COLOR_ALPHA }; }
#endif
    public ReducedMotion reduced_motion { get; private set; default = NO_PREFERENCE; }

    private PantheonAccountsService? pantheon_proxy;
    private SettingsDaemonAccountsService? settings_daemon_proxy;
    private Portal? portal_proxy;

    construct {
        Bus.watch_name (
            SYSTEM, FDO_ACCOUNTS_NAME, NONE,
            () => connect_to_accounts_service.begin (),
            () => {
                pantheon_proxy = null;
                settings_daemon_proxy = null;
            }
        );

        Bus.watch_name (
            SESSION, PORTAL_NAME, NONE,
            () => on_portal_appeared.begin (),
            () => portal_proxy = null
        );
    }

    private async void connect_to_accounts_service () {
        try {
            var accounts = yield Bus.get_proxy<Accounts> (SYSTEM, FDO_ACCOUNTS_NAME, FDO_ACCOUNTS_PATH);

            var path = yield accounts.find_user_by_name (Environment.get_user_name ());

            pantheon_proxy = yield Bus.get_proxy<PantheonAccountsService> (SYSTEM, FDO_ACCOUNTS_NAME, path, GET_INVALIDATED_PROPERTIES);
            settings_daemon_proxy = yield Bus.get_proxy<SettingsDaemonAccountsService> (SYSTEM, FDO_ACCOUNTS_NAME, path, GET_INVALIDATED_PROPERTIES);
        } catch {
            warning ("Could not connect to AccountsService. Default accent color will be used");
            return;
        }

        update_color_scheme (pantheon_proxy.prefers_color_scheme);
        update_color (settings_daemon_proxy.accent_color);

        pantheon_proxy.g_properties_changed.connect ((changed, invalid) => {
            var value = changed.lookup_value ("PrefersColorScheme", new VariantType ("i"));
            if (value != null) {
                update_color_scheme (value.get_int32 ());
            }
        });

        settings_daemon_proxy.g_properties_changed.connect ((changed, invalid) => {
            var value = changed.lookup_value ("AccentColor", new VariantType ("i"));
            if (value != null) {
                update_color (value.get_int32 ());
            }
        });
    }

    private void update_color_scheme (int color_scheme) {
        prefers_color_scheme = (ColorScheme) color_scheme;
    }

    private void update_color (int color) {
        var rgb = get_color (color);

        var r = (uint8) ((rgb >> 16) & 255);
        var g = (uint8) ((rgb >> 8) & 255);
        var b = (uint8) (rgb & 255);

        theme_accent_color = { r, g, b, ACCENT_COLOR_ALPHA };
    }

    private int get_color (int color) {
        switch (color) {
            case 1: // Strawberry
                return 0xed5353;

            case 2: // Orange
                return 0xffa154;

            case 3: // Banana
                return 0xf9c440;

            case 4: // Lime
                return 0x68b723;

            case 5: // Mint
                return 0x28bca3;

            case 6: // Blueberry
                return 0x3689e6;

            case 7: // Grape
                return 0xa56de2;

            case 8: // Bubblegum
                return 0xde3e80;

            case 9: // Cocoa
                return 0x8a715e;

            case 10: // Slate
                return 0x667885;

            case 11: // Latte
                return 0xe7c591;
        }

        return 0;
    }

    private async void on_portal_appeared () {
        try {
            portal_proxy = yield Bus.get_proxy<Portal> (SESSION, PORTAL_NAME, PORTAL_PATH);
        } catch (Error e) {
            warning ("Could not connect to portal: %s", e.message);
            return;
        }

        portal_proxy.setting_changed.connect (on_setting_changed);

        try {
            var variant = yield portal_proxy.read_one ("org.freedesktop.appearance", "reduced-motion");
            reduced_motion = (ReducedMotion) variant.get_uint32 ();
        } catch (Error e) {
            warning ("Could not read reduced-motion setting from portal: %s", e.message);
        }
    }

    private void on_setting_changed (string namespace, string key, Variant value) {
        if (namespace != "org.freedesktop.appearance") {
            return;
        }

        switch (key) {
            case "reduced-motion":
                reduced_motion = (ReducedMotion) value.get_uint32 ();
                break;

            default:
                break;
        }
    }
}
