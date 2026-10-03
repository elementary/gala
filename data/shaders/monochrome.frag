/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

uniform sampler2D tex;
uniform float STRENGTH;
uniform bool PAUSE_FOR_SCREENSHOT;

const mat3 GRAY_MAT = mat3(
    0.2126, 0.2126, 0.2126,
    0.7152, 0.7152, 0.7152,
    0.0722, 0.0722, 0.0722
);

void main() {
    vec4 sample = texture2D (tex, cogl_tex_coord0_in.xy);

    if (PAUSE_FOR_SCREENSHOT) {
        cogl_color_out = sample;
        return;
    }

    vec3 grayRGB = GRAY_MAT * sample.rgb;
    vec3 result = mix(sample.rgb, grayRGB, STRENGTH);
    cogl_color_out = vec4(result, sample.a);
}
