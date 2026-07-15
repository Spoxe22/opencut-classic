// Five-photo vertical film effect: three frames downward, then two hidden frames return upward.

uniform float strip_width; // = 0.9

const vec4 BLACK = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 FILM_BASE = vec4(0.030, 0.024, 0.018, 1.0);
const vec4 FILM_EDGE = vec4(0.17, 0.12, 0.07, 1.0);

float rounded_box(vec2 p, vec2 center, vec2 half_size, float radius) {
  vec2 d = abs(p - center) - half_size + radius;
  float distance = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
  float antialias = 1.5 / resolution.y;
  return 1.0 - smoothstep(-antialias, antialias, distance);
}

float noise(vec2 value) {
  return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
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

vec4 frame_color(int photo_index, vec2 uv, float defocus) {
  vec2 blur = vec2(1.25 / resolution.x, 2.5 / resolution.y) * defocus;
  vec4 color = getMediaColor(photo_index, uv) * 0.50;
  color += getMediaColor(photo_index, uv + vec2(blur.x, 0.0)) * 0.125;
  color += getMediaColor(photo_index, uv - vec2(blur.x, 0.0)) * 0.125;
  color += getMediaColor(photo_index, uv + vec2(0.0, blur.y)) * 0.125;
  color += getMediaColor(photo_index, uv - vec2(0.0, blur.y)) * 0.125;
  return color;
}

vec4 city_morning(vec2 q) {
  float sky = 1.0 - smoothstep(-0.12, 0.40, q.y);
  vec3 surface = mix(vec3(0.68, 0.60, 0.48), vec3(0.76, 0.86, 0.92), sky);
  float city_x = q.x / ratio + 0.5;
  float building_index = floor(city_x * 7.0);
  float roof = -0.04 + noise(vec2(building_index, 3.1)) * 0.27;
  float building = smoothstep(roof - 0.018, roof + 0.018, q.y);
  float facade = 0.84 + noise(vec2(building_index, 9.4)) * 0.12;
  surface = mix(surface, vec3(0.60, 0.61, 0.58) * facade, building * 0.62);
  float vignette = 1.0 - smoothstep(0.18, 0.80, length(vec2(q.x / ratio, q.y)));
  return vec4(surface * mix(0.62, 0.90, vignette), 1.0);
}

vec4 effect(vec2 uv) {
  vec2 backdrop_q = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec2 micro_weave = vec2(
    0.0018 * sin(progress * 53.0) + 0.0008 * sin(progress * 97.0),
    0.0012 * sin(progress * 41.0) + 0.0006 * sin(progress * 79.0)
  );
  vec2 q = backdrop_q - micro_weave;
  float strip_half_width = ratio * strip_width * 0.5;
  float rail_width = strip_half_width * 0.17;
  float image_half_width = strip_half_width - rail_width * 1.35;
  float image_half_height = image_half_width / ratio;
  float frame_gap = 0.055;
  float frame_pitch = image_half_height * 2.0 + frame_gap;
  float downward = smoothstep(0.0, 0.46, progress);
  float upward = smoothstep(0.54, 1.0, progress);
  bool reverse_pass = progress >= 0.54;
  float scroll = reverse_pass ? mix(-frame_pitch * 2.0, 0.0, upward) : -downward * frame_pitch * 2.0;
  float tilt = 0.012 + sin(progress * 6.2831853) * 0.002;
  float lateral_drift = sin(progress * 6.2831853) * 0.012 + sin(progress * 12.5663706) * 0.004;
  vec2 film_q = vec2(
    q.x * cos(tilt) + q.y * sin(tilt),
    -q.x * sin(tilt) + q.y * cos(tilt)
  ) - vec2(lateral_drift, 0.0);
  float frame_index = floor((film_q.y + scroll + frame_pitch * 0.5) / frame_pitch);
  float frame_center_y = frame_index * frame_pitch - scroll;
  float frame_screen_y = frame_center_y;
  int sequence_index = int(clamp(-frame_index, 0.0, 2.0));
  int photo_index = reverse_pass ? 2 + int(clamp(frame_index + 2.0, 0.0, 2.0)) : sequence_index;
  vec2 frame_center = vec2(0.0, frame_center_y);
  vec2 image_half_size = vec2(image_half_width, image_half_height);
  float view_gate = rounded_box(film_q, vec2(0.0), image_half_size + vec2(0.010), 0.010);
  float edge_antialias = 1.5 * ratio / resolution.x;
  float strip_mask = 1.0 - smoothstep(strip_half_width - edge_antialias, strip_half_width + edge_antialias, abs(film_q.x));
  float outer_frame = rounded_box(film_q, frame_center, image_half_size + vec2(0.009), 0.008) * view_gate;
  float image_mask = rounded_box(film_q, frame_center, image_half_size, 0.004) * view_gate;
  float frame_shadow = rounded_box(film_q, frame_center + vec2(0.003, 0.014), image_half_size + vec2(0.015), 0.014) * view_gate;
  vec2 image_uv = (film_q - frame_center) / (image_half_size * 2.0) + 0.5;
  float focus = 1.0 - smoothstep(0.12, 0.62, abs(frame_screen_y));
  vec4 image = center_saturation(cinema_print(frame_color(photo_index, image_uv, 1.0 - focus)), backdrop_q.y, frame_screen_y);
  image.rgb = clamp(image.rgb * 1.05 + vec3(0.018, 0.010, 0.004), 0.0, 1.0);

  float edge_curve = smoothstep(0.55, 1.0, abs(film_q.x) / strip_half_width);
  float rail_mask = step(image_half_width + 0.012, abs(film_q.x)) * strip_mask;
  float grain = noise(film_q * resolution.y + vec2(progress * 8.0, progress * 5.0)) - 0.5;
  float sheen = 0.56 + 0.44 * sin(film_q.y * 22.0 - progress * 5.0);
  float rail_patina = noise(floor(film_q * resolution.y * vec2(0.028, 0.022))) - 0.5;
  float rail_streak = noise(vec2(floor(film_q.x * resolution.y * 0.16), floor(film_q.y * resolution.y * 0.013))) - 0.5;
  float rail_wear = smoothstep(0.13, 0.50, abs(rail_patina + rail_streak * 0.85));
  float rail_scuff = step(0.78, noise(vec2(floor(film_q.x * resolution.y * 0.35), floor(film_q.y * resolution.y * 0.035))));
  float film_curve = 1.0 - pow(abs(film_q.x) / strip_half_width, 2.0);
  vec4 strip = vec4(FILM_BASE.rgb * mix(1.0, 0.62, edge_curve), 1.0);
  strip.rgb += vec3(grain * 0.035) * strip_mask;
  strip.rgb += vec3(0.155, 0.078, 0.026) * (0.42 + sheen * 0.50 + rail_patina * 0.65) * rail_mask;
  strip.rgb *= 1.0 - rail_wear * rail_mask * 0.28;
  strip.rgb -= vec3(0.018, 0.010, 0.004) * rail_scuff * rail_mask;
  strip = mix(strip, FILM_EDGE, outer_frame);
  strip = mix(strip, BLACK, frame_shadow * (1.0 - image_mask) * 0.42);
  strip = mix(strip, image, image_mask);
  strip.rgb *= 0.955 + film_curve * 0.045;
  float grain_resolution = min(resolution.y, 960.0);
  vec2 emulsion_coord = vec2(film_q.x, film_q.y + scroll) * grain_resolution * 0.82;
  float emulsion_grain = noise(emulsion_coord) - 0.5;
  vec2 red_leak_position = vec2(backdrop_q.x / ratio + 0.40, backdrop_q.y + 0.12);
  vec2 gold_leak_position = vec2(backdrop_q.x / ratio - 0.34, backdrop_q.y - 0.18);
  float red_leak = exp(-dot(red_leak_position, red_leak_position) * 15.0);
  float gold_leak = exp(-dot(gold_leak_position, gold_leak_position) * 20.0);
  float film_burn = max(red_leak, gold_leak);
  float mobile_leak_center = -0.52 + 1.04 * smoothstep(0.0, 1.0, progress);
  vec2 mobile_leak_position = vec2(backdrop_q.x / ratio - mobile_leak_center, backdrop_q.y + 0.18);
  float mobile_leak = exp(-dot(mobile_leak_position, mobile_leak_position) * 18.0);
  float burn_falloff = 0.35 + 0.65 * (1.0 - smoothstep(0.12, 0.70, abs(backdrop_q.y)));
  vec3 burn_color = mix(vec3(0.98, 0.16, 0.025), vec3(1.0, 0.78, 0.25), gold_leak / (red_leak + gold_leak + 0.0001));
  strip.rgb = clamp(
    strip.rgb + vec3(emulsion_grain * (0.020 + image_mask * 0.050))
      + burn_color * film_burn * burn_falloff * (0.085 + image_mask * 0.22)
      + vec3(1.0, 0.42, 0.08) * mobile_leak * burn_falloff * (0.035 + image_mask * 0.095),
    0.0,
    1.0
  );
  float holes = perforation_mask(film_q, scroll, strip_half_width, rail_width, 1.0);
  float hole_rim = clamp(perforation_mask(film_q, scroll, strip_half_width, rail_width, 1.35) - holes, 0.0, 1.0);
  strip = mix(strip, vec4(0.12, 0.075, 0.03, 1.0), hole_rim * 0.45);

  float contact_distance = max(abs(film_q.x) - strip_half_width, 0.0);
  float contact_shadow = exp(-pow(contact_distance / 0.026, 2.0));
  vec4 backdrop = city_morning(backdrop_q);
  backdrop.rgb *= 1.0 - contact_shadow * 0.18;
  strip.rgb *= 0.985 + sin(progress * 6.2831853 + 0.7) * 0.015;
  return mix(backdrop, strip, strip_mask * (1.0 - holes));
}
