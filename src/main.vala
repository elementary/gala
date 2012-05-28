[CCode (cname="clutter_x11_handle_event")]
public extern int x_handle_event (X.Event xevent);
[CCode (cname="clutter_x11_get_stage_window")]
public extern X.Window x_get_stage_window (Clutter.Actor stage);

int main (string [] args) {

    OptionContext ctx = Meta.get_option_context ();
    ctx.add_main_entries (Gala.OPTIONS, null);
    try {
        ctx.parse (ref args);
    } catch (Error e) {
        stderr.printf ("Error initializing: %s\n", e.message);
        Meta.exit (Meta.ExitCode.ERROR);
    }

    Meta.Plugin.type_register (new Gala.Plugin ().get_type ());

    /**
     * Prevent Meta.init () from causing gtk to load gail and at-bridge
     * Taken from Gnome-Shell main.c
     */
    GLib.Environment.set_variable ("NO_GAIL", "1", true);
    GLib.Environment.set_variable ("NO_AT_BRIDGE", "1", true);
    Meta.init ();
    GLib.Environment.unset_variable ("NO_GAIL");
    GLib.Environment.unset_variable ("NO_AT_BRIDGE");

    return Meta.run ();
}