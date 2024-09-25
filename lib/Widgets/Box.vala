public class Gala.Widget.Box : Clutter.Actor {
    public uint spacing {
        get {
            return box_layout.spacing;
        }
        set {
            box_layout.spacing = value;
        }
    }

    public Clutter.Orientation orientation {
        get {
            return box_layout.orientation;
        }
        set {
            box_layout.orientation = value;
        }
    }

    private Clutter.BoxLayout box_layout;

    construct {
        layout_manager = box_layout = new Clutter.BoxLayout ();
        clip_to_allocation = false;
    }
}
