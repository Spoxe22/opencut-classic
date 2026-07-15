// Author: Motion Machine
// License: MIT

uniform float threshold;         // ex: 0.78
uniform float spread;            // ex: 0.24
uniform float knee;              // ex: 0.62
uniform float degrade_strength;  // ex: 0.85
uniform float saturation_boost;  // ex: 0.10

float sat(float x) {
  return clamp(x, 0.0, 1.0);
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 boostSaturation(vec3 color, float amount) {
  float g = luma(color);
  return clamp(mix(vec3(g), color, 1.0 + amount), 0.0, 1.0);
}

// Only already-bright areas can seed the transition
float brightSeed(vec3 color, float t) {
  return smoothstep(t, 1.0, luma(color));
}

// Spatial propagation from highlight sources
float expandedSourceMask(vec2 uv, float radius) {
  vec2 r = vec2(radius / max(ratio, 0.0001), radius);

  float m = 0.0;

  m = max(m, brightSeed(getFromColor(uv).rgb, threshold));

  m = max(m, brightSeed(getFromColor(uv + vec2( r.x, 0.0)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(-r.x, 0.0)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(0.0,  r.y)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(0.0, -r.y)).rgb, threshold));

  m = max(m, brightSeed(getFromColor(uv + vec2( r.x,  r.y)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(-r.x,  r.y)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2( r.x, -r.y)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(-r.x, -r.y)).rgb, threshold));

  m = max(m, brightSeed(getFromColor(uv + vec2(2.0 * r.x, 0.0)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(-2.0 * r.x, 0.0)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(0.0,  2.0 * r.y)).rgb, threshold));
  m = max(m, brightSeed(getFromColor(uv + vec2(0.0, -2.0 * r.y)).rgb, threshold));

  return m;
}

// Highlight degradation only
vec3 degradeHighlights(vec3 color, float amount) {
  float lum = luma(color);
  float hi = smoothstep(knee, 1.0, lum);

  // optional slight saturation push before degradation
  vec3 satColor = boostSaturation(color, saturation_boost * amount);

  // push highlights upward, then flatten them
  vec3 clipped = min(satColor * (1.0 + 0.18 * amount * hi), vec3(1.0));

  float maxc = max(max(clipped.r, clipped.g), clipped.b);
  vec3 flattened = mix(clipped, vec3(maxc), 0.32 * amount * hi);

  // mild local contrast loss in bright regions
  vec3 grayish = vec3(luma(flattened));
  vec3 compressed = mix(flattened, grayish, 0.18 * amount * hi);

  // only highlights are strongly affected
  return mix(color, compressed, amount * hi);
}

float growthCurve(float p) {
  // spatial propagation
  return smoothstep(0.04, 0.72, p);
}

float damageCurve(float p) {
  // amount of degradation inside the propagated zone
  return smoothstep(0.10, 0.66, p);
}

float dissolveCurve(float p) {
  // handoff only after the degraded field nearly fills the frame
  return smoothstep(0.70, 0.82, p);
}

float revealCurve(float p) {
  // incoming image recovers near the end
  return smoothstep(0.82, 1.0, p);
}

vec4 transition(vec2 uv) {
  float p = progress;

  vec4 fromC = getFromColor(uv);
  vec4 toC   = getToColor(uv);

  // expanding field from bright seeds in the FROM image
  float radius = spread * growthCurve(p);
  float fillMask = expandedSourceMask(uv, radius);
  fillMask = smoothstep(0.0, 1.0, fillMask);

  // outgoing image degrades only where the propagated field has reached
  float damage = damageCurve(p) * fillMask;
  vec3 fromDamaged = mix(
    fromC.rgb,
    degradeHighlights(fromC.rgb, degrade_strength),
    damage
  );

  // incoming image starts slightly degraded, then returns to normal
  vec3 toDamaged = degradeHighlights(toC.rgb, degrade_strength);
  float reveal = revealCurve(p);
  vec3 toRecovered = mix(toDamaged, toC.rgb, reveal);

  float dissolve = dissolveCurve(p);

  vec3 finalColor = mix(fromDamaged, toRecovered, dissolve);
  return vec4(finalColor, mix(fromC.a, toC.a, dissolve));
}