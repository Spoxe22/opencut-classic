import type { TransitionParamValues } from "@/timeline";
import { BaseNode } from "./base-node";

export interface TransitionSource {
	id: string;
	url: string;
	maxSourceSize?: number;
}

export interface TransitionNodeParams {
	from: TransitionSource;
	to: TransitionSource;
	type: string;
	params: TransitionParamValues;
	timeOffset: number;
	duration: number;
}

export interface ResolvedTransitionNodeState {
	from: { source: CanvasImageSource; width: number; height: number };
	to: { source: CanvasImageSource; width: number; height: number };
	progress: number;
}

export class TransitionNode extends BaseNode<
	TransitionNodeParams,
	ResolvedTransitionNodeState
> {}
