mod blend_mode;
mod compositor;
mod frame;
mod presets;
mod texture_pool;
mod texture_store;

pub use blend_mode::BlendMode;
pub use compositor::{Compositor, CompositorError, RenderFrameOptions};
pub use frame::{
    CanvasClearDescriptor, CanvasTextureDescriptor, EffectPassDescriptor, FrameDescriptor,
    FrameItemDescriptor, LayerDescriptor, LayerMaskDescriptor, QuadTransformDescriptor,
    TransitionDescriptor,
};
pub use presets::{
    TRANSITION_PRESETS, TransitionPresetDefinition, encode_preset_params, preset_code,
};

#[cfg(test)]
mod shader_tests {
    #[test]
    fn transition_shader_is_valid_wgsl() {
        naga::front::wgsl::parse_str(include_str!("shaders/transition.wgsl")).unwrap();
    }
}
