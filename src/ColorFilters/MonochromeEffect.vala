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

    /*
     * Used for fading in and out the effect, since you can't add transitions to effects.
     */
    public Clutter.Actor? transition_actor { get; set; default = null; }

    public MonochromeEffect (double strength) {
        Object (
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
            strength: strength
        );

        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/monochrome.vert", GLib.ResourceLookupFlags.NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load monochrome.vert: %s", e.message);
        }
    }
}
