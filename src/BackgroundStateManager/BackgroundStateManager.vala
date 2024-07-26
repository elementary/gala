// TODO: Copyright

public enum Gala.BackgroundState {
    LIGHT,
    DARK,
    MAXIMIZED,
    TRANSLUCENT_DARK,
    TRANSLUCENT_LIGHT
}

[DBus (name = "io.elementary.gala.BackgroundStateManager")]
public class Gala.BackgroundStateManager : GLib.Object {
    private static WindowManager wm;
    private static BackgroundStateManager? instance;

    private BackgroundListener background_listener;

    [DBus (visible = false)]
    public static void init (WindowManager wm) {
        BackgroundStateManager.wm = wm;

        Bus.own_name (
            BusType.SESSION,
            "io.elementary.gala.BackgroundStateManager",
            BusNameOwnerFlags.NONE,
            (connection) => {
                if (instance == null) {
                    instance = new BackgroundStateManager ();
                }

                try {
                    connection.register_object ("/io/elementary/gala/BackgroundStateManager", instance);
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => warning ("Could not acquire name")
        );
    }

    public signal void state_changed (BackgroundState state, uint animation_duration); 

    public void initialize (int panel_height) throws GLib.Error {
        background_listener = new BackgroundListener (wm, panel_height);
        background_listener.state_changed.connect ((state, animation_duration) => state_changed (state, animation_duration));
    }
}