/*
 * Copyright 2023-2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindnessCorrectionEffect : SimpleShaderEffect {
    public const string EFFECT_NAME = "colorblindness-correction-filter";

    private int _mode;
    public int mode {
        get { return _mode; }
        construct set {
            _mode = value;
            set_uniform_1i ("COLORBLIND_MODE", _mode);
        }
    }
    private double _strength;
    public double strength {
        get { return _strength; }
        construct set {
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

    public ColorblindnessCorrectionEffect (int mode, double strength) {
        string shader_source;
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/colorblindness-correction.frag", GLib.ResourceLookupFlags.NONE);
            shader_source = (string) bytes.get_data ();
        } catch (Error e) {
            warning ("Unable to load colorblindness-correction.frag: %s", e.message);
            shader_source = FALLBACK_SHADER;
        }

        base (shader_source);
        this.mode = mode;
        this.strength = strength;
        pause_for_screenshot = false;
    }
}
