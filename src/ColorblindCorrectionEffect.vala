/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindCorrectionEffect : Clutter.ShaderEffect {
    // Taken from https://www.shadertoy.com/view/XslyzX
    private const string SHADER_TEMPLATE = """
        uniform sampler2D tex;
        uniform int mode = %d;
        void main() {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec4 sum = texture2D (tex, uv);
            float L = (17.8824 * sum.r) + (43.5161 * sum.g) + (4.11935 * sum.b);
            float M = (3.45565 * sum.r) + (27.1554 * sum.g) + (3.86714 * sum.b);
            float S = (0.0299566 * sum.r) + (0.184309 * sum.g) + (1.46709 * sum.b);
            float l, m, s;
            if (mode == 1) { // Protanopia
                l = 0.0 * L + 2.02344 * M + -2.52581 * S;
                m = 0.0 * L + 1.0 * M + 0.0 * S;
                s = 0.0 * L + 0.0 * M + 1.0 * S;
            }
            
            if (mode == 2) { // Deuteranopia
                l = 1.0 * L + 0.0 * M + 0.0 * S;
                m = 0.494207 * L + 0.0 * M + 1.24827 * S;
                s = 0.0 * L + 0.0 * M + 1.0 * S;
            }
            
            if (mode == 3) { // Tritanopia
                l = 1.0 * L + 0.0 * M + 0.0 * S;
                m = 0.0 * L + 1.0 * M + 0.0 * S;
                s = -0.395913 * L + 0.801109 * M + 0.0 * S;
            }
            
            vec4 error;
            error.r = (0.0809444479 * l) + (-0.130504409 * m) + (0.116721066 * s);
            error.g = (-0.0102485335 * l) + (0.0540193266 * m) + (-0.113614708 * s);
            error.b = (-0.000365296938 * l) + (-0.00412161469 * m) + (0.693511405 * s);
            error.a = 1.0;
            vec4 diff = sum - error;
            vec4 correction;
            correction.r = 0.0;
            correction.g =  (diff.r * 0.7) + (diff.g * 1.0);
            correction.b =  (diff.r * 0.7) + (diff.b * 1.0);
            correction = sum + correction;
            
            cogl_color_out = correction;
        }
    """;

    // https://www.reddit.com/r/gamemaker/comments/11us4t4/accurate_monochrome_glsl_shader_tutorial/
    private const string MONOCHROME_SHADER = """
        uniform sampler2D tex;
        void main() {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec4 sample = texture2D (tex, uv);
            vec3 luminance = vec3 (0.2126, 0.7512, 0.0722);
            float gray = luminance.r * sample.r + luminance.g * sample.g + luminance.b * sample.b;
            cogl_color_out = vec4 (gray, gray, gray, sample.a);
        }
    """;

    public int mode { get; construct; }

    public ColorblindCorrectionEffect (int mode) {
        Object (mode: mode);
    }

    construct {
        string shader;
        switch (mode) {
            case 1:
            case 2:
            case 3:
                shader = SHADER_TEMPLATE.printf (mode);
                break;
            case 4:
                shader = MONOCHROME_SHADER;
                break;
            default:
                assert_not_reached ();
                break;
        }

        set_shader_source (SHADER_TEMPLATE.printf(mode));
    }
}
