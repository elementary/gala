uniform vec4  bounds;           // x, y: top left; z, w: bottom right
uniform float clip_radius;
uniform vec2  pixel_step;


float circle_bounds(vec2 p, vec2 center, float clip_radius) {
  vec2 delta = p - vec2(center.x, center.y);
  float dist_squared = dot(delta, delta);

  // Fully outside the circle
  float outer_radius = clip_radius + 0.5;
  if(dist_squared >= (outer_radius * outer_radius))
    return 0.0;

  // Fully inside the circle
  float inner_radius = clip_radius - 0.5;
  if(dist_squared <= (inner_radius * inner_radius))
    return 1.0;

  // Only pixels on the edge of the curve need expensive antialiasing
  return outer_radius - sqrt(dist_squared);
}

float rounded_rect_coverage(vec2 p, vec4 bounds, float clip_radius) {
  // Outside the bounds
  if(p.x < bounds.x || p.x > bounds.z || p.y < bounds.y || p.y > bounds.w) {
    return 0.0;
  }

  vec2 center;

  float center_left = bounds.x + clip_radius;
  float center_right = bounds.z - clip_radius;

  if(p.x < center_left)
    center.x = center_left;
  else if(p.x > center_right)
    center.x = center_right;
  else
    return 1.0; // The vast majority of pixels exit early here

  float center_top = bounds.y + clip_radius;
  float center_bottom = bounds.w - clip_radius;

  if(p.y < center_top)
      center.y = center_top;
  else if(p.y > center_bottom)
    center.y = center_bottom;
  else
    return 1.0;

  return circle_bounds(p, center, clip_radius);
}

void main() {
  vec2 texture_coord = cogl_tex_coord0_in.xy / pixel_step;

  float outer_alpha = rounded_rect_coverage(texture_coord, bounds, clip_radius);

  cogl_color_out *= outer_alpha;
}