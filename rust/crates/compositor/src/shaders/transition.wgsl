struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) tex_coord: vec2f,
}

struct TransitionUniforms {
    resolution: vec2f,
    progress: f32,
    aspect_ratio: f32,
    preset: u32,
    _padding0: u32,
    _padding1: u32,
    _padding2: u32,
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

fn dreamy_zoom(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let phase = select((p - 0.5) * 2.0, p * 2.0, p < 0.5);
    let rotation = uniforms.params0.x * 0.039269908169872415;
    let angle_offset = select(mix(-rotation, 0.0, phase), mix(0.0, rotation, phase), p < 0.5);
    let scale = select(mix(uniforms.params0.y, 1.0, phase), mix(1.0, uniforms.params0.y, phase), p < 0.5);
    var point = (uv - 0.5) / scale * vec2f(uniforms.aspect_ratio, 1.0);
    let angle = atan2(point.y, point.x) + angle_offset;
    let distance = length(point);
    point = vec2f(cos(angle) * distance / uniforms.aspect_ratio, sin(angle) * distance) + 0.5;
    let color = select(to_color(point), from_color(point), p < 0.5);
    let flash = select(1.0 - phase, phase, p < 0.5);
    return color + vec4f(flash);
}

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

fn river_current(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let direction = normalize(vec2f(uniforms.params0.x, uniforms.params0.y) + vec2f(0.000001));
    let normal = vec2f(-direction.y, direction.x);
    let centered = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    let along = dot(centered, direction);
    let across = dot(centered, normal);
    let envelope = sin(3.141592653589793 * p);
    var ripple = sin(across * 78.0 - p * 18.0);
    ripple += sin(across * 33.0 + p * 24.0) * 0.45;
    ripple *= uniforms.params0.z;
    let extent = abs(direction.x) * uniforms.aspect_ratio * 0.5 + abs(direction.y) * 0.5;
    let threshold = mix(-extent - 0.10, extent + 0.10, p);
    let edge = along - threshold + ripple;
    let reveal = 1.0 - smoothstep(-0.055, 0.055, edge);
    let foam = 1.0 - smoothstep(0.015, 0.13, abs(edge));
    let flow_uv = vec2f(direction.x / max(uniforms.aspect_ratio, 0.001), direction.y);
    let distortion = ripple * envelope * (0.15 + foam * 0.85);
    let outgoing = from_color(uv + flow_uv * distortion);
    let incoming = to_color(uv - flow_uv * distortion);
    var color = mix(outgoing.rgb, incoming.rgb, reveal);
    color += vec3f(0.45, 0.75, 0.82) * foam * envelope * 0.22;
    return vec4f(color, mix(outgoing.a, incoming.a, reveal));
}

fn luma(color: vec3f) -> f32 {
    return dot(color, vec3f(0.299, 0.587, 0.114));
}

fn bright_seed(color: vec3f) -> f32 {
    return smoothstep(uniforms.params0.x, 1.0, luma(color));
}

fn expanded_source_mask(uv: vec2f, radius: f32) -> f32 {
    let r = vec2f(radius / max(uniforms.aspect_ratio, 0.0001), radius);
    var mask = bright_seed(from_color(uv).rgb);
    mask = max(mask, bright_seed(from_color(uv + vec2f(r.x, 0.0)).rgb));
    mask = max(mask, bright_seed(from_color(uv - vec2f(r.x, 0.0)).rgb));
    mask = max(mask, bright_seed(from_color(uv + vec2f(0.0, r.y)).rgb));
    mask = max(mask, bright_seed(from_color(uv - vec2f(0.0, r.y)).rgb));
    mask = max(mask, bright_seed(from_color(uv + r).rgb));
    mask = max(mask, bright_seed(from_color(uv + vec2f(-r.x, r.y)).rgb));
    mask = max(mask, bright_seed(from_color(uv + vec2f(r.x, -r.y)).rgb));
    mask = max(mask, bright_seed(from_color(uv - r).rgb));
    mask = max(mask, bright_seed(from_color(uv + vec2f(2.0 * r.x, 0.0)).rgb));
    mask = max(mask, bright_seed(from_color(uv - vec2f(2.0 * r.x, 0.0)).rgb));
    mask = max(mask, bright_seed(from_color(uv + vec2f(0.0, 2.0 * r.y)).rgb));
    mask = max(mask, bright_seed(from_color(uv - vec2f(0.0, 2.0 * r.y)).rgb));
    return mask;
}

fn degrade_highlights(color: vec3f, amount: f32) -> vec3f {
    let luminance = luma(color);
    let highlight = smoothstep(uniforms.params0.z, 1.0, luminance);
    let gray = vec3f(luminance);
    let saturated = clamp(mix(gray, color, 1.0 + uniforms.params1.x * amount), vec3f(0.0), vec3f(1.0));
    let clipped = min(saturated * (1.0 + 0.18 * amount * highlight), vec3f(1.0));
    let maximum = max(max(clipped.r, clipped.g), clipped.b);
    let flattened = mix(clipped, vec3f(maximum), 0.32 * amount * highlight);
    let compressed = mix(flattened, vec3f(luma(flattened)), 0.18 * amount * highlight);
    return mix(color, compressed, amount * highlight);
}

fn motion_machine_flash(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let outgoing = from_color(uv);
    let incoming = to_color(uv);
    let radius = uniforms.params0.y * smoothstep(0.04, 0.72, p);
    let fill_mask = smoothstep(0.0, 1.0, expanded_source_mask(uv, radius));
    let damage = smoothstep(0.10, 0.66, p) * fill_mask;
    let damaged_outgoing = mix(
        outgoing.rgb,
        degrade_highlights(outgoing.rgb, uniforms.params0.w),
        damage,
    );
    let damaged_incoming = degrade_highlights(incoming.rgb, uniforms.params0.w);
    let recovered_incoming = mix(damaged_incoming, incoming.rgb, smoothstep(0.82, 1.0, p));
    let dissolve = smoothstep(0.70, 0.82, p);
    return vec4f(mix(damaged_outgoing, recovered_incoming, dissolve), mix(outgoing.a, incoming.a, dissolve));
}

fn rounded_box(point: vec2f, center: vec2f, half_size: vec2f, radius: f32) -> f32 {
    let d = abs(point - center) - half_size + radius;
    let distance = length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - radius;
    let antialias = 1.5 / uniforms.resolution.y;
    return 1.0 - smoothstep(-antialias, antialias, distance);
}

fn viewer_sample_uv(local_input: vec2f, half_size: vec2f) -> vec2f {
    var local = local_input;
    let card_ratio = half_size.x / half_size.y;
    local.y = (local.y - 0.5) * (uniforms.aspect_ratio / card_ratio) + 0.5;
    return local;
}

fn full_stereo_card(uv: vec2f, incoming: bool, amount: f32, radius: f32) -> vec4f {
    let q = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    let scale = mix(1.0, uniforms.params0.x, amount);
    let half_size = vec2f(uniforms.aspect_ratio, 1.0) * 0.5 * scale;
    let mask = rounded_box(q, vec2f(0.0), half_size, radius * amount);
    let sample_uv = (uv - 0.5) / scale + 0.5;
    let source = select(from_color(sample_uv), to_color(sample_uv), incoming);
    return mix(vec4f(0.0, 0.0, 0.0, 1.0), source, mask);
}

fn stacked_stereo_cards(uv: vec2f, incoming: bool, amount: f32, radius: f32) -> vec4f {
    let q = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    let offset = mix(0.22, 0.64, amount);
    let half_size = vec2f(uniforms.aspect_ratio * 0.45, 0.18) * mix(1.0, 0.78, amount);
    let card_radius = min(radius, min(half_size.x, half_size.y) * 0.72);
    let top_center = vec2f(0.0, -offset);
    let bottom_center = vec2f(0.0, offset);
    let top_mask = rounded_box(q, top_center, half_size, card_radius);
    let bottom_mask = rounded_box(q, bottom_center, half_size, card_radius);
    let top_uv = viewer_sample_uv((q - top_center) / half_size * 0.5 + 0.5, half_size);
    let bottom_uv = viewer_sample_uv((q - bottom_center) / half_size * 0.5 + 0.5, half_size);
    let top = select(from_color(top_uv), to_color(top_uv), incoming);
    let bottom = select(from_color(bottom_uv), to_color(bottom_uv), incoming);
    var cards = vec4f(0.0, 0.0, 0.0, 1.0);
    cards = mix(cards, top, top_mask);
    return mix(cards, bottom, bottom_mask);
}

fn stereo_viewer_vertical(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let radius = uniforms.params0.y * min(uniforms.aspect_ratio, 1.0);
    if (p < 0.12) { return full_stereo_card(uv, false, p / 0.12, radius); }
    if (p < 0.44) { return stacked_stereo_cards(uv, false, (p - 0.12) / 0.32, radius); }
    if (p < 0.56) { return vec4f(0.0, 0.0, 0.0, 1.0); }
    if (p < 0.88) { return stacked_stereo_cards(uv, true, 1.0 - (p - 0.56) / 0.32, radius); }
    return full_stereo_card(uv, true, (1.0 - p) / 0.12, radius);
}

fn cubic_a(a1: f32, a2: f32) -> f32 { return 1.0 - 3.0 * a2 + 3.0 * a1; }
fn cubic_b(a1: f32, a2: f32) -> f32 { return 3.0 * a2 - 6.0 * a1; }
fn cubic_c(a1: f32) -> f32 { return 3.0 * a1; }
fn cubic_slope(t: f32, a1: f32, a2: f32) -> f32 { return 3.0 * cubic_a(a1, a2) * t * t + 2.0 * cubic_b(a1, a2) * t + cubic_c(a1); }
fn cubic_value(t: f32, a1: f32, a2: f32) -> f32 { return ((cubic_a(a1, a2) * t + cubic_b(a1, a2)) * t + cubic_c(a1)) * t; }

fn cubic_t_for_x(x: f32, x1: f32, x2: f32) -> f32 {
    var guess = x;
    for (var i = 0; i < 4; i += 1) {
        let slope = cubic_slope(guess, x1, x2);
        if (slope == 0.0) { return guess; }
        guess -= (cubic_value(guess, x1, x2) - x) / slope;
    }
    return guess;
}

fn tangent_easing(x: f32) -> f32 { return cubic_value(cubic_t_for_x(x, 0.68, 0.17), 0.01, 0.98); }
fn rotate_uv(uv_input: vec2f, angle: f32) -> vec2f {
    let uv = uv_input - vec2f(1.0, 0.0);
    let sine = sin(angle);
    let cosine = cos(angle);
    return vec2f(cosine * uv.x + sine * uv.y, -sine * uv.x + cosine * uv.y) + vec2f(1.0, 0.0);
}

fn tangent_blur_source(uv: vec2f, speed: vec2f, incoming: bool) -> vec4f {
    var color = vec3f(0.0);
    var total = 0.0;
    let offset = hash21(uv);
    for (var i = 0; i <= 20; i += 1) {
        let percent = (f32(i) + offset) / 20.0;
        let weight = 4.0 * (percent - percent * percent);
        let sample_uv = fract(uv + speed * percent);
        let sample_color = select(from_color(sample_uv), to_color(sample_uv), incoming);
        color += sample_color.rgb * weight;
        total += weight;
    }
    return vec4f(color / total, 1.0);
}

fn tangent_blur(uv: vec2f) -> vec4f {
    let easing = tangent_easing(uniforms.progress);
    let blur = exp(-20.0 * (easing - 0.5) * (easing - 0.5));
    let rotation = 3.14159;
    var angle = select(-rotation + rotation * easing, rotation * easing, easing <= 0.5);
    var current = uv;
    current.y /= uniforms.aspect_ratio;
    current = rotate_uv(current, angle);
    current.y *= uniforms.aspect_ratio;
    let interval = 0.0334;
    angle = select(-rotation + rotation * (easing + interval), rotation * (easing + interval), easing <= 0.5);
    var next = uv;
    next.y /= uniforms.aspect_ratio;
    next = rotate_uv(next, angle);
    next.y *= uniforms.aspect_ratio;
    let speed = (next - current) / interval * blur * 0.5;
    return tangent_blur_source(current, speed, easing > 0.5);
}

@fragment
fn fragment_main(input: VertexOutput) -> @location(0) vec4f {
    let p = clamp(uniforms.progress, 0.0, 1.0);
    if (p <= 0.00001) { return from_color(input.tex_coord); }
    if (p >= 0.99999) { return to_color(input.tex_coord); }
    let id = uniforms.preset;
    if (id == 1u) { return dreamy_zoom(input.tex_coord); }
    if (id == 2u) { return dreamy(input.tex_coord, 1.0, 0.0); }
    if (id == 3u) { return dreamy(input.tex_coord, 1.0, 1.0); }
    if (id >= 4u && id <= 7u) { return film_roll(input.tex_coord, f32(id - 4u)); }
    if (id == 8u) { return glitch(input.tex_coord); }
    if (id == 9u) { return motion_machine_flash(input.tex_coord); }
    if (id == 10u) {
        let outgoing = from_color(input.tex_coord); let incoming = to_color(input.tex_coord); let strength = uniforms.params0.x;
        return vec4f(clamp(outgoing.rgb * outgoing.a * (1.0 - p + sin(p * 3.14159265) * strength) + incoming.rgb * incoming.a * (p + sin(p * 3.14159265) * strength), vec3f(0.0), vec3f(1.0)), mix(outgoing.a, incoming.a, p));
    }
    if (id == 11u) { return river_current(input.tex_coord); }
    if (id == 12u) { return river(input.tex_coord, 1.0); }
    if (id == 13u) { return stereo_viewer_vertical(input.tex_coord); }
    if (id == 14u) { return tangent_blur(input.tex_coord); }
    return mix(from_color(input.tex_coord), to_color(input.tex_coord), p);
}
