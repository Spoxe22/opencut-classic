mod pipeline;
mod types;

pub use pipeline::{ApplyEffectsOptions, EffectPipeline, EffectsError};
pub use types::{EffectPass, UniformValue};

#[cfg(test)]
mod shader_tests {
    #[test]
    fn super8_shader_is_valid_wgsl() {
        naga::front::wgsl::parse_str(include_str!("shaders/super8_frame.wgsl")).unwrap();
    }
}
