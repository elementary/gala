[CCode (cprefix = "AtkBridge", lower_case_cprefix = "atk_bridge_")]
namespace AtkBridge {
	public static int adaptor_init (int argc, char[] argv);
    public static void adaptor_cleanup ();
    public static void set_event_context (GLib.MainContext cnx);
}
