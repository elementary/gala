/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MonochromeEffect : Clutter.ShaderEffect {
    public const string EFFECT_NAME = "monochrome-filter";

    private static string decls = """
        uniform sampler2D tex;
        uniform float STRENGTH;
        uniform bool PAUSE_FOR_SCREENSHOT;

        const mat3 GRAY_MAT = mat3(
            0.2126, 0.2126, 0.2126,
            0.7152, 0.7152, 0.7152,
            0.0722, 0.0722, 0.0722
        );
    """;

    private static string post = """
        vec4 sample = texture2D (tex, cogl_tex_coord0_in.xy);

        if (PAUSE_FOR_SCREENSHOT) {
            cogl_color_out = sample;
            return;
        }

        vec3 grayRGB = GRAY_MAT * sample.rgb;
        vec3 result = mix(sample.rgb, grayRGB, STRENGTH);
        cogl_color_out = vec4(result, sample.a);
    """;


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
#if !HAS_MUTTER51
#if HAS_MUTTER48
            shader_type: Cogl.ShaderType.FRAGMENT,
#else
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
#endif
#endif
            strength: strength
        );
    }

    construct {
#if !HAS_MUTTER51
        set_shader_source (@"$decls \n void main() { $post }");
#endif

        pause_for_screenshot = false;
    }

#if HAS_MUTTER51
    public override Cogl.Snippet get_static_snippet () {
        return new Cogl.Snippet (Cogl.SnippetHook.FRAGMENT, decls, post);
    }
#endif
}
