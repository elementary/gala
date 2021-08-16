/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Gala.MixedDpiManager : Object {
    public WindowManager wm { get; construct; }

    public MixedDpiManager (WindowManager wm) {
        Object (wm: wm);

        unowned Meta.MonitorManager monitor_manager = Meta.MonitorManager.@get ();
        monitor_manager.monitors_changed.connect (adjust_mixed_dpi);
    }

    public void adjust_mixed_dpi () {
        var scales = new HashTable<int, Variant> (direct_hash, direct_equal);
        double lower_scale = -1;

        unowned Meta.Display display = wm.get_display ();
        int n_monitors = display.get_n_monitors ();

        for (int n = 0; n < n_monitors; n++) {
            double scale = get_dpi_scale (n);
            scales.insert (n, new Variant.double (scale));
            if (scale >= 1 && (lower_scale < 1 || scale < lower_scale)) {
                lower_scale = scale;
            }
        }

        if (lower_scale < 1) {
            debug ("All monitors are configured with DPI < 1, exit");
            return;
        }

        debug ("Adjusting to the lower scale '%f'", lower_scale);
        for (int n = 0; n < n_monitors; n++) {
            double scale = scales[n].get_double ();

            if (scale == lower_scale) {
                debug ("Monitor %d is already in the target resolution", n);
            } else {
                Meta.Rectangle geometry = display.get_monitor_geometry (n);
                int width = get_target_resolution (scale, lower_scale, geometry.width);
                int height = get_target_resolution (scale, lower_scale, geometry.height);
                debug ("Monitor %d ideal target resolution: %d x %d", n, width, height);
            }
        }
    }

    private static double get_dpi_scale (int monitor_index) {
        // 2 to allow 0.5, 4 to allow 0.25, 0.5 and 0.75, etc
        const int INTERMEDIATE_VALUES = 2;

        unowned Gdk.Display display = Gdk.Display.get_default ();
        unowned Gdk.Monitor monitor = display.get_monitor (monitor_index);

        Gdk.Rectangle geometry = monitor.get_geometry ();
        var inches = mm_to_inches (monitor.width_mm);
        var dpi = geometry.width / inches;
        var scale = Math.round ((dpi / 100) * INTERMEDIATE_VALUES) / INTERMEDIATE_VALUES;
        debug ("Monitor %d (%s) has a DPI scale of '%f'", monitor_index, monitor.manufacturer, scale);
        return scale;
    }

    private static double mm_to_inches (int mm) {
        return mm / 25.4;
    }

    private static int get_target_resolution (double scale, double target_scale, int dim) {
        return (int) ((dim * target_scale) / scale);
    }
}
