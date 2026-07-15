// Vertical stacked-viewer transition inspired by StereoViewer by Ted Schundler.
// License: BSD 2 Clause

uniform float zoom; // = 0.94
uniform float corner_radius; // = 0.18

const vec4 black = vec4(0.0, 0.0, 0.0, 1.0);

float rounded_box(vec2 p, vec2 center, vec2 half_size, float radius) {
  vec2 d = abs(p - center) - half_size + radius;
  float distance = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
  float antialias = 1.5 / resolution.y;
  return 1.0 - smoothstep(-antialias, antialias, distance);
}

vec2 viewer_sample_uv(vec2 local, vec2 half_size) {
  float card_ratio = half_size.x / half_size.y;
  local.y = (local.y - 0.5) * (ratio / card_ratio) + 0.5;
  return local;
}

vec4 full_card(vec2 uv, bool incoming, float amount, float radius) {
  vec2 q = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec2 half_size = vec2(ratio, 1.0) * 0.5 * mix(1.0, zoom, amount);
  float mask = rounded_box(q, vec2(0.0), half_size, radius * amount);
  vec2 sample_uv = (uv - 0.5) / mix(1.0, zoom, amount) + 0.5;
  vec4 image = incoming ? getToColor(sample_uv) : getFromColor(sample_uv);
  return mix(black, image, mask);
}

vec4 stacked_cards(vec2 uv, bool incoming, float amount, float radius) {
  vec2 q = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  float offset = mix(0.22, 0.64, amount);
  vec2 half_size = vec2(ratio * 0.45, 0.18) * mix(1.0, 0.78, amount);
  float card_radius = min(radius, min(half_size.x, half_size.y) * 0.72);
  vec2 top_center = vec2(0.0, -offset);
  vec2 bottom_center = vec2(0.0, offset);
  float top_mask = rounded_box(q, top_center, half_size, card_radius);
  float bottom_mask = rounded_box(q, bottom_center, half_size, card_radius);
  vec2 top_uv = viewer_sample_uv((q - top_center) / half_size * 0.5 + 0.5, half_size);
  vec2 bottom_uv = viewer_sample_uv((q - bottom_center) / half_size * 0.5 + 0.5, half_size);
  vec4 top = incoming ? getToColor(top_uv) : getFromColor(top_uv);
  vec4 bottom = incoming ? getToColor(bottom_uv) : getFromColor(bottom_uv);
  vec4 cards = black;
  cards = mix(cards, top, top_mask);
  cards = mix(cards, bottom, bottom_mask);
  return cards;
}

vec4 transition(vec2 uv) {
  float radius = corner_radius * min(ratio, 1.0);

  if (progress <= 0.0) {
    return getFromColor(uv);
  } else if (progress < 0.12) {
    return full_card(uv, false, progress / 0.12, radius);
  } else if (progress < 0.44) {
    return stacked_cards(uv, false, (progress - 0.12) / 0.32, radius);
  } else if (progress < 0.56) {
    return black;
  } else if (progress < 0.88) {
    return stacked_cards(uv, true, 1.0 - (progress - 0.56) / 0.32, radius);
  } else if (progress < 1.0) {
    return full_card(uv, true, (1.0 - progress) / 0.12, radius);
  }
  return getToColor(uv);
}
