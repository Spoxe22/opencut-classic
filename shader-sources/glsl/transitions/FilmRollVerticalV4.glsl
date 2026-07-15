// Cinematic vertical film-strip over a bright city morning.

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

vec4 center_saturation(vec4 color, float screen_y, float frame_center_y) {
  float scan_saturation = 1.0 - smoothstep(0.025, 0.24, abs(screen_y));
  float full_frame_saturation = 1.0 - smoothstep(0.0, 0.18, abs(frame_center_y));
  float saturation = max(scan_saturation, full_frame_saturation);
  float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  return vec4(mix(vec3(luminance), color.rgb, saturation), color.a);
}

vec4 cinema_print(vec4 color) {
  float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  vec3 printed = mix(vec3(luminance), color.rgb, 0.88);
  printed = (printed - 0.5) * 0.88 + 0.5;
  float shadow = 1.0 - smoothstep(0.0, 0.22, luminance);
  float highlight = smoothstep(0.65, 1.0, luminance);
  printed += vec3(0.025) * shadow;
  printed = mix(printed, vec3(0.88), highlight * 0.16);
  return vec4(clamp(printed, 0.0, 1.0), color.a);
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

vec4 city_morning(vec2 q) {
  float sky = 1.0 - smoothstep(-0.12, 0.40, q.y);
  vec3 surface = mix(vec3(0.56, 0.54, 0.49), vec3(0.68, 0.81, 0.90), sky);
  float city_x = q.x / ratio + 0.5;
  float building_index = floor(city_x * 7.0);
  float roof = -0.04 + noise(vec2(building_index, 3.1)) * 0.27;
  float building = smoothstep(roof - 0.018, roof + 0.018, q.y);
  float facade = 0.84 + noise(vec2(building_index, 9.4)) * 0.12;
  surface = mix(surface, vec3(0.60, 0.61, 0.58) * facade, building * 0.62);
  float vignette = 1.0 - smoothstep(0.18, 0.80, length(vec2(q.x / ratio, q.y)));
  return vec4(surface * mix(0.48, 0.82, vignette), 1.0);
}

vec4 transition(vec2 uv) {
  vec2 backdrop_q = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec2 q = backdrop_q - gate_weave(progress);
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
  vec4 image = center_saturation(cinema_print(frame_color(image_uv, incoming, 1.0 - focus)), q.y, frame_center_y);

  float edge_curve = smoothstep(0.55, 1.0, abs(q.x) / strip_half_width);
  float rail_mask = step(image_half_width + 0.012, abs(q.x)) * strip_mask;
  float grain = noise(q * resolution.y + vec2(progress * 31.0, progress * 47.0)) - 0.5;
  float sheen = 0.5 + 0.5 * sin(q.y * 22.0 - progress * 10.0);
  float rail_patina = noise(floor(q * resolution.y * vec2(0.028, 0.022))) - 0.5;
  float rail_streak = noise(vec2(floor(q.x * resolution.y * 0.16), floor(q.y * resolution.y * 0.013))) - 0.5;
  float rail_wear = smoothstep(0.13, 0.50, abs(rail_patina + rail_streak * 0.85));
  float rail_scuff = step(0.78, noise(vec2(floor(q.x * resolution.y * 0.35), floor(q.y * resolution.y * 0.035))));
  vec4 strip = vec4(FILM_BASE.rgb * mix(1.0, 0.62, edge_curve), 1.0);
  strip.rgb += vec3(grain * 0.026) * strip_mask;
  strip.rgb += vec3(0.085, 0.048, 0.017) * (0.32 + sheen * 0.32 + rail_patina * 0.80) * rail_mask;
  strip.rgb *= 1.0 - rail_wear * rail_mask * 0.42;
  strip.rgb -= vec3(0.035, 0.020, 0.008) * rail_scuff * rail_mask;
  strip = mix(strip, FILM_EDGE, outer_frame);
  strip = mix(strip, BLACK, frame_shadow * (1.0 - image_mask) * 0.42);
  strip = mix(strip, image, image_mask);
  float flicker = 0.95 + 0.035 * sin(progress * 83.0) + 0.018 * sin(progress * 171.0);
  float emulsion_grain = noise(q * resolution.y * 0.75 + vec2(progress * 71.0, progress * 43.0)) - 0.5;
  float scratch_column = step(0.993, noise(vec2(floor(q.x * resolution.y * 0.5), floor(progress * 12.0))));
  float scratch = scratch_column * (0.25 + 0.75 * step(0.45, noise(vec2(floor(q.y * resolution.y * 0.12), floor(progress * 12.0)))));
  strip.rgb = clamp(strip.rgb * flicker + vec3(emulsion_grain * 0.045), 0.0, 1.0);
  strip.rgb *= 1.0 - scratch * 0.16;
  float holes = perforation_mask(q, scroll, strip_half_width, rail_width, 1.0);
  float hole_rim = clamp(perforation_mask(q, scroll, strip_half_width, rail_width, 1.35) - holes, 0.0, 1.0);
  strip = mix(strip, vec4(0.12, 0.075, 0.03, 1.0), hole_rim * 0.45);

  return mix(city_morning(backdrop_q), strip, strip_mask * (1.0 - holes));
}
