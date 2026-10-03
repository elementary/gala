/*
 * Copyright 2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

uniform sampler2D tex;
uniform int RADIUS;
uniform vec2 PIXEL_STEP;
uniform vec2 DIRECTION;

void main() {
    if (RADIUS == 0) {
        cogl_color_out = texture2D(tex, cogl_tex_coord0_in.xy);
        return;
    }

    vec4 sum = vec4(0, 0, 0, 0);
    int count = 0;

    for (int i = -RADIUS; i <= RADIUS; i++) {
        vec2 offset = DIRECTION * PIXEL_STEP * i;

        sum += texture2D(tex, cogl_tex_coord0_in.xy + offset);
        count += 1;
    }

    cogl_color_out = sum / count;
}
