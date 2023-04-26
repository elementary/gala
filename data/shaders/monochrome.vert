/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

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
        sample.a
    ) ;
}
