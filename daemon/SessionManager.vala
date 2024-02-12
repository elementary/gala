

[DBus (name = "org.gnome.SessionManager.EndSessionDialog")]
public class Gala.Daemon.SessionManager : Object {
    public signal void confirmed_logout ();
    public signal void confirmed_reboot ();
    public signal void confirmed_shutdown ();
    public signal void canceled ();
    public signal void closed ();

    public void open (uint type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError {
        var window = new Window (10000, 10000, false);
        window.get_style_context ().add_class ("black-background");
        window.opacity = 0.6;
        window.present_with_time (timestamp);
        var dia = new EndSessionDialog ((EndSessionDialogType) type);
        dia.show_all ();
        dia.present_with_time (timestamp);
        dia.destroy.connect (() => {
            window.close ();
        });
    }
}
