struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) tex_coord: vec2f,
}

struct TransitionUniforms {
    resolution: vec2f,
    progress: f32,
    aspect_ratio: f32,
    preset: u32,
    _padding: vec3u,
    params0: vec4f,
    params1: vec4f,
    params2: vec4f,
    params3: vec4f,
}

@group(0) @binding(0) var from_texture: texture_2d<f32>;
@group(0) @binding(1) var from_sampler: sampler;
@group(1) @binding(0) var to_texture: texture_2d<f32>;
@group(1) @binding(1) var to_sampler: sampler;
@group(2) @binding(0) var<uniform> uniforms: TransitionUniforms;

fn cover_uv(uv: vec2f, dimensions: vec2u) -> vec2f {
    let source_ratio = f32(dimensions.x) / max(f32(dimensions.y), 1.0);
    var scale = vec2f(1.0);
    if (source_ratio > uniforms.aspect_ratio) { scale.x = uniforms.aspect_ratio / source_ratio; }
    else { scale.y = source_ratio / uniforms.aspect_ratio; }
    return (uv - 0.5) * scale + 0.5;
}

fn from_color(uv: vec2f) -> vec4f {
    return textureSampleLevel(from_texture, from_sampler, cover_uv(clamp(uv, vec2f(0.0), vec2f(1.0)), textureDimensions(from_texture)), 0.0);
}

fn to_color(uv: vec2f) -> vec4f {
    return textureSampleLevel(to_texture, to_sampler, cover_uv(clamp(uv, vec2f(0.0), vec2f(1.0)), textureDimensions(to_texture)), 0.0);
}

fn hash21(p: vec2f) -> f32 { return fract(sin(dot(p, vec2f(12.9898, 78.233))) * 43758.5453); }

fn dreamy(uv: vec2f, burn: f32, directional: f32) -> vec4f {
    let p = uniforms.progress;
    let peak = 1.0 - abs(p * 2.0 - 1.0);
    let rotation = uniforms.params0.x * 0.0174532925 * peak;
    let scale = mix(1.0, max(uniforms.params0.y, 0.01), peak);
    let centered = (uv - 0.5) / scale;
    let c = cos(rotation);
    let s = sin(rotation);
    let sample_uv = vec2f(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + 0.5;
    var color = select(from_color(sample_uv), to_color(sample_uv), p >= 0.5);
    if (burn > 0.0) {
        let direction = normalize(vec2f(uniforms.params0.w, uniforms.params1.x) + vec2f(0.0001));
        let travel = dot((uv - 0.5) * vec2f(uniforms.aspect_ratio, 1.0), direction) - mix(-0.7, 0.7, p);
        let noise = hash21(floor(uv * uniforms.resolution / 24.0) + p * 11.0);
        let leak = exp(-travel * travel * mix(10.0, 30.0, directional)) * (0.55 + noise * 0.45) * sin(p * 3.14159265);
        let fire = mix(vec3f(1.0, 0.08, 0.0), vec3f(1.0, 0.85, 0.3), leak);
        color = vec4f(mix(color.rgb, 1.0 - (1.0 - color.rgb) * (1.0 - fire), clamp(leak * uniforms.params0.z, 0.0, 0.92)), color.a);
    }
    return vec4f(clamp(color.rgb + vec3f(pow(peak, 14.0)), vec3f(0.0), vec3f(1.0)), color.a);
}

fn film_roll(uv: vec2f, variant: f32) -> vec4f {
    let p = uniforms.progress;
    let cells = max(uniforms.params0.x, 1.0);
    let strip_width = max(uniforms.params0.y, 0.2);
    let q = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    let scroll = p * cells;
    let local = fract(q.y + scroll + 0.5) - 0.5;
    let incoming = step(hash21(vec2f(floor(q.y + scroll), variant)), p);
    var color = mix(from_color(uv + vec2f(0.0, scroll * 0.035)), to_color(uv - vec2f(0.0, (1.0 - p) * 0.035)), incoming);
    let half_width = uniforms.aspect_ratio * strip_width * 0.5;
    let rail = smoothstep(half_width * 0.72, half_width * 0.76, abs(q.x));
    let perforation = step(0.38, abs(sin((local + 0.5) * 50.265))) * rail;
    var rgb = mix(color.rgb, vec3f(0.035, 0.022, 0.012) + hash21(q * 500.0 + p) * 0.04, rail * 0.88);
    rgb = mix(rgb, vec3f(0.01), perforation);
    return vec4f(rgb, color.a);
}

fn glitch(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let band = floor(uv.y * 24.0);
    let shift = (hash21(vec2f(band, floor(p * 30.0))) - 0.5) * sin(p * 3.14159265) * 0.18;
    let reveal = smoothstep(p - 0.08, p + 0.08, uv.x + shift);
    return mix(from_color(uv + vec2f(shift, 0.0)), to_color(uv - vec2f(shift, 0.0)), reveal);
}

fn river(uv: vec2f, depth: f32) -> vec4f {
    let p = uniforms.progress;
    let direction = normalize(vec2f(uniforms.params0.x, uniforms.params0.y) + vec2f(0.0001));
    let normal = vec2f(-direction.y, direction.x);
    let centered = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    let across = dot(centered, normal);
    let ripple = sin(across * 78.0 - p * 18.0) + sin(across * 33.0 + p * 24.0) * 0.45;
    let displacement = direction * ripple * uniforms.params0.z * sin(p * 3.14159265) * (1.0 + depth * uniforms.params0.w);
    let reveal = smoothstep(p - 0.12, p + 0.12, dot(centered, direction) + 0.5);
    return mix(from_color(uv + displacement), to_color(uv - displacement), reveal);
}

fn tangent_blur(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let amount = sin(p * 3.14159265) * 0.04;
    var a = vec4f(0.0); var b = vec4f(0.0);
    for (var i = 0; i < 8; i += 1) {
        let t = (f32(i) / 7.0 - 0.5) * amount;
        a += from_color(uv + vec2f(t, 0.0)); b += to_color(uv - vec2f(t, 0.0));
    }
    return mix(a / 8.0, b / 8.0, p);
}

@fragment
fn fragment_main(input: VertexOutput) -> @location(0) vec4f {
    let p = clamp(uniforms.progress, 0.0, 1.0);
    if (p <= 0.00001) { return from_color(input.tex_coord); }
    if (p >= 0.99999) { return to_color(input.tex_coord); }
    let id = uniforms.preset;
    if (id == 1u) { return dreamy(input.tex_coord, 0.0, 0.0); }
    if (id == 2u) { return dreamy(input.tex_coord, 1.0, 0.0); }
    if (id == 3u) { return dreamy(input.tex_coord, 1.0, 1.0); }
    if (id >= 4u && id <= 7u) { return film_roll(input.tex_coord, f32(id - 4u)); }
    if (id == 8u) { return glitch(input.tex_coord); }
    if (id == 9u) {
        let outgoing = from_color(input.tex_coord); let incoming = to_color(input.tex_coord);
        let flash = pow(sin(p * 3.14159265), 3.0) * uniforms.params1.x;
        return vec4f(clamp(mix(outgoing.rgb, incoming.rgb, smoothstep(0.70, 0.86, p)) + flash, vec3f(0.0), vec3f(1.0)), mix(outgoing.a, incoming.a, p));
    }
    if (id == 10u) {
        let outgoing = from_color(input.tex_coord); let incoming = to_color(input.tex_coord); let strength = uniforms.params0.x;
        return vec4f(clamp(outgoing.rgb * (1.0 - p + sin(p * 3.14159265) * strength) + incoming.rgb * (p + sin(p * 3.14159265) * strength), vec3f(0.0), vec3f(1.0)), mix(outgoing.a, incoming.a, p));
    }
    if (id == 11u) { return river(input.tex_coord, 0.0); }
    if (id == 12u) { return river(input.tex_coord, 1.0); }
    if (id == 13u) {
        let offset = mix(0.0, 0.55, p); let shifted = input.tex_coord + vec2f(0.0, select(offset, offset - 1.0, input.tex_coord.y > 0.5));
        return mix(from_color(shifted), to_color(shifted), step(0.5, p));
    }
    if (id == 14u) { return tangent_blur(input.tex_coord); }
    return mix(from_color(input.tex_coord), to_color(input.tex_coord), p);
}
