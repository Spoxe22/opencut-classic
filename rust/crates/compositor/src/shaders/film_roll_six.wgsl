struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) tex_coord: vec2f,
}

struct FilmRollUniforms {
    resolution: vec2f,
    progress: f32,
    aspect_ratio: f32,
    strip_width: f32,
    _padding: vec3f,
}

@group(0) @binding(0) var texture0: texture_2d<f32>;
@group(0) @binding(1) var sampler0: sampler;
@group(0) @binding(2) var texture1: texture_2d<f32>;
@group(0) @binding(3) var sampler1: sampler;
@group(0) @binding(4) var texture2: texture_2d<f32>;
@group(0) @binding(5) var sampler2: sampler;
@group(0) @binding(6) var texture3: texture_2d<f32>;
@group(0) @binding(7) var sampler3: sampler;
@group(0) @binding(8) var texture4: texture_2d<f32>;
@group(0) @binding(9) var sampler4: sampler;
@group(0) @binding(10) var<uniform> uniforms: FilmRollUniforms;

fn sample_photo(index: i32, uv: vec2f) -> vec4f {
    let safe_uv = clamp(uv, vec2f(0.0), vec2f(1.0));
    if (index == 0) { return textureSampleLevel(texture0, sampler0, safe_uv, 0.0); }
    if (index == 1) { return textureSampleLevel(texture1, sampler1, safe_uv, 0.0); }
    if (index == 2) { return textureSampleLevel(texture2, sampler2, safe_uv, 0.0); }
    if (index == 3) { return textureSampleLevel(texture3, sampler3, safe_uv, 0.0); }
    return textureSampleLevel(texture4, sampler4, safe_uv, 0.0);
}

fn hash21(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(12.9898, 78.233))) * 43758.5453);
}

@fragment
fn fragment_main(input: VertexOutput) -> @location(0) vec4f {
    let p = clamp(uniforms.progress, 0.0, 1.0);
    let q = vec2f((input.tex_coord.x - 0.5) * uniforms.aspect_ratio, input.tex_coord.y - 0.5);
    let half_width = uniforms.aspect_ratio * uniforms.strip_width * 0.5;
    let rail_width = half_width * 0.17;
    let image_half_width = half_width - rail_width * 1.35;
    let image_half_height = image_half_width / uniforms.aspect_ratio;
    let pitch = image_half_height * 2.0 + 0.055;
    let reverse = p >= 0.54;
    let down = smoothstep(0.0, 0.46, p);
    let up = smoothstep(0.54, 1.0, p);
    let scroll = select(-down * pitch * 2.0, mix(-pitch * 2.0, 0.0, up), reverse);
    let frame_index = floor((q.y + scroll + pitch * 0.5) / pitch);
    let frame_center = frame_index * pitch - scroll;
    let forward_index = i32(clamp(-frame_index, 0.0, 2.0));
    let reverse_index = 2 + i32(clamp(frame_index + 2.0, 0.0, 2.0));
    let photo_index = select(forward_index, reverse_index, reverse);
    let image_uv = vec2f(
        (q.x + image_half_width) / (image_half_width * 2.0),
        (q.y - frame_center + image_half_height) / (image_half_height * 2.0),
    );
    let inside_strip = 1.0 - smoothstep(half_width - 0.004, half_width + 0.004, abs(q.x));
    let inside_image = step(abs(q.x), image_half_width) * step(abs(q.y - frame_center), image_half_height);
    let local_hole = abs(fract((q.y + scroll) / 0.125) - 0.5);
    let rail = step(image_half_width + 0.01, abs(q.x)) * inside_strip;
    let holes = step(local_hole, 0.17) * rail;
    let grain = (hash21(floor(q * uniforms.resolution.y) + p * 19.0) - 0.5) * 0.055;
    var film = vec3f(0.055, 0.035, 0.018) + grain;
    let photo = sample_photo(photo_index, image_uv);
    film = mix(film, photo.rgb * vec3f(1.04, 1.0, 0.93), inside_image);
    let sky = mix(vec3f(0.66, 0.58, 0.47), vec3f(0.76, 0.86, 0.92), 1.0 - smoothstep(-0.12, 0.4, q.y));
    let composed = mix(sky, film, inside_strip * (1.0 - holes));
    return vec4f(clamp(composed, vec3f(0.0), vec3f(1.0)), 1.0);
}
