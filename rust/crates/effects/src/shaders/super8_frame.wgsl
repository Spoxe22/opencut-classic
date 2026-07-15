struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) tex_coord: vec2f,
}

struct EffectUniforms {
    resolution: vec2f,
    direction: vec2f,
    scalars: vec4f,
}

@group(0) @binding(0) var input_texture: texture_2d<f32>;
@group(0) @binding(1) var input_sampler: sampler;
@group(1) @binding(0) var<uniform> uniforms: EffectUniforms;

fn hash21(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453);
}

@fragment
fn fragment_main(input: VertexOutput) -> @location(0) vec4f {
    let grain = uniforms.scalars.x;
    let vignette = uniforms.scalars.y;
    let warmth = uniforms.scalars.z;
    let frame = uniforms.scalars.w;
    let jitter = vec2f(
        (hash21(vec2f(frame, 2.0)) - 0.5) / max(uniforms.resolution.x, 1.0),
        (hash21(vec2f(frame, 7.0)) - 0.5) / max(uniforms.resolution.y, 1.0),
    ) * 3.0;
    let color = textureSample(input_texture, input_sampler, input.tex_coord + jitter);
    let noise = hash21(floor(input.tex_coord * uniforms.resolution) + frame * 17.0) - 0.5;
    var rgb = color.rgb + noise * grain;
    rgb *= vec3f(1.0 + warmth * 0.12, 1.0 + warmth * 0.025, 1.0 - warmth * 0.10);
    let centered = input.tex_coord * 2.0 - 1.0;
    let edge = smoothstep(0.25, 1.35, dot(centered, centered));
    rgb *= 1.0 - edge * vignette;
    let border = 1.0 - smoothstep(0.0, 0.018, min(min(input.tex_coord.x, 1.0 - input.tex_coord.x), min(input.tex_coord.y, 1.0 - input.tex_coord.y)));
    rgb *= 1.0 - border * 0.82;
    return vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), color.a);
}
