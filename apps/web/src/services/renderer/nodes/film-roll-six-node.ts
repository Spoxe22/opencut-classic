import { BaseNode } from "./base-node";

interface FilmRollSource {
	id: string;
	url: string;
	maxSourceSize?: number;
}

export interface FilmRollSixNodeParams {
	sources: [FilmRollSource, FilmRollSource, FilmRollSource, FilmRollSource, FilmRollSource];
	stripWidth: number;
	timeOffset: number;
	duration: number;
}

export interface ResolvedFilmRollSixNodeState {
	sources: Array<{ source: CanvasImageSource; width: number; height: number }>;
	progress: number;
}

export class FilmRollSixNode extends BaseNode<
	FilmRollSixNodeParams,
	ResolvedFilmRollSixNodeState
> {}
