/*
 * Copyright 2022-2023 GdH <G-dH@github.com>
 * Copyright 2023-2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

uniform sampler2D tex;
uniform int COLORBLIND_MODE;
uniform float STRENGTH;
uniform bool PAUSE_FOR_SCREENSHOT;

const mat3 RGB_TO_LMS = mat3(
    17.8824, 3.45565, 0.0299566,
    43.5161, 27.1554, 0.184309,
    4.11935, 3.86714, 1.46709
);

const mat3 LMS_TO_RGB = mat3(
    0.0809444479, -0.0102485335, -0.000365296938,
    -0.130504409, 0.0540193266, -0.00412161469,
    0.116721066, -0.113614708, 0.693511405
);

void main() {
    vec4 c = texture2D(tex, cogl_tex_coord0_in.xy);

    if (PAUSE_FOR_SCREENSHOT) {
        cogl_color_out = c;
        return;
    }

    vec3 lms = RGB_TO_LMS * c.rgb;

    // Remove invisible colors
    mat3 deficiencyMat;
    if (COLORBLIND_MODE == 1 || COLORBLIND_MODE == 2) { // Protanopia - reds are greatly reduced
        deficiencyMat = mat3(
            0.0, 0.0, 0.0,
            2.02344, 1.0, 0.0,
            -2.52581, 0.0, 1.0
        );
    } else if (COLORBLIND_MODE == 3 || COLORBLIND_MODE == 4) { // Deuteranopia - greens are greatly reduced
        deficiencyMat = mat3(
            1.0, 0.494207, 0.0,
            0.0, 0.0, 0.0,
            0.0, 1.24827, 1.0
        );
    } else if (COLORBLIND_MODE == 5 ) { // Tritanopia - blues are greatly reduced (1 of 10 000)
        // GdH - trinatopia vector calculated by me, all public sources were off
        deficiencyMat = mat3(
            1.0, 0.0, -0.012491378299329402,
            0.0, 1.0, 0.07203451899279534,
            0.0, 0.0, 0.0
        );
    } else {
        deficiencyMat = mat3(1.0);
    }

    vec3 perceivedRGB = LMS_TO_RGB * (deficiencyMat * lms);

    vec3 errorRGB = mix(c.rgb, perceivedRGB, STRENGTH);

    // Isolate invisible colors to color vision deficiency (calculate error matrix)
    vec3 delta = c.rgb - errorRGB;

    // Shift colors
    mat3 shiftMat;
    if ( COLORBLIND_MODE == 1 ) { // protanopia / protanomaly corrections
        //(kwin effect values)
        shiftMat = mat3(
            0.56667, 0.55833, 0.00000,
            0.43333, 0.44267, 0.24167,
            0.00000, 0.00000, 0.75833
        );
    } else if ( COLORBLIND_MODE == 2 ) { // protanopia / protanomaly high contrast G-R corrections
        shiftMat = mat3(
            2.56667, 1.55833, 0.00000,
            0.43333, 0.44267, 0.24167,
            0.00000, 0.00000, 0.75833
        );
    } else if ( COLORBLIND_MODE == 3 ) { // deuteranopia / deuteranomaly corrections (tries to mimic Android, GdH)
        shiftMat = mat3(
           -0.7,  0.5, -0.3,
            0.0,  1.0,  0.0,
            0.0,  0.0,  1.0
        );
    } else if ( COLORBLIND_MODE == 4 ) { // deuteranopia / deuteranomaly high contrast R-G corrections
        shiftMat = mat3(
           -1.5, -1.5,  1.5,
            1.5,  1.5,  0.0,
            0.0,  0.0,  0.0
        );
    } else if ( COLORBLIND_MODE == 5 ) { // tritanopia / tritanomaly corrections (GdH)
        shiftMat = mat3(
            0.3, 0.5, 0.0,
            0.5, 0.7, 0.0,
            0.4, 0.3, 1.0
        );
    } else {
        shiftMat = mat3(0.0);
    }

    // Add compensation to original values
    vec3 compensated = c.rgb + (shiftMat * delta);

    cogl_color_out = vec4(compensated, c.a);
}
