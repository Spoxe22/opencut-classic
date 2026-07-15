import {
	Command,
	createElementSelectionResult,
	type CommandResult,
} from "@/commands/base-command";
import { EditorCore } from "@/core";
import type {
	FilmRollSixInstance,
	ImageElement,
	SceneTracks,
	TransitionInstance,
} from "@/timeline";
import { generateUUID } from "@/utils/id";
import { mediaTime, ZERO_MEDIA_TIME } from "@/wasm";

export class CreateFilmRollSixCommand extends Command {
	private previous:
		| {
				tracks: SceneTracks;
				transitions: TransitionInstance[];
				filmRollSix: FilmRollSixInstance[];
		  }
		| undefined;

	execute(): CommandResult {
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		const selected = new Set(
			editor.selection
				.getSelectedElements()
				.filter((ref) => ref.trackId === scene.tracks.main.id)
				.map((ref) => ref.elementId),
		);
		const ordered = scene.tracks.main.elements
			.slice()
			.sort((a, b) => a.startTime - b.startTime);
		const picked = ordered.filter((element) => selected.has(element.id));
		const images = picked.filter(
			(element): element is ImageElement => element.type === "image",
		);
		if (picked.length !== 5 || images.length !== 5) {
			throw new Error("Sélectionnez cinq images consécutives sur la piste principale");
		}
		const firstIndex = ordered.findIndex((element) => element.id === images[0].id);
		if (
			images.some((element, index) => ordered[firstIndex + index]?.id !== element.id) ||
			images.slice(1).some(
				(element, index) =>
					images[index].startTime + images[index].duration !== element.startTime,
			)
		) {
			throw new Error("Les cinq images doivent partager quatre coupes adjacentes");
		}
		const mediaIds = [
			images[0].mediaId,
			images[1].mediaId,
			images[2].mediaId,
			images[3].mediaId,
			images[4].mediaId,
		] satisfies FilmRollSixInstance["mediaIds"];
		const elementId = generateUUID();
		const end = images[4].startTime + images[4].duration;
		const placeholder = {
			...images[0],
			id: elementId,
			name: "Film Roll Six",
			duration: mediaTime({ ticks: end - images[0].startTime }),
			trimStart: ZERO_MEDIA_TIME,
			trimEnd: ZERO_MEDIA_TIME,
		};
		const instance: FilmRollSixInstance = {
			id: generateUUID(),
			elementId,
			mediaIds,
			stripWidth: 0.9,
		};
		this.previous = {
			tracks: scene.tracks,
			transitions: scene.transitions,
			filmRollSix: scene.filmRollSix,
		};
		const removedIds = new Set(images.map((element) => element.id));
		const elements = ordered.filter((element) => !removedIds.has(element.id));
		elements.splice(firstIndex, 0, placeholder);
		editor.scenes.updateSceneTimeline({
			tracks: {
				...scene.tracks,
				main: { ...scene.tracks.main, elements },
			},
			transitions: scene.transitions.filter(
				(transition) =>
					!removedIds.has(transition.fromElementId) &&
					!removedIds.has(transition.toElementId),
			),
			filmRollSix: [...scene.filmRollSix, instance],
		});
		return createElementSelectionResult([
			{ trackId: scene.tracks.main.id, elementId },
		]);
	}

	undo(): void {
		if (!this.previous) return;
		const editor = EditorCore.getInstance();
		editor.scenes.updateSceneTimeline(this.previous);
	}
}
