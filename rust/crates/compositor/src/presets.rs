use std::collections::HashMap;

use serde::Serialize;

use crate::frame::EffectUniformValueDescriptor;

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PresetParamDefinition {
    pub key: &'static str,
    pub label: &'static str,
    pub default: f32,
    pub min: f32,
    pub max: f32,
    pub step: f32,
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TransitionPresetDefinition {
    pub id: &'static str,
    pub name: &'static str,
    pub keywords: &'static [&'static str],
    pub params: &'static [PresetParamDefinition],
}

const EMPTY: &[PresetParamDefinition] = &[];
const DREAMY: &[PresetParamDefinition] = &[
    param("rotation", "Rotation", 0.0, -45.0, 45.0, 0.5),
    param("scale", "Scale", 1.0, 0.5, 2.0, 0.01),
];
const DREAMY_BURN: &[PresetParamDefinition] = &[
    param("rotation", "Rotation", 0.0, -45.0, 45.0, 0.5),
    param("scale", "Scale", 1.0, 0.5, 2.0, 0.01),
    param("burn_strength", "Burn", 1.0, 0.0, 2.0, 0.01),
];
const DREAMY_BURN_V2: &[PresetParamDefinition] = &[
    param("rotation", "Rotation", 0.0, -45.0, 45.0, 0.5),
    param("scale", "Scale", 1.0, 0.5, 2.0, 0.01),
    param("burn_strength", "Burn", 1.0, 0.0, 2.0, 0.01),
    param("leak_direction_x", "Leak X", 1.0, -1.0, 1.0, 0.01),
    param("leak_direction_y", "Leak Y", -0.35, -1.0, 1.0, 0.01),
];
const FILM_ROLL: &[PresetParamDefinition] = &[
    param("roll_cells", "Roll cells", 3.0, 1.0, 8.0, 0.1),
    param("strip_width", "Strip width", 0.66, 0.2, 1.0, 0.01),
];
const OVEREXPOSURE: &[PresetParamDefinition] =
    &[param("strength", "Strength", 0.6, 0.0, 2.0, 0.01)];
const RIVER: &[PresetParamDefinition] = &[
    param("flow_direction_x", "Flow X", 1.0, -1.0, 1.0, 0.01),
    param("flow_direction_y", "Flow Y", 0.15, -1.0, 1.0, 0.01),
    param("ripple_strength", "Ripple", 0.012, 0.0, 0.08, 0.001),
];
const RIVER_V2: &[PresetParamDefinition] = &[
    param("flow_direction_x", "Flow X", 1.0, -1.0, 1.0, 0.01),
    param("flow_direction_y", "Flow Y", 0.15, -1.0, 1.0, 0.01),
    param("ripple_strength", "Ripple", 0.012, 0.0, 0.08, 0.001),
    param("depth_strength", "Depth", 0.75, 0.0, 2.0, 0.01),
];
const STEREO: &[PresetParamDefinition] = &[
    param("zoom", "Zoom", 0.94, 0.5, 1.2, 0.01),
    param("corner_radius", "Corner radius", 0.18, 0.0, 0.5, 0.01),
];
const MOTION_FLASH: &[PresetParamDefinition] = &[
    param("threshold", "Threshold", 0.78, 0.0, 1.0, 0.01),
    param("spread", "Spread", 0.24, 0.0, 1.0, 0.01),
    param("knee", "Knee", 0.62, 0.0, 1.0, 0.01),
    param("degrade_strength", "Degrade", 0.85, 0.0, 2.0, 0.01),
    param("saturation_boost", "Saturation", 0.10, 0.0, 1.0, 0.01),
];

const fn param(
    key: &'static str,
    label: &'static str,
    default: f32,
    min: f32,
    max: f32,
    step: f32,
) -> PresetParamDefinition {
    PresetParamDefinition {
        key,
        label,
        default,
        min,
        max,
        step,
    }
}

const fn preset(
    id: &'static str,
    name: &'static str,
    keywords: &'static [&'static str],
    params: &'static [PresetParamDefinition],
) -> TransitionPresetDefinition {
    TransitionPresetDefinition {
        id,
        name,
        keywords,
        params,
    }
}

pub const TRANSITION_PRESETS: &[TransitionPresetDefinition] = &[
    preset("crossfade", "Crossfade", &["fade", "dissolve"], EMPTY),
    preset("DreamyZoom", "Dreamy Zoom", &["zoom", "dreamy"], DREAMY),
    preset(
        "DreamyZoomFilmBurn",
        "Dreamy Zoom Film Burn",
        &["zoom", "film", "burn"],
        DREAMY_BURN,
    ),
    preset(
        "DreamyZoomFilmBurnV2",
        "Dreamy Zoom Film Burn V2",
        &["zoom", "film", "burn"],
        DREAMY_BURN_V2,
    ),
    preset(
        "FilmRollVertical",
        "Film Roll Vertical",
        &["film", "roll"],
        FILM_ROLL,
    ),
    preset(
        "FilmRollVerticalV2",
        "Film Roll Vertical V2",
        &["film", "roll"],
        FILM_ROLL,
    ),
    preset(
        "FilmRollVerticalV3",
        "Film Roll Vertical V3",
        &["film", "roll", "cinematic"],
        FILM_ROLL,
    ),
    preset(
        "FilmRollVerticalV4",
        "Film Roll Vertical V4",
        &["film", "roll", "city"],
        FILM_ROLL,
    ),
    preset(
        "GlitchDisplace",
        "Glitch Displace",
        &["glitch", "digital"],
        EMPTY,
    ),
    preset(
        "MotionMachineFlash",
        "Motion Machine Flash",
        &["flash", "highlight"],
        MOTION_FLASH,
    ),
    preset(
        "Overexposure",
        "Overexposure",
        &["flash", "light"],
        OVEREXPOSURE,
    ),
    preset("RiverCurrent", "River Current", &["water", "flow"], RIVER),
    preset(
        "RiverCurrentV2",
        "River Current V2",
        &["water", "depth"],
        RIVER_V2,
    ),
    preset(
        "StereoViewerVertical",
        "Stereo Viewer Vertical",
        &["stereo", "vertical"],
        STEREO,
    ),
    preset(
        "tangentMotionBlur",
        "Tangent Motion Blur",
        &["motion", "blur"],
        EMPTY,
    ),
];

pub fn preset_code(id: &str) -> Option<u32> {
    TRANSITION_PRESETS
        .iter()
        .position(|preset| preset.id == id)
        .map(|index| index as u32)
}

pub fn encode_preset_params(
    id: &str,
    values: &HashMap<String, EffectUniformValueDescriptor>,
) -> Option<[f32; 16]> {
    let definition = TRANSITION_PRESETS.iter().find(|preset| preset.id == id)?;
    let mut encoded = [0.0; 16];
    for (index, param) in definition.params.iter().enumerate() {
        encoded[index] = number(values.get(param.key)).unwrap_or(param.default);
    }
    if matches!(id, "RiverCurrent" | "RiverCurrentV2") {
        copy_vector(values.get("flow_direction"), &mut encoded, 0);
    }
    if id == "DreamyZoomFilmBurnV2" {
        copy_vector(values.get("leak_direction"), &mut encoded, 3);
    }
    Some(encoded)
}

fn number(value: Option<&EffectUniformValueDescriptor>) -> Option<f32> {
    match value {
        Some(EffectUniformValueDescriptor::Number(value)) => Some(*value),
        Some(EffectUniformValueDescriptor::Vector(values)) => values.first().copied(),
        None => None,
    }
}

fn copy_vector(
    value: Option<&EffectUniformValueDescriptor>,
    target: &mut [f32; 16],
    offset: usize,
) {
    if let Some(EffectUniformValueDescriptor::Vector(values)) = value {
        for (index, value) in values.iter().take(2).enumerate() {
            target[offset + index] = *value;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_contains_curated_presets() {
        assert_eq!(TRANSITION_PRESETS.len(), 15);
        assert_eq!(preset_code("DreamyZoom"), Some(1));
        assert_eq!(preset_code("missing"), None);
    }

    #[test]
    fn legacy_vectors_are_encoded() {
        let values = HashMap::from([(
            "flow_direction".to_string(),
            EffectUniformValueDescriptor::Vector(vec![1.0, -0.25]),
        )]);
        let encoded = encode_preset_params("RiverCurrent", &values).unwrap();
        assert_eq!(&encoded[..3], &[1.0, -0.25, 0.012]);
    }
}
