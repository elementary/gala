/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

// based on shader from mutter

uniform sampler2D tex;
uniform float clip_radius;
uniform vec2 actor_size;

float rounded_rect_coverage (vec2 p) {
  float center_left = clip_radius + 1.5;
  float center_right = actor_size.x - clip_radius - 0.55;
  float center_x;

  if (p.x < center_left)
    center_x = center_left;
  else if (p.x >= center_right)
    center_x = center_right;
  else
    return 1.0;

  float center_top = clip_radius + 1.5;
  float center_bottom = actor_size.y - clip_radius - 0.55;
  float center_y;

  if (p.y < center_top)
    center_y = center_top;
  else if (p.y > center_bottom)
    center_y = center_bottom;
  else
    return 1.0;

  vec2 delta = p - vec2 (center_x, center_y);
  float dist_squared = dot (delta, delta);

  // Fully outside the circle
  float outer_radius = clip_radius + 0.5;
  if (dist_squared > (outer_radius * outer_radius))
    return 0.0;

  // Fully inside the circle
  float inner_radius = clip_radius - 0.5;
  if (dist_squared <= (inner_radius * inner_radius))
    return 1.0;

  // Only pixels on the edge of the curve need expensive antialiasing
  return smoothstep (outer_radius, inner_radius, sqrt (dist_squared));
}

void main () {
  vec4 sample = texture2D (tex, cogl_tex_coord0_in.xy);

  vec2 texture_coord = cogl_tex_coord0_in.xy * actor_size;
  float res = rounded_rect_coverage (texture_coord);

  cogl_color_out = sample * cogl_color_in * res;
}
