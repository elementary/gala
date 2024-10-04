/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala.Background.Utils {
    public enum ColorScheme {
        NO_PREFERENCE,
        DARK,
        LIGHT
    }

    public delegate void OnStyleChange (ColorScheme new_style);

    [DBus (name = "org.freedesktop.Accounts")]
    private interface Accounts : Object {
        public abstract string find_user_by_name (string name) throws IOError, DBusError;
    }

    [DBus (name = "io.elementary.pantheon.AccountsService")]
    private interface AccountsService : DBusProxy {
        public abstract int prefers_color_scheme { get; set; }
    }

    private const string FDO_ACCOUNTS_NAME = "org.freedesktop.Accounts";
    private const string FDO_ACCOUNTS_PATH = "/org/freedesktop/Accounts";

    private static AccountsService? accounts_service_proxy;

    public static void init_color_scheme_watcher (OnStyleChange style_change_callback) {
        try {
            var accounts = Bus.get_proxy_sync<Accounts> (SYSTEM, FDO_ACCOUNTS_NAME, FDO_ACCOUNTS_PATH);

            var path = accounts.find_user_by_name (Environment.get_user_name ());

            accounts_service_proxy = Bus.get_proxy_sync<AccountsService> (SYSTEM, FDO_ACCOUNTS_NAME, path, GET_INVALIDATED_PROPERTIES);
        } catch {
            warning ("Could not connect to AccountsService. Default style will be used");
            return;
        }

        style_change_callback (accounts_service_proxy.prefers_color_scheme);

        accounts_service_proxy.g_properties_changed.connect ((changed, invalid) => {
            var value = changed.lookup_value ("PrefersColorScheme", new VariantType ("i"));
            if (value != null) {
                style_change_callback (value.get_int32 ());
            }
        });
    }

    private const double SATURATION_WEIGHT = 1.5;
    private const double WEIGHT_THRESHOLD = 1.0;

    public static Background.ColorInformation? get_background_color_information (Gdk.Texture texture, int panel_height) {
        int width = texture.width;
        int height = int.min (texture.height, panel_height);

        if (width <= 0 || height <= 0) {
            warning ("Got invalid rectangle: %i, %i".printf (width, height));
            return null;
        }

        double mean_acutance, variance, mean, r_total, g_total, b_total = 0;

        var texture_width = texture.width;
        var texture_height = texture.height;

        var pixels = new uint8[texture_width * texture_height * 4];
        var pixel_lums = new double[texture_width * texture_height];

        texture.download (pixels, texture_width * 4);

        int size = width * height;

        double mean_squares = 0;
        double pixel = 0;

        double max, min, score, delta, score_total = 0, r_total2 = 0, g_total2 = 0, b_total2 = 0;

        /*
         * code to calculate weighted average color is copied from
         * plank's lib/Drawing/DrawingService.vala average_color()
         * http://bazaar.launchpad.net/~docky-core/plank/trunk/view/head:/lib/Drawing/DrawingService.vala
         */
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int i = (y * (int)texture_width * 4) + (x * 4);

                uint8 r = pixels[i + 1];
                uint8 g = pixels[i + 2];
                uint8 b = pixels[i + 3];

                pixel = (0.3 * r + 0.59 * g + 0.11 * b) ;

                pixel_lums[y * width + x] = pixel;

                min = uint8.min (r, uint8.min (g, b));
                max = uint8.max (r, uint8.max (g, b));

                delta = max - min;

                /* prefer colored pixels over shades of grey */
                score = SATURATION_WEIGHT * (delta == 0 ? 0.0 : delta / max);

                r_total += score * r;
                g_total += score * g;
                b_total += score * b;
                score_total += score;

                r_total += r;
                g_total += g;
                b_total += b;

                mean += pixel;
                mean_squares += pixel * pixel;
            }
        }

        for (int y = 1; y < height - 1; y++) {
            for (int x = 1; x < width - 1; x++) {
                var acutance =
                    (pixel_lums[y * width + x] * 4) -
                    (
                        pixel_lums[y * width + x - 1] +
                        pixel_lums[y * width + x + 1] +
                        pixel_lums[(y - 1) * width + x] +
                        pixel_lums[(y + 1) * width + x]
                    );

                mean_acutance += acutance > 0 ? acutance : -acutance;
            }
        }

        score_total /= size;
        b_total /= size;
        g_total /= size;
        r_total /= size;

        if (score_total > 0.0) {
            b_total /= score_total;
            g_total /= score_total;
            r_total /= score_total;
        }

        b_total2 /= size * uint8.MAX;
        g_total2 /= size * uint8.MAX;
        r_total2 /= size * uint8.MAX;

        /*
         * combine weighted and not weighted sum depending on the average "saturation"
         * if saturation isn't reasonable enough
         * s = 0.0 -> f = 0.0 ; s = WEIGHT_THRESHOLD -> f = 1.0
         */
        if (score_total <= WEIGHT_THRESHOLD) {
            var f = 1.0 / WEIGHT_THRESHOLD * score_total;
            var rf = 1.0 - f;

            b_total = b_total * f + b_total2 * rf;
            g_total = g_total * f + g_total2 * rf;
            r_total = r_total * f + r_total2 * rf;
        }

        /* there shouldn't be values larger then 1.0 */
        var max_val = double.max (r_total, double.max (g_total, b_total));

        if (max_val > 1.0) {
            b_total /= max_val;
            g_total /= max_val;
            r_total /= max_val;
        }

        mean /= size;
        mean_squares = mean_squares / size;

        variance = (mean_squares - (mean * mean));

        mean_acutance /= (width - 2) * (height - 2);

        return { r_total, g_total, b_total, mean, variance, mean_acutance };
    }
}
