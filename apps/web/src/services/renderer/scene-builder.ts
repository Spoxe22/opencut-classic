import type {
	SceneTracks,
	TimelineTrack,
	TransitionInstance,
	FilmRollSixInstance,
	ImageElement,
	VideoElement,
} from "@/timeline";
import type { MediaAsset } from "@/media/types";
import { RootNode } from "./nodes/root-node";
import { VideoNode } from "./nodes/video-node";
import { ImageNode } from "./nodes/image-node";
import { TextNode } from "./nodes/text-node";
import { StickerNode } from "./nodes/sticker-node";
import { GraphicNode } from "./nodes/graphic-node";
import { ColorNode } from "./nodes/color-node";
import { BlurBackgroundNode } from "./nodes/blur-background-node";
import { EffectLayerNode } from "./nodes/effect-layer-node";
import {
	TransitionNode,
	type TransitionSource,
} from "./nodes/transition-node";
import { FilmRollSixNode } from "./nodes/film-roll-six-node";
import type { AnyBaseNode } from "./nodes/base-node";
import type { TBackground, TCanvasSize } from "@/project/types";
import { DEFAULT_BACKGROUND_BLUR_INTENSITY } from "@/background/blur";
import {
	buildTransformFromParams,
	readBlendModeFromParams,
	readOpacityFromParams,
} from "@/rendering";

const PREVIEW_MAX_IMAGE_SIZE = 2048;

function getVisibleSortedElements({ track }: { track: TimelineTrack }) {
	return track.elements
		.filter((element) => !("hidden" in element && element.hidden))
		.slice()
		.sort((a, b) => {
			if (a.startTime !== b.startTime) return a.startTime - b.startTime;
			return a.id.localeCompare(b.id);
		});
}

function buildTrackNodes({
	tracks,
	mediaMap,
	canvasSize,
	isPreview,
}: {
	tracks: TimelineTrack[];
	mediaMap: Map<string, MediaAsset>;
	canvasSize: TCanvasSize;
	isPreview?: boolean;
}): AnyBaseNode[] {
	const nodes: AnyBaseNode[] = [];

	for (const track of tracks) {
		const elements = getVisibleSortedElements({ track });

		for (const element of elements) {
			if (element.type === "effect") {
				nodes.push(
					new EffectLayerNode({
						effectType: element.effectType,
						effectParams: element.params,
						timeOffset: element.startTime,
						duration: element.duration,
					}),
				);
				continue;
			}

			if (element.type === "video" || element.type === "image") {
				const mediaAsset = mediaMap.get(element.mediaId);
				if (!mediaAsset?.file || !mediaAsset?.url) {
					continue;
				}

				if (element.type === "video" && mediaAsset.type === "video") {
					nodes.push(
						new VideoNode({
							mediaId: mediaAsset.id,
							url: mediaAsset.url,
							file: mediaAsset.file,
							duration: element.duration,
							timeOffset: element.startTime,
							trimStart: element.trimStart,
							trimEnd: element.trimEnd,
							retime: element.retime,
							transform: buildTransformFromParams({ params: element.params }),
							animations: element.animations,
							opacity: readOpacityFromParams({ params: element.params }),
							blendMode: readBlendModeFromParams({ params: element.params }),
							effects: element.effects ?? [],
							masks: element.masks ?? [],
						}),
					);
				}
				if (element.type === "image" && mediaAsset.type === "image") {
					nodes.push(
						new ImageNode({
							url: mediaAsset.url,
							duration: element.duration,
							timeOffset: element.startTime,
							trimStart: element.trimStart,
							trimEnd: element.trimEnd,
							transform: buildTransformFromParams({ params: element.params }),
							animations: element.animations,
							opacity: readOpacityFromParams({ params: element.params }),
							blendMode: readBlendModeFromParams({ params: element.params }),
							effects: element.effects ?? [],
							masks: element.masks ?? [],
							...(isPreview && {
								maxSourceSize: PREVIEW_MAX_IMAGE_SIZE,
							}),
						}),
					);
				}
			}

			if (element.type === "text") {
				nodes.push(
					new TextNode({
						...element,
						transform: buildTransformFromParams({ params: element.params }),
						opacity: readOpacityFromParams({ params: element.params }),
						blendMode: readBlendModeFromParams({ params: element.params }),
						canvasCenter: { x: canvasSize.width / 2, y: canvasSize.height / 2 },
						canvasHeight: canvasSize.height,
						textBaseline: "middle",
						effects: element.effects ?? [],
					}),
				);
			}

			if (element.type === "sticker") {
				nodes.push(
					new StickerNode({
						stickerId: element.stickerId,
						intrinsicWidth: element.intrinsicWidth,
						intrinsicHeight: element.intrinsicHeight,
						duration: element.duration,
						timeOffset: element.startTime,
						trimStart: element.trimStart,
						trimEnd: element.trimEnd,
						transform: buildTransformFromParams({ params: element.params }),
						animations: element.animations,
						opacity: readOpacityFromParams({ params: element.params }),
						blendMode: readBlendModeFromParams({ params: element.params }),
						effects: element.effects ?? [],
					}),
				);
			}

			if (element.type === "graphic") {
				nodes.push(
					new GraphicNode({
						definitionId: element.definitionId,
						params: element.params,
						duration: element.duration,
						timeOffset: element.startTime,
						trimStart: element.trimStart,
						trimEnd: element.trimEnd,
						transform: buildTransformFromParams({ params: element.params }),
						animations: element.animations,
						opacity: readOpacityFromParams({ params: element.params }),
						blendMode: readBlendModeFromParams({ params: element.params }),
						effects: element.effects ?? [],
						masks: element.masks ?? [],
					}),
				);
			}
		}
	}

	return nodes;
}

function buildBlurBackgroundNodes({
	track,
	mediaMap,
	blurIntensity,
}: {
	track: TimelineTrack | undefined;
	mediaMap: Map<string, MediaAsset>;
	blurIntensity: number;
}): AnyBaseNode[] {
	if (!track) {
		return [];
	}

	const nodes: AnyBaseNode[] = [];
	const elements = getVisibleSortedElements({ track });

	for (const element of elements) {
		if (element.type !== "video" && element.type !== "image") {
			continue;
		}

		const mediaAsset = mediaMap.get(element.mediaId);
		if (
			!mediaAsset?.file ||
			!mediaAsset?.url ||
			(mediaAsset.type !== "video" && mediaAsset.type !== "image")
		) {
			continue;
		}

		nodes.push(
			new BlurBackgroundNode({
				mediaId: mediaAsset.id,
				url: mediaAsset.url,
				file: mediaAsset.file,
				mediaType: mediaAsset.type,
				duration: element.duration,
				timeOffset: element.startTime,
				trimStart: element.trimStart,
				trimEnd: element.trimEnd,
				retime: element.type === "video" ? element.retime : undefined,
				blurIntensity,
			}),
		);
	}

	return nodes;
}

export type BuildSceneParams = {
	canvasSize: TCanvasSize;
	tracks: SceneTracks;
	mediaAssets: MediaAsset[];
	duration: number;
	background: TBackground;
	transitions?: TransitionInstance[];
	filmRollSix?: FilmRollSixInstance[];
	isPreview?: boolean;
};

export function buildScene({
	canvasSize,
	tracks,
	mediaAssets,
	duration,
	background,
	transitions = [],
	filmRollSix = [],
	isPreview,
}: BuildSceneParams) {
	const rootNode = new RootNode({ duration });
	const mediaMap = new Map(mediaAssets.map((m) => [m.id, m]));

	const visibleOverlays = tracks.overlay.filter(
		(track) => !("hidden" in track && track.hidden),
	);
	const mainTrack = tracks.main.hidden ? undefined : tracks.main;
	const filmRollElementIds = new Set(filmRollSix.map((instance) => instance.elementId));
	const renderedMainTrack = mainTrack
		? {
				...mainTrack,
				elements: mainTrack.elements.filter(
					(element) => !filmRollElementIds.has(element.id),
				),
			}
		: undefined;
	const mainNodes = buildTrackNodes({
		tracks: renderedMainTrack ? [renderedMainTrack] : [],
		mediaMap,
		canvasSize,
		isPreview,
	});
	const overlayNodes = buildTrackNodes({
		tracks: visibleOverlays.slice().reverse(),
		mediaMap,
		canvasSize,
		isPreview,
	});

	if (background.type === "blur") {
		const blurNodes = buildBlurBackgroundNodes({
			track: mainTrack,
			mediaMap,
			blurIntensity:
				background.blurIntensity ?? DEFAULT_BACKGROUND_BLUR_INTENSITY,
		});
		for (const node of blurNodes) {
			rootNode.add(node);
		}
	} else if (
		background.type === "color" &&
		background.color !== "transparent"
	) {
		rootNode.add(new ColorNode({ color: background.color }));
	}

	for (const node of mainNodes) {
		rootNode.add(node);
	}

	if (mainTrack) {
		const elements = new Map(mainTrack.elements.map((element) => [element.id, element]));
		for (const instance of filmRollSix) {
			const placeholder = elements.get(instance.elementId);
			if (!placeholder) continue;
			const assets = instance.mediaIds.map((id) => mediaMap.get(id));
			if (
				!assets.every(
					(asset): asset is MediaAsset & { url: string } =>
						typeof asset?.url === "string",
				)
			)
				continue;
			const source = (asset: MediaAsset & { url: string }) => ({
				id: asset.id,
				url: asset.url,
				...(isPreview && { maxSourceSize: PREVIEW_MAX_IMAGE_SIZE }),
			});
			rootNode.add(
				new FilmRollSixNode({
					sources: [
						source(assets[0]),
						source(assets[1]),
						source(assets[2]),
						source(assets[3]),
						source(assets[4]),
					],
					stripWidth: instance.stripWidth,
					timeOffset: placeholder.startTime,
					duration: placeholder.duration,
				}),
			);
		}
	}

	if (mainTrack) {
		const elements = new Map(mainTrack.elements.map((element) => [element.id, element]));
		for (const transition of transitions) {
			const from = elements.get(transition.fromElementId);
			const to = elements.get(transition.toElementId);
			if (
				(from?.type !== "image" && from?.type !== "video") ||
				(to?.type !== "image" && to?.type !== "video")
			)
				continue;
			const fromMedia = mediaMap.get(from.mediaId);
			const toMedia = mediaMap.get(to.mediaId);
			const fromUrl = fromMedia?.url;
			const toUrl = toMedia?.url;
			if (!fromMedia || !toMedia || !fromUrl || !toUrl) continue;
			const transitionSource = ({
				element,
				media,
				url,
			}: {
				element: ImageElement | VideoElement;
				media: MediaAsset;
				url: string;
			}): TransitionSource => {
				const visual = {
					duration: element.duration,
					timeOffset: element.startTime,
					trimStart: element.trimStart,
					trimEnd: element.trimEnd,
					transform: buildTransformFromParams({ params: element.params }),
					animations: element.animations,
					opacity: readOpacityFromParams({ params: element.params }),
					blendMode: readBlendModeFromParams({ params: element.params }),
					effects: element.effects ?? [],
					masks: element.masks ?? [],
				};
				return element.type === "video"
					? {
							...visual,
							id: media.id,
							mediaType: "video",
							mediaId: media.id,
							url,
							file: media.file,
							retime: element.retime,
						}
					: {
							...visual,
							id: media.id,
							mediaType: "image",
							url,
							...(isPreview && { maxSourceSize: PREVIEW_MAX_IMAGE_SIZE }),
						};
			};
			rootNode.add(
				new TransitionNode({
					from: transitionSource({ element: from, media: fromMedia, url: fromUrl }),
					to: transitionSource({ element: to, media: toMedia, url: toUrl }),
					type: transition.type,
					params: transition.params,
					timeOffset: to.startTime,
					duration: transition.duration,
				}),
			);
		}
	}

	for (const node of overlayNodes) {
		rootNode.add(node);
	}

	return rootNode;
}
