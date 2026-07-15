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

fn burn_hash(point_input: vec2f) -> f32 {
    var point = fract(point_input * vec2f(123.34, 456.21));
    point += dot(point, point + 45.32);
    return fract(point.x * point.y);
}

fn burn_noise(point: vec2f) -> f32 {
    let cell = floor(point);
    var local = fract(point);
    local = local * local * (3.0 - 2.0 * local);
    return mix(
        mix(burn_hash(cell), burn_hash(cell + vec2f(1.0, 0.0)), local.x),
        mix(burn_hash(cell + vec2f(0.0, 1.0)), burn_hash(cell + 1.0), local.x),
        local.y,
    );
}

fn burn_fbm(point_input: vec2f) -> f32 {
    var point = point_input;
    var value = 0.0;
    var amplitude = 0.55;
    for (var i = 0; i < 4; i += 1) {
        value += amplitude * burn_noise(point);
        point = point * 2.03 + vec2f(17.1, 9.2);
        amplitude *= 0.5;
    }
    return value;
}

fn dreamy_burn(uv: vec2f, directional: bool) -> vec4f {
    let p = uniforms.progress;
    let phase = select((p - 0.5) * 2.0, p * 2.0, p < 0.5);
    let peak_phase = select(1.0 - phase, phase, p < 0.5);
    let rotation = uniforms.params0.x * 0.039269908169872415;
    let angle_offset = select(mix(-rotation, 0.0, phase), mix(0.0, rotation, phase), p < 0.5);
    let scale = select(mix(uniforms.params0.y, 1.0, phase), mix(1.0, uniforms.params0.y, phase), p < 0.5);
    var sample_uv = (uv - 0.5) / scale * vec2f(uniforms.aspect_ratio, 1.0);
    let angle = atan2(sample_uv.y, sample_uv.x) + angle_offset;
    let distance = length(sample_uv);
    sample_uv = vec2f(cos(angle) * distance / uniforms.aspect_ratio, sin(angle) * distance) + 0.5;
    let source = select(to_color(sample_uv), from_color(sample_uv), p < 0.5);
    let envelope = pow(sin(p * 3.141592653589793), 0.7);
    let burn_uv = vec2f(uv.x * uniforms.aspect_ratio, uv.y);
    let hotspot = vec2f(
        mix(-0.15, uniforms.aspect_ratio + 0.15, p),
        0.5 + sin(p * 8.0) * 0.22,
    );
    let radial = 1.0 - smoothstep(0.05, 0.82, length(burn_uv - hotspot));
    let texture_field = burn_fbm(burn_uv * 3.5 + vec2f(p * 4.2, -p * 2.7));
    var field = radial * 0.75 + texture_field * 0.65;
    if (directional) {
        let direction_input = vec2f(uniforms.params0.w, uniforms.params1.x);
        let direction = direction_input / max(length(direction_input), 0.001);
        let normal = vec2f(-direction.y, direction.x);
        let centered = burn_uv - vec2f(uniforms.aspect_ratio * 0.5, 0.5);
        let along = dot(centered, direction) - mix(-0.7, 0.7, p);
        let across = dot(centered, normal);
        var leak = exp(-along * along * 30.0);
        leak *= 0.55 + 0.45 * burn_fbm(vec2f(across * 5.0, p * 6.0));
        field = radial * 0.35 + leak * (0.55 + texture_field * 0.65);
    }
    field = clamp(field, 0.0, 1.0) * envelope;
    let outer = smoothstep(0.08, 0.48, field);
    let middle = smoothstep(0.34, 0.72, field);
    let core = smoothstep(0.66, 0.94, field);
    var burn_color = mix(vec3f(1.0, 0.04, 0.0), vec3f(1.0, 0.48, 0.02), middle);
    burn_color = mix(burn_color, vec3f(1.0, 0.96, 0.72), core);
    let luminance = dot(source.rgb, vec3f(0.2126, 0.7152, 0.0722));
    let strength = uniforms.params0.z;
    let saturated = mix(vec3f(luminance), source.rgb, 1.0 + envelope * strength * 0.65);
    let screened = 1.0 - (1.0 - saturated) * (1.0 - burn_color);
    var color = mix(saturated, screened, clamp(outer * strength, 0.0, 0.92));
    color += burn_color * (middle * 0.28 + core * 0.55) * strength;
    let flash = select(peak_phase, pow(peak_phase, 14.0), directional);
    return vec4f(color + flash, source.a);
}

fn glsl_mod(value: f32, divisor: f32) -> f32 {
    return value - divisor * floor(value / divisor);
}

fn film_frame_seed(value: f32) -> f32 {
    return fract(sin(value * 78.233) * 43758.5453);
}

fn organic_roll_progress(value: f32) -> f32 {
    let t = clamp((value - 0.10) / 0.90, 0.0, 1.0);
    return clamp(t + 0.04 * sin(6.2831853 * t), 0.0, 1.0);
}

fn gate_weave(value: f32) -> vec2f {
    return vec2f(
        0.006 * sin(value * 37.0) + 0.002 * sin(value * 83.0),
        0.003 * sin(value * 19.0),
    );
}

fn film_perforations(
    q: vec2f,
    scroll: f32,
    strip_half_width: f32,
    rail_width: f32,
    scale: f32,
    cinematic: bool,
) -> f32 {
    let pitch = 0.125;
    let local_y = glsl_mod(q.y + scroll + pitch * 0.5, pitch) - pitch * 0.5;
    let hole_half_size = select(
        vec2f(rail_width * 0.25, pitch * 0.22),
        vec2f(rail_width * 0.19, pitch * 0.18) * scale,
        cinematic,
    );
    let radius = select(0.008, 0.003, cinematic);
    let left = rounded_box(
        vec2f(q.x, local_y),
        vec2f(-strip_half_width + rail_width * 0.55, 0.0),
        hole_half_size,
        radius,
    );
    let right = rounded_box(
        vec2f(q.x, local_y),
        vec2f(strip_half_width - rail_width * 0.55, 0.0),
        hole_half_size,
        radius,
    );
    return clamp(left + right, 0.0, 1.0);
}

fn film_center_saturation(color: vec4f, screen_y: f32, frame_center_y: f32, city: bool) -> vec4f {
    var saturation = 1.0 - smoothstep(0.15, 0.58, abs(frame_center_y));
    if (city) {
        let scan_saturation = 1.0 - smoothstep(0.025, 0.24, abs(screen_y));
        let full_frame_saturation = 1.0 - smoothstep(0.0, 0.18, abs(frame_center_y));
        saturation = max(scan_saturation, full_frame_saturation);
    }
    let luminance = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));
    return vec4f(mix(vec3f(luminance), color.rgb, saturation), color.a);
}

fn film_frame_color(uv: vec2f, incoming: f32, defocus: f32) -> vec4f {
    let blur = vec2f(1.25 / uniforms.resolution.x, 2.5 / uniforms.resolution.y) * defocus;
    var color = mix(from_color(uv), to_color(uv), incoming) * 0.50;
    color += mix(from_color(uv + vec2f(blur.x, 0.0)), to_color(uv + vec2f(blur.x, 0.0)), incoming) * 0.125;
    color += mix(from_color(uv - vec2f(blur.x, 0.0)), to_color(uv - vec2f(blur.x, 0.0)), incoming) * 0.125;
    color += mix(from_color(uv + vec2f(0.0, blur.y)), to_color(uv + vec2f(0.0, blur.y)), incoming) * 0.125;
    color += mix(from_color(uv - vec2f(0.0, blur.y)), to_color(uv - vec2f(0.0, blur.y)), incoming) * 0.125;
    return color;
}

fn cinema_print(color: vec4f) -> vec4f {
    let luminance = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));
    var printed = mix(vec3f(luminance), color.rgb, 0.88);
    printed = (printed - 0.5) * 0.88 + 0.5;
    let shadow = 1.0 - smoothstep(0.0, 0.22, luminance);
    let highlight = smoothstep(0.65, 1.0, luminance);
    printed += 0.025 * shadow;
    printed = mix(printed, vec3f(0.88), highlight * 0.16);
    return vec4f(clamp(printed, vec3f(0.0), vec3f(1.0)), color.a);
}

fn city_morning(q: vec2f) -> vec4f {
    let sky = 1.0 - smoothstep(-0.12, 0.40, q.y);
    var surface = mix(vec3f(0.56, 0.54, 0.49), vec3f(0.68, 0.81, 0.90), sky);
    let city_x = q.x / uniforms.aspect_ratio + 0.5;
    let building_index = floor(city_x * 7.0);
    let roof = -0.04 + hash21(vec2f(building_index, 3.1)) * 0.27;
    let building = smoothstep(roof - 0.018, roof + 0.018, q.y);
    let facade = 0.84 + hash21(vec2f(building_index, 9.4)) * 0.12;
    surface = mix(surface, vec3f(0.60, 0.61, 0.58) * facade, building * 0.62);
    let vignette = 1.0 - smoothstep(0.18, 0.80, length(vec2f(q.x / uniforms.aspect_ratio, q.y)));
    return vec4f(surface * mix(0.48, 0.82, vignette), 1.0);
}

fn film_roll(uv: vec2f, variant: u32) -> vec4f {
    let p = uniforms.progress;
    let backdrop_q = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    var q = backdrop_q;
    if (variant > 0u) { q -= gate_weave(p); }
    let strip_half_width = uniforms.aspect_ratio * uniforms.params0.y * 0.5;
    let rail_width = strip_half_width * 0.17;
    let image_half_width = strip_half_width - rail_width * 1.35;
    let image_half_height = image_half_width / uniforms.aspect_ratio;
    let frame_pitch = image_half_height * 2.0 + 0.055;
    let linear_progress = clamp((p - 0.10) / 0.90, 0.0, 1.0);
    let roll_progress = select(linear_progress, organic_roll_progress(p), variant > 0u);
    let scroll = roll_progress * uniforms.params0.x * frame_pitch;
    let frame_index = floor((q.y + scroll + frame_pitch * 0.5) / frame_pitch);
    let frame_center_y = frame_index * frame_pitch - scroll;
    let frame_center = vec2f(0.0, frame_center_y);
    let image_half_size = vec2f(image_half_width, image_half_height);
    let strip_mask = step(abs(q.x), strip_half_width);
    let cinematic = variant >= 2u;
    let outer_padding = select(0.014, 0.009, cinematic);
    let outer_radius = select(0.022, 0.008, cinematic);
    let image_radius = select(0.012, 0.004, cinematic);
    let outer_frame = rounded_box(q, frame_center, image_half_size + outer_padding, outer_radius);
    let image_mask = rounded_box(q, frame_center, image_half_size, image_radius);
    let frame_shadow = rounded_box(
        q,
        frame_center + select(vec2f(0.004, 0.018), vec2f(0.003, 0.014), cinematic),
        image_half_size + select(0.020, 0.015, cinematic),
        select(0.028, 0.014, cinematic),
    );
    let image_uv = (q - frame_center) / (image_half_size * 2.0) + 0.5;
    let incoming = step(film_frame_seed(frame_index), smoothstep(0.20, 0.80, roll_progress));
    let focus = 1.0 - smoothstep(0.12, 0.62, abs(frame_center_y));
    var image = mix(from_color(image_uv), to_color(image_uv), incoming);
    if (variant > 0u) { image = film_frame_color(image_uv, incoming, 1.0 - focus); }
    if (variant == 3u) { image = cinema_print(image); }
    image = film_center_saturation(image, q.y, frame_center_y, variant == 3u);

    let black = vec4f(0.0, 0.0, 0.0, 1.0);
    let film_base = select(vec3f(0.055, 0.047, 0.035), vec3f(0.018, 0.016, 0.014), cinematic);
    let film_edge = select(vec4f(0.22, 0.18, 0.12, 1.0), vec4f(0.13, 0.09, 0.05, 1.0), cinematic);
    var strip = vec4f(film_base, 1.0);
    if (variant > 0u) {
        let edge_curve = smoothstep(0.55, 1.0, abs(q.x) / strip_half_width);
        strip = vec4f(film_base * mix(1.0, select(0.58, 0.62, cinematic), edge_curve), 1.0);
    }
    if (cinematic) {
        let rail_mask = step(image_half_width + 0.012, abs(q.x)) * strip_mask;
        let grain = hash21(q * uniforms.resolution.y + vec2f(p * 31.0, p * 47.0)) - 0.5;
        let sheen = 0.5 + 0.5 * sin(q.y * 22.0 - p * 10.0);
        strip = vec4f(strip.rgb + grain * 0.026 * strip_mask, 1.0);
        if (variant == 2u) {
            strip = vec4f(strip.rgb + vec3f(0.035, 0.020, 0.006) * sheen * rail_mask, 1.0);
        } else {
            let rail_patina = hash21(floor(q * uniforms.resolution.y * vec2f(0.028, 0.022))) - 0.5;
            let rail_streak = hash21(vec2f(floor(q.x * uniforms.resolution.y * 0.16), floor(q.y * uniforms.resolution.y * 0.013))) - 0.5;
            let rail_wear = smoothstep(0.13, 0.50, abs(rail_patina + rail_streak * 0.85));
            let rail_scuff = step(0.78, hash21(vec2f(floor(q.x * uniforms.resolution.y * 0.35), floor(q.y * uniforms.resolution.y * 0.035))));
            var rgb = strip.rgb + vec3f(0.085, 0.048, 0.017) * (0.32 + sheen * 0.32 + rail_patina * 0.80) * rail_mask;
            rgb *= 1.0 - rail_wear * rail_mask * 0.42;
            rgb -= vec3f(0.035, 0.020, 0.008) * rail_scuff * rail_mask;
            strip = vec4f(rgb, 1.0);
        }
    }
    strip = mix(strip, film_edge, outer_frame);
    if (variant > 0u) { strip = mix(strip, black, frame_shadow * (1.0 - image_mask) * select(0.38, 0.42, cinematic)); }
    strip = mix(strip, image, image_mask);
    if (variant == 3u) {
        let flicker = 0.95 + 0.035 * sin(p * 83.0) + 0.018 * sin(p * 171.0);
        let emulsion_grain = hash21(q * uniforms.resolution.y * 0.75 + vec2f(p * 71.0, p * 43.0)) - 0.5;
        let scratch_column = step(0.993, hash21(vec2f(floor(q.x * uniforms.resolution.y * 0.5), floor(p * 12.0))));
        let scratch = scratch_column * (0.25 + 0.75 * step(0.45, hash21(vec2f(floor(q.y * uniforms.resolution.y * 0.12), floor(p * 12.0)))));
        strip = vec4f(clamp(strip.rgb * flicker + emulsion_grain * 0.045, vec3f(0.0), vec3f(1.0)) * (1.0 - scratch * 0.16), strip.a);
    }
    let holes = film_perforations(q, scroll, strip_half_width, rail_width, 1.0, cinematic);
    if (cinematic) {
        let hole_rim = clamp(film_perforations(q, scroll, strip_half_width, rail_width, 1.35, true) - holes, 0.0, 1.0);
        strip = mix(strip, vec4f(0.12, 0.075, 0.03, 1.0), hole_rim * 0.45);
    }
    if (variant == 3u) {
        return mix(city_morning(backdrop_q), strip, strip_mask * (1.0 - holes));
    }
    strip = mix(strip, black, holes);
    return mix(black, strip, strip_mask);
}

fn glitch(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let ease1 = select(
        select(-0.5 * pow(2.0, 10.0 - p * 20.0) + 1.0, 0.5 * pow(2.0, 20.0 * p - 10.0), p < 0.5),
        p,
        p == 0.0 || p == 1.0,
    );
    let ease2 = select(1.0 - pow(2.0, -10.0 * p), p, p == 1.0);
    let outgoing = from_color(uv);
    let incoming = to_color(uv);
    let outgoing_offset = (outgoing.xy * (0.33 - 0.7) + 0.7 * 0.33) * (1.0 - ease1);
    let incoming_offset = (incoming.xy * (0.33 - 0.5) + 0.5 * 0.33) * ease2;
    let displaced_incoming = to_color(uv + outgoing_offset);
    var displaced_outgoing = from_color(uv + incoming_offset);
    let gray = dot(min(displaced_outgoing, displaced_incoming).rgb, vec3f(0.299, 0.587, 0.114));
    displaced_outgoing = vec4f(vec3f(gray), 1.0) * 2.0;
    let color1 = mix(outgoing, displaced_outgoing, smoothstep(0.0, 0.5, p));
    let color2 = mix(incoming, displaced_incoming, 1.0 - smoothstep(0.5, 1.0, p));
    return mix(color1, color2, ease1);
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

fn river_hash(point_input: vec2f) -> f32 {
    let point = fract(point_input * vec2f(127.1, 311.7));
    return fract(sin(dot(point, vec2f(269.5, 183.3))) * 43758.5453);
}

fn river_noise(point: vec2f) -> f32 {
    let cell = floor(point);
    var local = fract(point);
    local = local * local * (3.0 - 2.0 * local);
    return mix(
        mix(river_hash(cell), river_hash(cell + vec2f(1.0, 0.0)), local.x),
        mix(river_hash(cell + vec2f(0.0, 1.0)), river_hash(cell + 1.0), local.x),
        local.y,
    );
}

fn river_flow_field(point: vec2f) -> vec2f {
    let epsilon = 0.08;
    let dx = river_noise(point + vec2f(epsilon, 0.0)) - river_noise(point - vec2f(epsilon, 0.0));
    let dy = river_noise(point + vec2f(0.0, epsilon)) - river_noise(point - vec2f(0.0, epsilon));
    return vec2f(-dy, dx) / max(length(vec2f(dx, dy)), 0.001);
}

fn river_current_v2(uv: vec2f) -> vec4f {
    let p = uniforms.progress;
    let direction_input = vec2f(uniforms.params0.x, uniforms.params0.y);
    let direction = direction_input / max(length(direction_input), 0.001);
    let normal = vec2f(-direction.y, direction.x);
    let centered = vec2f((uv.x - 0.5) * uniforms.aspect_ratio, uv.y - 0.5);
    let along = dot(centered, direction);
    let across = dot(centered, normal);
    let envelope = sin(3.141592653589793 * p);
    let depth = smoothstep(0.06, 1.0, uv.y);
    let depth_scale = mix(0.35, 1.0 + uniforms.params0.w, depth);
    let field = river_flow_field(centered * 3.6 + direction * p * 3.2);
    var current_direction = mix(direction, field, 0.62);
    current_direction /= max(length(current_direction), 0.001);
    let extent = abs(direction.x) * uniforms.aspect_ratio * 0.5 + abs(direction.y) * 0.5;
    let threshold = mix(-extent - 0.10, extent + 0.10, p);
    var meander = river_noise(centered * 4.0 + field * 1.7 + p * 2.0) - 0.5;
    meander *= 0.12 * mix(0.35, 1.0, depth);
    let edge = along - threshold + meander;
    let reveal = 1.0 - smoothstep(-0.055, 0.055, edge);
    let foam = 1.0 - smoothstep(0.015, 0.13, abs(edge));
    let flow_uv = vec2f(current_direction.x / max(uniforms.aspect_ratio, 0.001), current_direction.y);
    let distortion = uniforms.params0.z * envelope * depth_scale * (0.05 + foam * 0.95);
    let outgoing = from_color(uv + flow_uv * distortion);
    let incoming = to_color(uv - flow_uv * distortion);
    var caustic = pow(max(0.0, sin((across + meander) * 92.0 + p * 19.0 + field.x * 8.0)), 9.0);
    caustic *= foam * envelope * mix(0.35, 1.0, depth);
    var color = mix(outgoing.rgb, incoming.rgb, reveal);
    color += vec3f(0.44, 0.76, 0.84) * foam * envelope * 0.14;
    color += vec3f(0.72, 0.92, 1.0) * caustic * 0.18;
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
    let id = uniforms.preset;
    let film_roll_preset = id >= 4u && id <= 7u;
    if (p <= 0.00001 && !film_roll_preset) { return from_color(input.tex_coord); }
    if (p >= 0.99999 && !film_roll_preset) { return to_color(input.tex_coord); }
    if (id == 1u) { return dreamy_zoom(input.tex_coord); }
    if (id == 2u) { return dreamy_burn(input.tex_coord, false); }
    if (id == 3u) { return dreamy_burn(input.tex_coord, true); }
    if (film_roll_preset) { return film_roll(input.tex_coord, id - 4u); }
    if (id == 8u) { return glitch(input.tex_coord); }
    if (id == 9u) { return motion_machine_flash(input.tex_coord); }
    if (id == 10u) {
        let outgoing = from_color(input.tex_coord); let incoming = to_color(input.tex_coord); let strength = uniforms.params0.x;
        return vec4f(clamp(outgoing.rgb * outgoing.a * (1.0 - p + sin(p * 3.14159265) * strength) + incoming.rgb * incoming.a * (p + sin(p * 3.14159265) * strength), vec3f(0.0), vec3f(1.0)), mix(outgoing.a, incoming.a, p));
    }
    if (id == 11u) { return river_current(input.tex_coord); }
    if (id == 12u) { return river_current_v2(input.tex_coord); }
    if (id == 13u) { return stereo_viewer_vertical(input.tex_coord); }
    if (id == 14u) { return tangent_blur(input.tex_coord); }
    return mix(from_color(input.tex_coord), to_color(input.tex_coord), p);
}
