

class Gala.AliveChecker : Object {
    private const string CHECK_ALIVE_TIMEOUT = "check-alive-timeout";
    private const uint TIMEOUT_MSEC = 50;

    public Meta.Display display { private get; construct; }
    private Settings mutter_settings;

    public AliveChecker (Meta.Display display) {
        Object (display: display);
    }

    construct {
        mutter_settings = new Settings ("org.gnome.mutter");
        disable_automatic_check ();

        display.notify["focus-window"].connect (focus_window_changed);
    }

    private void focus_window_changed () {
        if (display.focus_window != null) {
            mutter_settings.set_uint (CHECK_ALIVE_TIMEOUT, TIMEOUT_MSEC); // quickly check if app is responding
            display.focus_window.check_alive (Meta.CURRENT_TIME);
            Timeout.add_once (TIMEOUT_MSEC, disable_automatic_check); // and disable automatic check again
        }
    }

    private void disable_automatic_check () {
        mutter_settings.set_uint (CHECK_ALIVE_TIMEOUT, 0);
    }
}
