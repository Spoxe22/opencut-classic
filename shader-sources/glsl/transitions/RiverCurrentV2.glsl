// Depth-weighted procedural river-current transition by slideshow_ai.

uniform vec2 flow_direction; // = vec2(1.0, 0.15)
uniform float ripple_strength; // = 0.012
uniform float depth_strength; // = 0.75

const float PI = 3.141592653589793;

float hash(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
  return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x),
    f.y
  );
}

vec2 flowField(vec2 p) {
  const float e = 0.08;
  float dx = noise(p + vec2(e, 0.0)) - noise(p - vec2(e, 0.0));
  float dy = noise(p + vec2(0.0, e)) - noise(p - vec2(0.0, e));
  return vec2(-dy, dx) / max(length(vec2(dx, dy)), 0.001);
}

vec4 transition(vec2 uv) {
  vec2 direction = flow_direction / max(length(flow_direction), 0.001);
  vec2 normal = vec2(-direction.y, direction.x);
  vec2 centered = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  float along = dot(centered, direction);
  float across = dot(centered, normal);
  float envelope = sin(PI * progress);
  float depth = smoothstep(0.06, 1.0, uv.y);
  float depthScale = mix(0.35, 1.0 + depth_strength, depth);
  vec2 field = flowField(centered * 3.6 + direction * progress * 3.2);
  vec2 currentDirection = mix(direction, field, 0.62);
  currentDirection /= max(length(currentDirection), 0.001);

  float extent = abs(direction.x) * ratio * 0.5 + abs(direction.y) * 0.5;
  float threshold = mix(-extent - 0.10, extent + 0.10, progress);
  float meander = (noise(centered * 4.0 + field * 1.7 + progress * 2.0) - 0.5);
  meander *= 0.12 * mix(0.35, 1.0, depth);
  float edge = along - threshold + meander;
  float reveal = 1.0 - smoothstep(-0.055, 0.055, edge);
  float foam = 1.0 - smoothstep(0.015, 0.13, abs(edge));

  vec2 flowUv = vec2(currentDirection.x / max(ratio, 0.001), currentDirection.y);
  float distortion = ripple_strength * envelope * depthScale * (0.05 + foam * 0.95);
  vec4 from = getFromColor(uv + flowUv * distortion);
  vec4 to = getToColor(uv - flowUv * distortion);
  float caustic = pow(max(0.0, sin((across + meander) * 92.0 + progress * 19.0 + field.x * 8.0)), 9.0);
  caustic *= foam * envelope * mix(0.35, 1.0, depth);

  vec3 color = mix(from.rgb, to.rgb, reveal);
  color += vec3(0.44, 0.76, 0.84) * foam * envelope * 0.14;
  color += vec3(0.72, 0.92, 1.0) * caustic * 0.18;
  return vec4(color, mix(from.a, to.a, reveal));
}
