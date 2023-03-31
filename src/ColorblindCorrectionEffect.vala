/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindCorrectionEffect : Clutter.ShaderEffect {
    // Big thank you to https://github.com/G-dH/gnome-colorblind-filters
    private const string SHADER_TEMPLATE = """
    uniform sampler2D tex;
    uniform int COLORBLIND_MODE = %d;
    uniform float STRENGTH = %f;
    void main() {
        vec4 c = texture2D(tex, cogl_tex_coord0_in.xy);

        // RGB to LMS matrix
        float L = (17.8824f * c.r) + (43.5161f * c.g) + (4.11935f * c.b);
        float M = (3.45565f * c.r) + (27.1554f * c.g) + (3.86714f * c.b);
        float S = (0.0299566f * c.r) + (0.184309f * c.g) + (1.46709f * c.b);
        
        float l, m, s;

        // Remove invisible colors
        if ( COLORBLIND_MODE == 1 || COLORBLIND_MODE == 2) { // Protanopia - reds are greatly reduced
            l = 0.0f * L + 2.02344f * M + -2.52581f * S;
            m = 0.0f * L + 1.0f * M + 0.0f * S;
            s = 0.0f * L + 0.0f * M + 1.0f * S;
        } else if ( COLORBLIND_MODE == 3 || COLORBLIND_MODE == 4 || COLORBLIND_MODE == 6) { // Deuteranopia - greens are greatly reduced
            l = 1.0f * L + 0.0f * M + 0.0f * S;
            m = 0.494207f * L + 0.0f * M + 1.24827f * S;
            s = 0.0f * L + 0.0f * M + 1.0f * S;
        } else if ( COLORBLIND_MODE == 5 ) { // Tritanopia - blues are greatly reduced (1 of 10 000)
            l = 1.0f * L + 0.0f * M + 0.0f * S;
            m = 0.0f * L + 1.0f * M + 0.0f * S;
            // GdH - trinatopia vector calculated by me, all public sources were off
            s = -0.012491378299329402f * L + 0.07203451899279534f * M + 0.0f * S;
        }

        // LMS to RGB matrix conversion
        vec4 error;
        error.r = (0.0809444479f * l) + (-0.130504409f * m) + (0.116721066f * s);
        error.g = (-0.0102485335f * l) + (0.0540193266f * m) + (-0.113614708f * s);
        error.b = (-0.000365296938f * l) + (-0.00412161469f * m) + (0.693511405f * s);
        // The error is what they see

        // ratio between original and error colors allows adjusting filter for weaker forms of dichromacy
        error = error * STRENGTH + c * (1.0 - STRENGTH);
        error.a = 1.0;

        // Isolate invisible colors to color vision deficiency (calculate error matrix)
        error = (c - error);

        // Shift colors
        vec4 correction;
        // protanopia / protanomaly corrections
        if ( COLORBLIND_MODE == 1 ) {
            //(kwin effect values)
            correction.r = error.r * 0.56667 + error.g * 0.43333 + error.b * 0.00000;
            correction.g = error.r * 0.55833 + error.g * 0.44267 + error.b * 0.00000;
            correction.b = error.r * 0.00000 + error.g * 0.24167 + error.b * 0.75833;
            // tries to mimic Android, GdH
            //correction.r = error.r * -0.5 + error.g * -0.3 + error.b * 0.0;
            //correction.g = error.r *  0.2 + error.g *  0.0 + error.b * 0.0;
            //correction.b = error.r *  0.2 + error.g *  1.0 + error.b * 1.0;
        // protanopia / protanomaly high contrast G-R corrections
        } else if ( COLORBLIND_MODE == 2 ) {
            correction.r = error.r * 2.56667 + error.g * 0.43333 + error.b * 0.00000;
            correction.g = error.r * 1.55833 + error.g * 0.44267 + error.b * 0.00000;
            correction.b = error.r * 0.00000 + error.g * 0.24167 + error.b * 0.75833;
        // deuteranopia / deuteranomaly corrections (tries to mimic Android, GdH)
        } else if ( COLORBLIND_MODE == 3 ) {
            correction.r = error.r * -0.7 + error.g * 0.0 + error.b * 0.0;
            correction.g = error.r *  0.5 + error.g * 1.0 + error.b * 0.0;
            correction.b = error.r * -0.3 + error.g * 0.0 + error.b * 1.0;
        // deuteranopia / deuteranomaly high contrast R-G corrections
        } else if ( COLORBLIND_MODE == 4 ) {
            correction.r = error.r * -1.5 + error.g * 1.5 + error.b * 0.0;
            correction.g = error.r * -1.5 + error.g * 1.5 + error.b * 0.0;
            correction.b = error.r * 1.5 + error.g * 0.0 + error.b * 0.0;
        // tritanopia / tritanomaly corrections (GdH)
        } else if ( COLORBLIND_MODE == 5 ) {
            correction.r = error.r * 0.3 + error.g * 0.5 + error.b * 0.4;
            correction.g = error.r * 0.5 + error.g * 0.7 + error.b * 0.3;
            correction.b = error.r * 0.0 + error.g * 0.0 + error.b * 1.0;
        }

        // Add compensation to original values
        correction = c + correction;
        correction.a = 1.0;

        cogl_color_out = correction;
    }
    """;

    // https://www.reddit.com/r/gamemaker/comments/11us4t4/accurate_monochrome_glsl_shader_tutorial/
    private const string MONOCHROME_SHADER = """
        uniform sampler2D tex;
        uniform float strength = %f;
        void main() {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec4 sample = texture2D (tex, uv);
            vec3 luminance = vec3 (0.2126, 0.7512, 0.0722);
            float gray = luminance.r * sample.r + luminance.g * sample.g + luminance.b * sample.b;
            cogl_color_out = vec4 (
                sample.r * (1.0 - strength) + gray * strength,
                sample.g * (1.0 - strength) + gray * strength,
                sample.b * (1.0 - strength) + gray * strength,
                1.0
            ) ;
        }
    """;

    public int mode { get; construct; }
    public double strength { get; construct; }

    public ColorblindCorrectionEffect (int mode, double strength) {
        Object (mode: mode, strength: strength);
    }

    construct {
        string shader;
        switch (mode) {
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
                shader = SHADER_TEMPLATE.printf (mode, strength);
                break;
            case 6:
                shader = MONOCHROME_SHADER.printf (strength);
                break;
            default:
                assert_not_reached ();
                break;
        }

        set_shader_source (shader);
    }
}
