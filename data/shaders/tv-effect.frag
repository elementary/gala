/*
 * Copyright 2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

uniform sampler2D tex;
uniform float OCCLUSION; // 0.0 when the TV is fully on, 1.0 when it's fully off
uniform float HEIGHT;    // Screen height in pixels

float cubicBezier(float x, float a, float b, float c, float d) {
    float _x = 1.0 - x;
    return a * _x * _x * _x +
           b * 3.0 * _x * _x * x +
           c * 3.0 * _x * x * x +
           d * x * x * x;
}

vec4 tvEffect(vec2 uv, float scale, float occlusion) {
    float y_scaled = 0.5 + (uv.y - 0.5) / (scale * scale);
    float x_scaled = uv.x;

    // Wait for scale to get small enough before shrinking the bright line to a dot
    if (scale < 0.1) {
        float scale_fract = scale / 0.1;
        x_scaled = 0.5 + (uv.x - 0.5) / (scale_fract * scale_fract);
    }

    // Outside of the scaled area should be black
    if (scale >= 0.0 && y_scaled >= 0.0 && y_scaled <= 1.0 && x_scaled >= 0.0 && x_scaled <= 1.0) {
        vec4 color = texture2D(tex, vec2(x_scaled, y_scaled));
        // Make it brighter as the window gets smaller
        return color + occlusion * color + occlusion * 0.75;
    } else {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
}

void main() {
    // Ease out the occlusion
    float occlusion = cubicBezier(OCCLUSION, 0.0, 0.98, 0.75, 1.0);
    float scale = 1.0 - occlusion;
    vec2 uv = cogl_tex_coord0_in.xy;

    // Apply a 5x5 Gaussian blur, with support of 0.5 and sigma 1.0
    float kernel[5];
    kernel[0] = 0.0614;
    kernel[1] = 0.2448;
    kernel[2] = 0.3877;
    kernel[3] = 0.2448;
    kernel[4] = 0.0614;

    float blurSize = occlusion * 5.0 / HEIGHT;

    vec4 color = vec4(0.0);
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            vec2 offset = vec2(float(i - 2), float(j - 2)) * blurSize;
            color += tvEffect(uv + offset, scale, occlusion) * kernel[i] * kernel[j];
        }
    }

    cogl_color_out = color;
}
