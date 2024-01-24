public class Gala.Window : Gtk.Window {
    public Gtk.Box content;
    public Window (int width, int height) {
        Object (
            default_width: width,
            default_height: height
        );
    }

    construct {
        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;

        bool first = true;
        //  button_press_event.connect (() => {
        //      if (first) {
        //          first = false;
        //          return Gdk.EVENT_PROPAGATE;
        //      }
        //      close ();
        //      return Gdk.EVENT_STOP;
        //  });

        child = content = new Gtk.Box (HORIZONTAL, 0);

        Timeout.add_seconds (5, () => {
            close ();
            return Source.REMOVE;
        });
        //  move (-1000, 0);
    }
}