/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MonochromeEffect : Clutter.ShaderEffect {
    public const string EFFECT_NAME = "monochrome-filter";

    private double _strength;
    public double strength {
        get { return _strength; }
        construct set {
            _strength = value;
            set_uniform_value ("STRENGTH", value);
            queue_repaint ();
        }
    }
    public bool pause_for_screenshot {
        set {
            set_uniform_value ("PAUSE_FOR_SCREENSHOT", (int) value);
            queue_repaint ();
        }
    }

    /*
     * Used for fading in and out the effect, since you can't add transitions to effects.
     */
    public Clutter.Actor? transition_actor { get; set; default = null; }

    public MonochromeEffect (double strength) {
        Object (
#if HAS_MUTTER48
            shader_type: Cogl.ShaderType.FRAGMENT,
#else
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
#endif
            strength: strength
        );

        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/monochrome.vert", GLib.ResourceLookupFlags.NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load monochrome.vert: %s", e.message);
        }

        pause_for_screenshot = false;
    }
}
