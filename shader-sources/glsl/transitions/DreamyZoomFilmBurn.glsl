// DreamyZoom by Zeh Fernando, film-burn treatment by slideshow_ai.
// License: MIT

#define DEG2RAD 0.03926990816987241548078304229099

uniform float rotation; // = 0.0
uniform float scale; // = 1.0
uniform float burn_strength; // = 1.0

float burnHash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float burnNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(burnHash(i), burnHash(i + vec2(1.0, 0.0)), f.x),
    mix(burnHash(i + vec2(0.0, 1.0)), burnHash(i + vec2(1.0)), f.x),
    f.y
  );
}

float burnFbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.55;
  for (int i = 0; i < 4; i++) {
    value += amplitude * burnNoise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    amplitude *= 0.5;
  }
  return value;
}

vec4 transition(vec2 uv) {
  float phase = progress < 0.5 ? progress * 2.0 : (progress - 0.5) * 2.0;
  float angleOffset = progress < 0.5
    ? mix(0.0, rotation * DEG2RAD, phase)
    : mix(-rotation * DEG2RAD, 0.0, phase);
  float newScale = progress < 0.5 ? mix(1.0, scale, phase) : mix(scale, 1.0, phase);

  vec2 p = (uv - vec2(0.5)) / newScale * vec2(ratio, 1.0);
  float angle = atan(p.y, p.x) + angleOffset;
  float dist = length(p);
  p = vec2(cos(angle) * dist / ratio, sin(angle) * dist) + vec2(0.5);

  vec4 source = progress < 0.5 ? getFromColor(p) : getToColor(p);
  float envelope = pow(sin(progress * 3.141592653589793), 0.7);
  vec2 burnUv = vec2(uv.x * ratio, uv.y);
  vec2 hotspot = vec2(
    mix(-0.15, ratio + 0.15, progress),
    0.5 + sin(progress * 8.0) * 0.22
  );
  float radial = 1.0 - smoothstep(0.05, 0.82, length(burnUv - hotspot));
  float textureField = burnFbm(burnUv * 3.5 + vec2(progress * 4.2, -progress * 2.7));
  float field = clamp(radial * 0.75 + textureField * 0.65, 0.0, 1.0) * envelope;

  float outer = smoothstep(0.08, 0.48, field);
  float middle = smoothstep(0.34, 0.72, field);
  float core = smoothstep(0.66, 0.94, field);
  vec3 burnColor = mix(vec3(1.0, 0.04, 0.0), vec3(1.0, 0.48, 0.02), middle);
  burnColor = mix(burnColor, vec3(1.0, 0.96, 0.72), core);

  float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
  vec3 saturated = mix(vec3(luminance), source.rgb, 1.0 + envelope * burn_strength * 0.65);
  vec3 screened = 1.0 - (1.0 - saturated) * (1.0 - burnColor);
  vec3 color = mix(saturated, screened, clamp(outer * burn_strength, 0.0, 0.92));
  color += burnColor * (middle * 0.28 + core * 0.55) * burn_strength;

  float flash = progress < 0.5 ? phase : 1.0 - phase;
  return vec4(color + vec3(flash), source.a);
}
