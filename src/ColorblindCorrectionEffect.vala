/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindCorrectionEffect : Clutter.ShaderEffect {
    // Taken from https://www.shadertoy.com/view/XslyzX
    private const string SHADER_TEMPLATE = """
        uniform sampler2D tex;
        void main() {
            vec4 c = texture2D(tex, cogl_tex_coord0_in.xy);
            mat3 rgb2lms = mat3(17.8824, 43.5161, 4.11935, 3.45565, 27.1554, 3.86714, 0.0299566, 0.184309, 1.46709);
            // inverse of a matrix calculated in numpy
            mat3 lms2rgb = mat3(8.09444479e-02, -1.30504409e-01,  1.16721066e-01, -1.02485335e-02, 5.40193266e-02, -1.13614708e-01, -3.65296938e-04, -4.12161469e-03, 6.93511405e-01);
            mat3 m[3] = mat3[3](
                mat3(0.0, 2.02344, -2.52581, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0),  // protanopia
                mat3(1.0, 0.0, 0.0, 0.494207, 0.0, 1.24827, 0.0, 0.0, 1.0),  // deuteranopia
                mat3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -0.395913, 0.801109, 0.0) // tritanopia
            );
            vec3 c2 = vec3 (c.r, c.g, c.b);
            c2 *= rgb2lms;
            c2 *= m[%d - 1];
            c2 *= lms2rgb;
            cogl_color_out = vec4( c2.r , c2.g, c2.b, 1.0 );
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
