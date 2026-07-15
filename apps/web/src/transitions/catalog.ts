export interface TransitionParamDefinition {
	key: string;
	label: string;
	default: number;
	min: number;
	max: number;
	step: number;
}

export interface TransitionPresetDefinition {
	id: string;
	name: string;
	keywords: string[];
	params: TransitionParamDefinition[];
}

const param = ({
	key,
	label,
	defaultValue,
	min,
	max,
	step = 0.01,
}: {
	key: string;
	label: string;
	defaultValue: number;
	min: number;
	max: number;
	step?: number;
}): TransitionParamDefinition => ({ key, label, default: defaultValue, min, max, step });

// eslint-disable-next-line opencut/prefer-object-params -- compact declarative catalogue rows
const p = (key: string, label: string, defaultValue: number, min: number, max: number, step?: number) => param({ key, label, defaultValue, min, max, step });
const dreamy = [p("rotation", "Rotation", 0, -45, 45, 0.5), p("scale", "Scale", 1, 0.5, 2)];
const filmRoll = [p("roll_cells", "Roll cells", 3, 1, 8, 0.1), p("strip_width", "Strip width", 0.66, 0.2, 1)];
const preset = ({ id, name, keywords, params = [] }: { id: string; name: string; keywords: string[]; params?: TransitionParamDefinition[] }): TransitionPresetDefinition => ({ id, name, keywords, params });

export const transitionCatalog: TransitionPresetDefinition[] = [
	preset({ id: "crossfade", name: "Crossfade", keywords: ["fade", "dissolve"] }),
	preset({ id: "DreamyZoom", name: "Dreamy Zoom", keywords: ["zoom", "dreamy"], params: dreamy }),
	preset({ id: "DreamyZoomFilmBurn", name: "Dreamy Zoom Film Burn", keywords: ["zoom", "film", "burn"], params: [...dreamy, p("burn_strength", "Burn", 1, 0, 2)] }),
	preset({ id: "DreamyZoomFilmBurnV2", name: "Dreamy Zoom Film Burn V2", keywords: ["zoom", "film", "burn"], params: [...dreamy, p("burn_strength", "Burn", 1, 0, 2), p("leak_direction_x", "Leak X", 1, -1, 1), p("leak_direction_y", "Leak Y", -0.35, -1, 1)] }),
	...[
		["FilmRollVertical", "Film Roll Vertical"],
		["FilmRollVerticalV2", "Film Roll Vertical V2"],
		["FilmRollVerticalV3", "Film Roll Vertical V3"],
		["FilmRollVerticalV4", "Film Roll Vertical V4"],
	].map(([id, name]) => preset({ id, name, keywords: ["film", "roll"], params: filmRoll })),
	preset({ id: "GlitchDisplace", name: "Glitch Displace", keywords: ["glitch", "digital"] }),
	preset({ id: "MotionMachineFlash", name: "Motion Machine Flash", keywords: ["flash", "highlight"], params: [p("threshold", "Threshold", 0.78, 0, 1), p("spread", "Spread", 0.24, 0, 1), p("knee", "Knee", 0.62, 0, 1), p("degrade_strength", "Degrade", 0.85, 0, 2), p("saturation_boost", "Saturation", 0.1, 0, 1)] }),
	preset({ id: "Overexposure", name: "Overexposure", keywords: ["flash", "light"], params: [p("strength", "Strength", 0.6, 0, 2)] }),
	preset({ id: "RiverCurrent", name: "River Current", keywords: ["water", "flow"], params: [p("flow_direction_x", "Flow X", 1, -1, 1), p("flow_direction_y", "Flow Y", 0.15, -1, 1), p("ripple_strength", "Ripple", 0.012, 0, 0.08, 0.001)] }),
	preset({ id: "RiverCurrentV2", name: "River Current V2", keywords: ["water", "depth"], params: [p("flow_direction_x", "Flow X", 1, -1, 1), p("flow_direction_y", "Flow Y", 0.15, -1, 1), p("ripple_strength", "Ripple", 0.012, 0, 0.08, 0.001), p("depth_strength", "Depth", 0.75, 0, 2)] }),
	preset({ id: "StereoViewerVertical", name: "Stereo Viewer Vertical", keywords: ["stereo", "vertical"], params: [p("zoom", "Zoom", 0.94, 0.5, 1.2), p("corner_radius", "Corner radius", 0.18, 0, 0.5)] }),
	preset({ id: "tangentMotionBlur", name: "Tangent Motion Blur", keywords: ["motion", "blur"] }),
];

export function defaultTransitionParams(preset: TransitionPresetDefinition) {
	return Object.fromEntries(preset.params.map((item) => [item.key, item.default]));
}
