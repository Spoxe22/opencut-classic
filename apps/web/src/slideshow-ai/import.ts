import type { EditorCore } from "@/core";
import { processMediaAssets } from "@/media/processing";
import { buildElementFromMedia } from "@/timeline/element-utils";
import type {
	ImageElement,
	SceneTracks,
	TransitionInstance,
	TransitionParamValues,
} from "@/timeline";
import { generateUUID } from "@/utils/id";
import { applyTransitionOverlap } from "@/commands/transitions";
import {
	addMediaTime,
	mediaTimeFromSeconds,
	ZERO_MEDIA_TIME,
} from "@/wasm";
import { matchShotFiles, slideshowShotListV1Schema } from "./schema";

const CURATED_PRESETS = new Set([
	"DreamyZoom",
	"DreamyZoomFilmBurn",
	"DreamyZoomFilmBurnV2",
	"FilmRollVertical",
	"FilmRollVerticalV2",
	"FilmRollVerticalV3",
	"FilmRollVerticalV4",
	"GlitchDisplace",
	"MotionMachineFlash",
	"Overexposure",
	"RiverCurrent",
	"RiverCurrentV2",
	"StereoViewerVertical",
	"tangentMotionBlur",
]);

function mapTransition({
	value,
	params,
	warnings,
}: {
	value: string;
	params: TransitionParamValues;
	warnings: string[];
}): { type: string; params: TransitionParamValues } | null {
	if (value === "cut") return null;
	if (value === "crossfade") return { type: "crossfade", params: {} };
	if (value.startsWith("gl:")) {
		const id = value.slice(3);
		if (CURATED_PRESETS.has(id)) {
			if (id === "MotionMachineFlash") {
				return {
					type: id,
					params: {
						...params,
						threshold: params.threshold ?? 0.78,
						spread: params.spread ?? params.zoom_strength ?? 0.24,
						knee: params.knee ?? 0.62,
						degrade_strength:
							params.degrade_strength ?? params.blur_strength ?? 0.85,
						saturation_boost:
							params.saturation_boost ?? params.flash_strength ?? 0.1,
					},
				};
			}
			return { type: id, params };
		}
	}
	warnings.push(`${value} remplacée par crossfade`);
	return { type: "crossfade", params: {} };
}

export async function importSlideshowAiProject({
	editor,
	jsonFile,
	mediaFiles,
}: {
	editor: EditorCore;
	jsonFile: File;
	mediaFiles: File[];
}): Promise<{ projectId: string; warnings: string[] }> {
	const shotList = slideshowShotListV1Schema.parse(
		JSON.parse(await jsonFile.text()) as unknown,
	);
	const matched = matchShotFiles({ shotList, files: mediaFiles });
	const uniqueFiles = [...new Set(matched)];
	const processed = await processMediaAssets({ files: uniqueFiles });
	if (
		processed.length !== uniqueFiles.length ||
		processed.some((asset) => asset.type !== "image")
	) {
		throw new Error("Tous les médias doivent être des images compatibles");
	}

	let projectId: string | null = null;
	try {
		projectId = await editor.project.createNewProject({ name: "Slideshow AI" });
		const assetByFile = new Map<
			File,
			Awaited<ReturnType<typeof editor.media.addMediaAsset>>
		>();
		for (let index = 0; index < uniqueFiles.length; index++) {
			assetByFile.set(
				uniqueFiles[index],
				await editor.media.addMediaAsset({ projectId, asset: processed[index] }),
			);
		}
		if ([...assetByFile.values()].some((asset) => !asset)) {
			throw new Error("Impossible d’enregistrer tous les médias");
		}

		const activeScene = editor.scenes.getActiveScene();
		const canvasSize =
			shotList.aspect_ratio === "9:16"
				? { width: 1080, height: 1920 }
				: { width: 1920, height: 1080 };
		let cursor = ZERO_MEDIA_TIME;
		const elements: ImageElement[] = [];
		for (let index = 0; index < shotList.shots.length; index++) {
			const shot = shotList.shots[index];
			const asset = assetByFile.get(matched[index]);
			if (!asset) throw new Error(`Média non enregistré : ${shot.source_path}`);
			const duration = mediaTimeFromSeconds({ seconds: shot.duration_seconds });
			const element = buildElementFromMedia({
				mediaId: asset.id,
				mediaType: "image",
				name: asset.name,
				duration,
				startTime: cursor,
			});
			if (element.type !== "image") {
				throw new Error("Élément image invalide");
			}
			const width = Math.max(asset.width ?? canvasSize.width, 1);
			const height = Math.max(asset.height ?? canvasSize.height, 1);
			const contain = Math.min(canvasSize.width / width, canvasSize.height / height);
			const cover = Math.max(canvasSize.width / width, canvasSize.height / height);
			elements.push({
				...element,
				id: generateUUID(),
				params: {
					...element.params,
					"transform.scaleX": cover / contain,
					"transform.scaleY": cover / contain,
				},
			});
			cursor = addMediaTime({ a: cursor, b: duration });
		}

		const warnings: string[] = [];
		const transitions: TransitionInstance[] = [];
		for (let index = 1; index < elements.length; index++) {
			const mapped = mapTransition({
				value: shotList.shots[index].transition,
				params: shotList.shots[index].transition_params,
				warnings,
			});
			if (!mapped) continue;
			const durationSeconds = Math.min(
				1,
				shotList.shots[index - 1].duration_seconds / 2,
				shotList.shots[index].duration_seconds / 2,
			);
			transitions.push({
				id: generateUUID(),
				fromElementId: elements[index - 1].id,
				toElementId: elements[index].id,
				type: mapped.type,
				duration: mediaTimeFromSeconds({ seconds: durationSeconds }),
				params: mapped.params,
			});
		}

		let tracks: SceneTracks = {
				...activeScene.tracks,
				main: { ...activeScene.tracks.main, elements },
			};
		for (const transition of transitions) {
			tracks = applyTransitionOverlap({
				tracks,
				fromElementId: transition.fromElementId,
				toElementId: transition.toElementId,
				delta: transition.duration,
			});
		}
		editor.scenes.updateSceneTimeline({
			tracks,
			transitions,
		});
		await editor.project.updateSettings({
			settings: {
				fps: { numerator: 30, denominator: 1 },
				canvasSize,
				canvasSizeMode: "preset",
			},
			pushHistory: false,
		});
		await editor.save.flush();
		return { projectId, warnings };
	} catch (error) {
		if (projectId) await editor.project.deleteProjects({ ids: [projectId] });
		throw error;
	}
}
