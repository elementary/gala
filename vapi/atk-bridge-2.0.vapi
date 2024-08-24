[CCode (cheader_filename = "atk-bridge.h", lower_case_cprefix = "atk_bridge_")]
namespace AtkBridge {
    public static int adaptor_init ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
    public static void adaptor_cleanup ();
    public static void set_event_context (GLib.MainContext cnx);
}
