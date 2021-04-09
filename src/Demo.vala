class Gala.Demo : GLib.Application {
    private AccentColorManager accent_color_manager;

    private Demo () {
        Object (
            application_id: "io.elementary.gala.demo"
        );
    }

    public override void activate () {
        accent_color_manager = new AccentColorManager ();

        hold ();
    }

    public static int main (string[] args) {
        var demo = new Demo ();
        return demo.run (args);
    }
}