/*
 * Copyright 2023-2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MonochromeEffect : SimpleShaderEffect {
    public const string EFFECT_NAME = "monochrome-filter";

    private double _strength;
    public double strength {
        get { return _strength; }
        set {
            _strength = value;
            set_uniform_1f ("STRENGTH", (float) value);
            queue_repaint ();
        }
    }
    public bool pause_for_screenshot {
        set {
            set_uniform_1i ("PAUSE_FOR_SCREENSHOT", (int) value);
            queue_repaint ();
        }
    }

    /*
     * Used for fading in and out the effect, since you can't add transitions to effects.
     */
    public Clutter.Actor? transition_actor { get; set; default = null; }

    public MonochromeEffect (double strength) {
        string shader_source;
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/monochrome.frag", NONE);
            shader_source = (string) bytes.get_data ();
        } catch (Error e) {
            warning ("Unable to load monochrome.frag: %s", e.message);
            shader_source = FALLBACK_SHADER;
        }

        base (shader_source);
        this.strength = strength;
        pause_for_screenshot = false;
    }
}
