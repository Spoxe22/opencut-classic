// Super 8 gate inspired by a worn vertical analogue frame.

uniform float frame_scale; // = 0.94
uniform float grain_strength; // = 0.08
uniform float frame_movement; // = 0.003
uniform float flicker_strength; // = 0.06

float noise(vec2 value) {
  return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

float rounded_box_distance(vec2 p, vec2 center, vec2 half_size, float radius) {
  vec2 d = abs(p - center) - half_size + radius;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

vec4 effect(vec2 uv) {
  float frame_tick = floor(progress * 240.0);
  vec2 frame_offset = vec2(
    sin(progress * 51.0) + 0.45 * sin(progress * 113.0),
    sin(progress * 43.0 + 1.2) + 0.35 * sin(progress * 97.0)
  ) * frame_movement;
  vec2 frame_uv = uv - frame_offset;
  vec2 media_uv = (uv - 0.5) / frame_scale + 0.5;
  vec4 image = getMediaColor(0, media_uv);

  float luminance = dot(image.rgb, vec3(0.2126, 0.7152, 0.0722));
  image.rgb = mix(vec3(luminance), image.rgb, 0.88);
  image.rgb = (image.rgb - 0.5) * 0.92 + 0.5;
  image.rgb *= vec3(1.055, 0.995, 0.90);
  float grain_resolution = min(resolution.y, 960.0);
  float grain = noise(floor(uv * grain_resolution * 0.58) + vec2(frame_tick * 3.1, frame_tick * 1.7)) - 0.5;
  image.rgb += vec3(grain * grain_strength);
  float vignette = smoothstep(0.72, 0.18, length((uv - vec2(0.5, 0.55)) * vec2(0.72, 1.0)));
  image.rgb *= mix(0.76, 1.03, vignette);

  float edge_wear =
    (noise(floor(frame_uv * vec2(67.0, 113.0))) - 0.5) * 0.004 +
    sin(frame_uv.x * 89.0 + frame_uv.y * 41.0) * 0.0015;
  float gate_distance = rounded_box_distance(frame_uv, vec2(0.5, 0.56), vec2(0.455, 0.38), 0.035) + edge_wear;
  float antialias = 1.5 / resolution.y;
  float gate = 1.0 - smoothstep(-antialias, antialias, gate_distance);

  float notch_pulse = 1.0 + 0.026 * sin(progress * 15.0) + 0.012 * sin(progress * 37.0 + 0.8);
  vec2 notch_center = vec2(0.5, 0.18 + 0.0025 * sin(progress * 19.0));
  float notch_distance = rounded_box_distance(frame_uv, notch_center, vec2(0.135, 0.075) * notch_pulse, 0.032);
  float notch = 1.0 - smoothstep(-antialias, antialias, notch_distance);
  float visible_image = gate * (1.0 - notch);

  float frame_grain = noise(floor(frame_uv * resolution.y * 0.32) + vec2(7.0, 19.0)) - 0.5;
  vec3 frame = vec3(0.006, 0.005, 0.004) + vec3(frame_grain * 0.018);
  float gate_glow = exp(-abs(gate_distance) * 130.0);
  float notch_glow = exp(-abs(notch_distance) * 72.0) * (0.82 + 0.18 * sin(progress * 21.0 + 0.5));
  float top_warmth = 0.22 + 0.78 * (1.0 - smoothstep(0.14, 0.72, frame_uv.y));
  frame += vec3(1.0, 0.32, 0.055) * (gate_glow * 0.18 * top_warmth + notch_glow * 0.52);

  float leak = exp(-pow((uv.x + 0.035) * 7.5, 2.0)) * (0.55 + 0.45 * sin(progress * 6.2831853 + 0.8));
  image.rgb += vec3(0.95, 0.13, 0.02) * leak * 0.10;
  vec3 result = mix(frame, image.rgb, visible_image);
  float flicker_noise = noise(vec2(floor(progress * 64.0), 53.0));
  float flicker_flash = smoothstep(0.93, 0.995, flicker_noise);
  float global_flicker = (flicker_noise - 0.5 + flicker_flash * 1.8) * flicker_strength;
  result = result * (1.0 + global_flicker) + vec3(max(global_flicker, 0.0) * 0.012);
  return vec4(clamp(result, 0.0, 1.0), 1.0);
}
