/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindnessEffect : Clutter.ShaderEffect {
    // Taken from https://godotshaders.com/shader/colorblindness-correction-shader/
    private const string SHADER_TEMPLATE = """
        uniform sampler2D tex;

        // Color correction mode
        // 1 - Protanopia
        // 2 - Deutranopia
        // 3 - Tritanopia

        uniform int mode = %d;

        uniform float intensity = 1.0;

        void main() {
            vec2 uv = cogl_tex_coord0_in.xy;

            vec4 sum = texture2D (tex, uv);

            float L = (17.8824 * sum.r) + (43.5161 * sum.g) + (4.11935 * sum.b);
            float M = (3.45565 * sum.r) + (27.1554 * sum.g) + (3.86714 * sum.b);
            float S = (0.0299566 * sum.r) + (0.184309 * sum.g) + (1.46709 * sum.b);

            float l, m, s;
            if (mode == 1) //Protanopia
            {
                l = 0.0 * L + 2.02344 * M + -2.52581 * S;
                m = 0.0 * L + 1.0 * M + 0.0 * S;
                s = 0.0 * L + 0.0 * M + 1.0 * S;
            }
            
            if (mode == 2) //Deuteranopia
            {
                l = 1.0 * L + 0.0 * M + 0.0 * S;
                m = 0.494207 * L + 0.0 * M + 1.24827 * S;
                s = 0.0 * L + 0.0 * M + 1.0 * S;
            }
            
            if (mode == 3) //Tritanopia
            {
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
            correction.a = sum.a * intensity;
            
            cogl_color_out = correction;
        }
    """;

    public int mode { get; construct; }

    public ColorblindnessEffect (int mode) {
        Object (mode: mode);
    }

    construct {
        var shader = SHADER_TEMPLATE.printf (mode);
        set_shader_source (shader);
    }
}
