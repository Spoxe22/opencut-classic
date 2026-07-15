import { Command } from "@/commands/base-command";
import { EditorCore } from "@/core";
import type { TransitionInstance } from "@/timeline";

export class SetTransitionCommand extends Command {
	private previous: TransitionInstance[] | null = null;

	constructor(private transition: TransitionInstance) {
		super();
	}

	execute(): undefined {
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		this.previous = scene.transitions;
		const next = scene.transitions.filter(
			(item) =>
				item.fromElementId !== this.transition.fromElementId ||
				item.toElementId !== this.transition.toElementId,
		);
		editor.scenes.updateSceneTimeline({
			tracks: scene.tracks,
			transitions: [...next, this.transition],
		});
	}

	undo(): void {
		if (!this.previous) return;
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		editor.scenes.updateSceneTimeline({
			tracks: scene.tracks,
			transitions: this.previous,
		});
	}
}
