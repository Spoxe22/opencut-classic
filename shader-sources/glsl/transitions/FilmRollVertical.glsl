// Vertical film-strip transition for portrait slideshows.

uniform float roll_cells; // = 3.0
uniform float strip_width; // = 0.66

const vec4 BLACK = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 FILM_BASE = vec4(0.055, 0.047, 0.035, 1.0);
const vec4 FILM_EDGE = vec4(0.22, 0.18, 0.12, 1.0);

float rounded_box(vec2 p, vec2 center, vec2 half_size, float radius) {
  vec2 d = abs(p - center) - half_size + radius;
  float distance = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
  float antialias = 1.5 / resolution.y;
  return 1.0 - smoothstep(-antialias, antialias, distance);
}

float frame_seed(float value) {
  return fract(sin(value * 78.233) * 43758.5453);
}

float perforations(vec2 q, float scroll, float strip_half_width, float rail_width) {
  float pitch = 0.125;
  float local_y = mod(q.y + scroll + pitch * 0.5, pitch) - pitch * 0.5;
  vec2 hole_half_size = vec2(rail_width * 0.25, pitch * 0.22);
  float left = rounded_box(vec2(q.x, local_y), vec2(-strip_half_width + rail_width * 0.55, 0.0), hole_half_size, 0.008);
  float right = rounded_box(vec2(q.x, local_y), vec2(strip_half_width - rail_width * 0.55, 0.0), hole_half_size, 0.008);
  return clamp(left + right, 0.0, 1.0);
}

vec4 center_saturation(vec4 color, float frame_center_y) {
  float saturation = 1.0 - smoothstep(0.15, 0.58, abs(frame_center_y));
  float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  return vec4(mix(vec3(luminance), color.rgb, saturation), color.a);
}

vec4 transition(vec2 uv) {
  vec2 q = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  float strip_half_width = ratio * strip_width * 0.5;
  float rail_width = strip_half_width * 0.17;
  float image_half_width = strip_half_width - rail_width * 1.35;
  float image_half_height = image_half_width / ratio;
  float frame_gap = 0.055;
  float frame_pitch = image_half_height * 2.0 + frame_gap;
  float roll_progress = clamp((progress - 0.10) / 0.90, 0.0, 1.0);
  float scroll = roll_progress * roll_cells * frame_pitch;
  float frame_index = floor((q.y + scroll + frame_pitch * 0.5) / frame_pitch);
  float frame_center_y = frame_index * frame_pitch - scroll;
  vec2 frame_center = vec2(0.0, frame_center_y);
  vec2 image_half_size = vec2(image_half_width, image_half_height);
  float strip_mask = step(abs(q.x), strip_half_width);
  float outer_frame = rounded_box(q, frame_center, image_half_size + vec2(0.014), 0.022);
  float image_mask = rounded_box(q, frame_center, image_half_size, 0.012);
  vec2 image_uv = (q - frame_center) / (image_half_size * 2.0) + 0.5;
  float incoming = step(frame_seed(frame_index), smoothstep(0.20, 0.80, roll_progress));
  vec4 image = center_saturation(mix(getFromColor(image_uv), getToColor(image_uv), incoming), frame_center_y);

  vec4 strip = FILM_BASE;
  strip = mix(strip, FILM_EDGE, outer_frame);
  strip = mix(strip, image, image_mask);
  strip = mix(strip, BLACK, perforations(q, scroll, strip_half_width, rail_width));

  vec4 film = mix(BLACK, strip, strip_mask);
  return film;
}
