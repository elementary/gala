public class RoundedCornerEffect : Clutter.ShaderEffect {
    public const string EFFECT_NAME = "monochrome-filter";

    public MonochromeEffect () {
        Object (
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER
        );
    }

    construct {
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/rounded-corners.vert", GLib.ResourceLookupFlags.NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load monochrome.vert: %s", e.message);
        }
    }
}