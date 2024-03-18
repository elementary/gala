public class Gala.ModalWindowActor : Clutter.Actor {
    public Meta.Display display { get; construct; }

    private int modal_dialogs = 0;

    public ModalWindowActor (Meta.Display display) {
        Object (display: display);
    }

    construct {
        background_color = Clutter.Color.from_string ("black");
        opacity = 200;
        x = 0;
        y = 0;
        width = 10000;
        height = 10000;
        visible = false;
    }

    public void make_modal (Meta.Window window) {
        modal_dialogs++;
        window.unmanaged.connect (unmake_modal);
        visible = true;

        var actor = (Meta.WindowActor) window.get_compositor_private ();
        if (actor == null) {
            warning ("IS NULL");
        } else {
            warning ("NOT NULL!");
        }
        InternalUtils.clutter_actor_reparent (actor, this);

        check_visible ();
    }

    public void unmake_modal (Meta.Window window) {
        modal_dialogs--;
        window.unmanaged.disconnect (unmake_modal);

        remove_child ((Meta.WindowActor) window.get_compositor_private ());

        check_visible ();
    }

    private void check_visible () {
        visible = modal_dialogs > 0;
    }
}
