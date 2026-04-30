[DBus (name = "io.elementary.gala.BrightnessManager")]
public class Gala.BrightnessManager : GLib.Object {
    public int brightness {
        get {
            if (backlight == null) {
                return -1;
            }
            int min, max;
            int value;
            backlight.get_brightness_info (out min, out max);
            value = backlight.get_brightness ();
            return ((value - min) * 100) / (max - min);
        }
        set {
            if (brightness == value || backlight == null) {
                return;
            }
            int min, max;
            backlight.get_brightness_info (out min, out max);
            backlight.set_brightness ((int) (value * (max - min) / 100) + min);
        }
    }

    private unowned Meta.MonitorManager monitor_manager;
    private unowned Meta.Backlight? backlight;

    public BrightnessManager (WindowManagerGala wm) {
        monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_available_backlights);
        update_available_backlights ();
    }

    private void update_available_backlights () {
        backlight = null;
        unowned var monitors = monitor_manager.get_monitors ();
        foreach (unowned var monitor in monitors) {
            if (monitor.is_primary () && monitor.is_active ()) {
                backlight = monitor.get_backlight ();
            }
        }
    }
}
