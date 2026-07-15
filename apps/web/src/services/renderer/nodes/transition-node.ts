import type { TransitionParamValues } from "@/timeline";
import { BaseNode } from "./base-node";
import type { ImageNodeParams } from "./image-node";
import type { VideoNodeParams } from "./video-node";
import type { ResolvedVisualSourceNodeState } from "./visual-node";

export type TransitionSource =
	| (ImageNodeParams & { id: string; mediaType: "image" })
	| (VideoNodeParams & { id: string; mediaType: "video" });

export interface TransitionNodeParams {
	from: TransitionSource;
	to: TransitionSource;
	type: string;
	params: TransitionParamValues;
	timeOffset: number;
	duration: number;
}

export interface ResolvedTransitionNodeState {
	from: ResolvedVisualSourceNodeState;
	to: ResolvedVisualSourceNodeState;
	progress: number;
}

export class TransitionNode extends BaseNode<
	TransitionNodeParams,
	ResolvedTransitionNodeState
> {}
