// Cinematic vertical film-strip transition for portrait slideshows.

uniform float roll_cells; // = 3.0
uniform float strip_width; // = 0.66

const vec4 BLACK = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 FILM_BASE = vec4(0.018, 0.016, 0.014, 1.0);
const vec4 FILM_EDGE = vec4(0.13, 0.09, 0.05, 1.0);

float rounded_box(vec2 p, vec2 center, vec2 half_size, float radius) {
  vec2 d = abs(p - center) - half_size + radius;
  float distance = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
  float antialias = 1.5 / resolution.y;
  return 1.0 - smoothstep(-antialias, antialias, distance);
}

float noise(vec2 value) {
  return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

float frame_seed(float value) {
  return fract(sin(value * 78.233) * 43758.5453);
}

float organic_roll_progress(float value) {
  float t = clamp((value - 0.10) / 0.90, 0.0, 1.0);
  return clamp(t + 0.04 * sin(6.2831853 * t), 0.0, 1.0);
}

vec2 gate_weave(float value) {
  return vec2(
    0.006 * sin(value * 37.0) + 0.002 * sin(value * 83.0),
    0.003 * sin(value * 19.0)
  );
}

float perforation_mask(vec2 q, float scroll, float strip_half_width, float rail_width, float scale) {
  float pitch = 0.125;
  float local_y = mod(q.y + scroll + pitch * 0.5, pitch) - pitch * 0.5;
  vec2 hole_half_size = vec2(rail_width * 0.19, pitch * 0.18) * scale;
  float left = rounded_box(vec2(q.x, local_y), vec2(-strip_half_width + rail_width * 0.55, 0.0), hole_half_size, 0.003);
  float right = rounded_box(vec2(q.x, local_y), vec2(strip_half_width - rail_width * 0.55, 0.0), hole_half_size, 0.003);
  return clamp(left + right, 0.0, 1.0);
}

vec4 center_saturation(vec4 color, float frame_center_y) {
  float saturation = 1.0 - smoothstep(0.15, 0.58, abs(frame_center_y));
  float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  return vec4(mix(vec3(luminance), color.rgb, saturation), color.a);
}

vec4 frame_color(vec2 uv, float incoming, float defocus) {
  vec2 blur = vec2(1.25 / resolution.x, 2.5 / resolution.y) * defocus;
  vec4 color = mix(getFromColor(uv), getToColor(uv), incoming) * 0.50;
  color += mix(getFromColor(uv + vec2(blur.x, 0.0)), getToColor(uv + vec2(blur.x, 0.0)), incoming) * 0.125;
  color += mix(getFromColor(uv - vec2(blur.x, 0.0)), getToColor(uv - vec2(blur.x, 0.0)), incoming) * 0.125;
  color += mix(getFromColor(uv + vec2(0.0, blur.y)), getToColor(uv + vec2(0.0, blur.y)), incoming) * 0.125;
  color += mix(getFromColor(uv - vec2(0.0, blur.y)), getToColor(uv - vec2(0.0, blur.y)), incoming) * 0.125;
  return color;
}

vec4 transition(vec2 uv) {
  vec2 q = vec2((uv.x - 0.5) * ratio, uv.y - 0.5) - gate_weave(progress);
  float strip_half_width = ratio * strip_width * 0.5;
  float rail_width = strip_half_width * 0.17;
  float image_half_width = strip_half_width - rail_width * 1.35;
  float image_half_height = image_half_width / ratio;
  float frame_gap = 0.055;
  float frame_pitch = image_half_height * 2.0 + frame_gap;
  float roll_progress = organic_roll_progress(progress);
  float scroll = roll_progress * roll_cells * frame_pitch;
  float frame_index = floor((q.y + scroll + frame_pitch * 0.5) / frame_pitch);
  float frame_center_y = frame_index * frame_pitch - scroll;
  vec2 frame_center = vec2(0.0, frame_center_y);
  vec2 image_half_size = vec2(image_half_width, image_half_height);
  float strip_mask = step(abs(q.x), strip_half_width);
  float outer_frame = rounded_box(q, frame_center, image_half_size + vec2(0.009), 0.008);
  float image_mask = rounded_box(q, frame_center, image_half_size, 0.004);
  float frame_shadow = rounded_box(q, frame_center + vec2(0.003, 0.014), image_half_size + vec2(0.015), 0.014);
  vec2 image_uv = (q - frame_center) / (image_half_size * 2.0) + 0.5;
  float incoming = step(frame_seed(frame_index), smoothstep(0.20, 0.80, roll_progress));
  float focus = 1.0 - smoothstep(0.12, 0.62, abs(frame_center_y));
  vec4 image = center_saturation(frame_color(image_uv, incoming, 1.0 - focus), frame_center_y);

  float edge_curve = smoothstep(0.55, 1.0, abs(q.x) / strip_half_width);
  float rail_mask = step(image_half_width + 0.012, abs(q.x)) * strip_mask;
  float grain = noise(q * resolution.y + vec2(progress * 31.0, progress * 47.0)) - 0.5;
  float sheen = 0.5 + 0.5 * sin(q.y * 22.0 - progress * 10.0);
  vec4 strip = vec4(FILM_BASE.rgb * mix(1.0, 0.62, edge_curve), 1.0);
  strip.rgb += vec3(grain * 0.026) * strip_mask;
  strip.rgb += vec3(0.035, 0.020, 0.006) * sheen * rail_mask;
  strip = mix(strip, FILM_EDGE, outer_frame);
  strip = mix(strip, BLACK, frame_shadow * (1.0 - image_mask) * 0.42);
  strip = mix(strip, image, image_mask);
  float holes = perforation_mask(q, scroll, strip_half_width, rail_width, 1.0);
  float hole_rim = clamp(perforation_mask(q, scroll, strip_half_width, rail_width, 1.35) - holes, 0.0, 1.0);
  strip = mix(strip, vec4(0.12, 0.075, 0.03, 1.0), hole_rim * 0.45);
  strip = mix(strip, BLACK, holes);

  return mix(BLACK, strip, strip_mask);
}
