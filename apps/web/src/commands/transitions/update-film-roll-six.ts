import { Command } from "@/commands/base-command";
import { EditorCore } from "@/core";
import type { FilmRollSixInstance } from "@/timeline";

export class UpdateFilmRollSixCommand extends Command {
	private previous: FilmRollSixInstance[] | undefined;

	constructor({
		id,
		patch,
	}: {
		id: string;
		patch: Partial<Pick<FilmRollSixInstance, "mediaIds" | "stripWidth">>;
	}) {
		super();
		this.id = id;
		this.patch = patch;
	}

	private id: string;
	private patch: Partial<Pick<FilmRollSixInstance, "mediaIds" | "stripWidth">>;

	execute(): undefined {
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		this.previous = scene.filmRollSix;
		editor.scenes.updateSceneTimeline({
			tracks: scene.tracks,
			filmRollSix: scene.filmRollSix.map((instance) =>
				instance.id === this.id ? { ...instance, ...this.patch } : instance,
			),
		});
	}

	undo(): void {
		if (!this.previous) return;
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		editor.scenes.updateSceneTimeline({
			tracks: scene.tracks,
			filmRollSix: this.previous,
		});
	}
}
