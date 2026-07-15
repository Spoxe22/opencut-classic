// Procedural river-current transition by slideshow_ai.

uniform vec2 flow_direction; // = vec2(1.0, 0.15)
uniform float ripple_strength; // = 0.012

const float PI = 3.141592653589793;

vec4 transition(vec2 uv) {
  vec2 direction = flow_direction / max(length(flow_direction), 0.001);
  vec2 normal = vec2(-direction.y, direction.x);
  vec2 centered = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  float along = dot(centered, direction);
  float across = dot(centered, normal);
  float envelope = sin(PI * progress);
  float ripple = sin(across * 78.0 - progress * 18.0);
  ripple += sin(across * 33.0 + progress * 24.0) * 0.45;
  ripple *= ripple_strength;
  float extent = abs(direction.x) * ratio * 0.5 + abs(direction.y) * 0.5;
  float threshold = mix(-extent - 0.10, extent + 0.10, progress);
  float edge = along - threshold + ripple;
  float reveal = 1.0 - smoothstep(-0.055, 0.055, edge);
  float foam = 1.0 - smoothstep(0.015, 0.13, abs(edge));
  vec2 flowUv = vec2(direction.x / max(ratio, 0.001), direction.y);
  float distortion = ripple * envelope * (0.15 + foam * 0.85);
  vec4 from = getFromColor(uv + flowUv * distortion);
  vec4 to = getToColor(uv - flowUv * distortion);
  vec3 color = mix(from.rgb, to.rgb, reveal);
  color += vec3(0.45, 0.75, 0.82) * foam * envelope * 0.22;
  return vec4(color, mix(from.a, to.a, reveal));
}
