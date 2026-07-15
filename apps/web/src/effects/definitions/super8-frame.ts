import type { EffectDefinition } from "@/effects/types";

const number = ({
	effectParams,
	key,
	fallback,
}: {
	effectParams: Record<string, unknown>;
	key: string;
	fallback: number;
}) => (typeof effectParams[key] === "number" ? effectParams[key] : fallback);

export const super8FrameEffectDefinition: EffectDefinition = {
	type: "super8-frame",
	name: "Super 8 Frame",
	keywords: ["film", "grain", "vintage", "frame"],
	params: [
		{ key: "grain", label: "Grain", type: "number", default: 0.12, min: 0, max: 0.5, step: 0.01 },
		{ key: "vignette", label: "Vignette", type: "number", default: 0.55, min: 0, max: 1, step: 0.01 },
		{ key: "warmth", label: "Warmth", type: "number", default: 0.35, min: -1, max: 1, step: 0.01 },
	],
	renderer: {
		passes: [
			{
				shader: "super8-frame",
				uniforms: ({ effectParams }) => ({
					u_grain: number({ effectParams, key: "grain", fallback: 0.12 }),
					u_vignette: number({ effectParams, key: "vignette", fallback: 0.55 }),
					u_warmth: number({ effectParams, key: "warmth", fallback: 0.35 }),
					u_frame: number({ effectParams, key: "__time", fallback: 0 }),
				}),
			},
		],
	},
};
