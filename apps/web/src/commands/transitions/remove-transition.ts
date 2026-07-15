import { Command } from "@/commands/base-command";
import { EditorCore } from "@/core";
import type { TransitionInstance } from "@/timeline";

export class RemoveTransitionCommand extends Command {
	private previous: TransitionInstance[] | null = null;

	constructor(private transitionId: string) {
		super();
	}

	execute(): undefined {
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		this.previous = scene.transitions;
		editor.scenes.updateSceneTimeline({
			tracks: scene.tracks,
			transitions: scene.transitions.filter((item) => item.id !== this.transitionId),
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
