/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 public class Gala.MonochromeEffect : Clutter.ShaderEffect {
    public const string EFFECT_NAME = "monochrome-filter";

    // https://www.reddit.com/r/gamemaker/comments/11us4t4/accurate_monochrome_glsl_shader_tutorial/
    private const string SHADER = """
        uniform sampler2D tex;
        uniform float STRENGTH;
        void main() {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec4 sample = texture2D (tex, uv);
            vec3 luminance = vec3 (0.2126, 0.7512, 0.0722);
            float gray = luminance.r * sample.r + luminance.g * sample.g + luminance.b * sample.b;
            cogl_color_out = vec4 (
                sample.r * (1.0 - STRENGTH) + gray * STRENGTH,
                sample.g * (1.0 - STRENGTH) + gray * STRENGTH,
                sample.b * (1.0 - STRENGTH) + gray * STRENGTH,
                1.0
            ) ;
        }
    """;

    private double _strength;
    public double strength {
        get { return _strength; }
        construct set {
            set_uniform_value ("STRENGTH", value);
            _strength = value;
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

        set_shader_source (SHADER);
    }
}
