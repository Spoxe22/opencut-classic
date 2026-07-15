import type { SceneTracks } from "@/timeline";
import { mediaTime, type MediaTime } from "@/wasm";

export function applyTransitionOverlap({
	tracks,
	fromElementId,
	toElementId,
	delta,
}: {
	tracks: SceneTracks;
	fromElementId: string;
	toElementId: string;
	delta: MediaTime;
}): SceneTracks {
	const ordered = tracks.main.elements
		.slice()
		.sort((a, b) => a.startTime - b.startTime);
	const fromIndex = ordered.findIndex((element) => element.id === fromElementId);
	const toIndex = ordered.findIndex((element) => element.id === toElementId);
	if (fromIndex < 0 || toIndex !== fromIndex + 1) {
		throw new Error("Une transition exige deux clips adjacents de la piste principale");
	}
	const target = ordered[toIndex];
	const nextStart = target.startTime - delta;
	const nextDuration = target.duration + delta;
	if (nextStart < 0 || nextDuration <= 0) {
		throw new Error("La durée de transition dépasse les poignées disponibles");
	}
	return {
		...tracks,
		main: {
			...tracks.main,
			elements: tracks.main.elements.map((element) =>
				element.id === toElementId
					? {
							...element,
							startTime: mediaTime({ ticks: nextStart }),
							duration: mediaTime({ ticks: nextDuration }),
						}
					: element,
			),
		},
	};
}
