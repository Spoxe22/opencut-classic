mod blend_mode;
mod compositor;
mod frame;
mod presets;
mod texture_pool;
mod texture_store;

pub use blend_mode::BlendMode;
pub use compositor::{Compositor, CompositorError, RenderFrameOptions};
pub use frame::{
    CanvasClearDescriptor, CanvasTextureDescriptor, EffectPassDescriptor, FilmRollSixDescriptor,
    FrameDescriptor, FrameItemDescriptor, LayerDescriptor, LayerMaskDescriptor,
    QuadTransformDescriptor, TransitionDescriptor,
};
pub use presets::{
    TRANSITION_PRESETS, TransitionPresetDefinition, encode_preset_params, preset_code,
};

#[cfg(test)]
mod shader_tests {
    fn uniform_size(source: &str) -> u32 {
        let module = naga::front::wgsl::parse_str(source).unwrap();
        let (_, uniform) = module
            .global_variables
            .iter()
            .find(|(_, variable)| variable.name.as_deref() == Some("uniforms"))
            .expect("shader must expose a uniform block named 'uniforms'");
        let mut layouter = naga::proc::Layouter::default();
        layouter.update(module.to_ctx()).unwrap();
        layouter[uniform.ty].size
    }

    #[test]
    fn transition_shader_is_valid_wgsl() {
        let source = include_str!("shaders/transition.wgsl");
        naga::front::wgsl::parse_str(source).unwrap();
        assert_eq!(
            uniform_size(source),
            crate::compositor::TRANSITION_UNIFORM_BUFFER_SIZE
        );
    }

    #[test]
    fn film_roll_six_shader_is_valid_wgsl() {
        let source = include_str!("shaders/film_roll_six.wgsl");
        naga::front::wgsl::parse_str(source).unwrap();
        assert_eq!(
            uniform_size(source),
            crate::compositor::FILM_ROLL_SIX_UNIFORM_BUFFER_SIZE
        );
    }
}
