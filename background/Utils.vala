namespace Gala.Background.Utils {
    private const double SATURATION_WEIGHT = 1.5;
    private const double WEIGHT_THRESHOLD = 1.0;

    public struct ColorInformation {
        double average_red;
        double average_green;
        double average_blue;
        double mean_luminance;
        double luminance_variance;
        double mean_acutance;
    }

    public static ColorInformation? get_background_color_information (Gdk.Texture texture, int panel_height) {
        int x_start = 0;
        int y_start = 0;

        int width = texture.width;
        int height = int.min (texture.height, panel_height);

        if (width <= 0 || height <= 0) {
            warning ("Got invalid rectangle: %i, %i, %i, %i".printf (x_start, y_start, width, height));
            return null;
        }

        double mean_acutance = 0, variance = 0, mean = 0, r_total = 0, g_total = 0, b_total = 0;

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
        for (int y = y_start; y < (y_start + height); y++) {
            for (int x = x_start; x < (x_start + width); x++) {
                int i = (y * (int)texture_width * 4) + (x * 4);

                uint8 b = pixels[i];
                uint8 g = pixels[i + 1];
                uint8 r = pixels[i + 2];

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

        for (int y = y_start + 1; y < (y_start + height) - 1; y++) {
            for (int x = x_start + 1; x < (x_start + width) - 1; x++) {
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
