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

    [DBus (name="org.freedesktop.Accounts")]
    private interface Accounts : Object {
        public abstract async string find_user_by_name (string name) throws IOError, DBusError;
    }

    [DBus (name="io.elementary.pantheon.AccountsService")]
    private interface AccountsService : DBusProxy {
        public abstract int prefers_color_scheme { get; set; }
        public abstract int prefers_accent_color { get; set; }
    }

    private const string FDO_ACCOUNTS_NAME = "org.freedesktop.Accounts";
    private const string FDO_ACCOUNTS_PATH = "/org/freedesktop/Accounts";

    private const double ACCENT_COLOR_ALPHA = 0.25;
    private const Gdk.RGBA DEFAULT_ACCENT_COLOR = { 0, 0, 0, ACCENT_COLOR_ALPHA };

    private static GLib.Once<StyleManager> instance;
    public static StyleManager get_instance () {
        return instance.once (() => {return new StyleManager ();});
    }

    public ColorScheme prefers_color_scheme { get; private set; default = LIGHT; }
    public Gdk.RGBA theme_accent_color { get; private set; default = DEFAULT_ACCENT_COLOR; }

    private AccountsService? accounts_service_proxy;

    construct {
        Bus.watch_name (SYSTEM, FDO_ACCOUNTS_NAME, NONE, () => connect_to_accounts_service.begin (), () => accounts_service_proxy = null);
    }

    private async void connect_to_accounts_service () {
        try {
            var accounts = yield Bus.get_proxy<Accounts> (SYSTEM, FDO_ACCOUNTS_NAME, FDO_ACCOUNTS_PATH);

            var path = yield accounts.find_user_by_name (Environment.get_user_name ());

            accounts_service_proxy = yield Bus.get_proxy<AccountsService> (SYSTEM, FDO_ACCOUNTS_NAME, path, GET_INVALIDATED_PROPERTIES);
        } catch {
            warning ("Could not connect to AccountsService. Default accent color will be used");
            return;
        }

        update_color_scheme (accounts_service_proxy.prefers_color_scheme);
        update_color (accounts_service_proxy.prefers_accent_color);

        accounts_service_proxy.g_properties_changed.connect ((changed, invalid) => {
            var value = changed.lookup_value ("PrefersAccentColor", new VariantType ("i"));
            if (value != null) {
                update_color (value.get_int32 ());
            }

            value = changed.lookup_value ("PrefersColorScheme", new VariantType ("i"));
            if (value != null) {
                update_color_scheme (value.get_int32 ());
            }
        });
    }

    private void update_color_scheme (int color_scheme) {
        prefers_color_scheme = (ColorScheme) color_scheme;
    }

    private void update_color (int color) {
        var rgb = get_color (color);

        double r = ((rgb >> 16) & 255) / 255.0;
        double g = ((rgb >> 8) & 255) / 255.0;
        double b = (rgb & 255) / 255.0;

        theme_accent_color = {
            r,
            g,
            b,
            ACCENT_COLOR_ALPHA
        };
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
        }

        return 0;
    }
}
