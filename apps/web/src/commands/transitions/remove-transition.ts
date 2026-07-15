import { Command } from "@/commands/base-command";
import { EditorCore } from "@/core";
import type { TransitionInstance } from "@/timeline";
import type { SceneTracks } from "@/timeline";
import { mediaTime } from "@/wasm";
import { applyTransitionOverlap } from "./transition-overlap";

export class RemoveTransitionCommand extends Command {
	private previous: TransitionInstance[] | null = null;
	private previousTracks: SceneTracks | null = null;

	constructor(private transitionId: string) {
		super();
	}

	execute(): undefined {
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		this.previous = scene.transitions;
		this.previousTracks = scene.tracks;
		const removed = scene.transitions.find((item) => item.id === this.transitionId);
		if (!removed) return;
		const tracks = applyTransitionOverlap({
			tracks: scene.tracks,
			fromElementId: removed.fromElementId,
			toElementId: removed.toElementId,
			delta: mediaTime({ ticks: -removed.duration }),
		});
		editor.scenes.updateSceneTimeline({
			tracks,
			transitions: scene.transitions.filter((item) => item.id !== this.transitionId),
		});
	}

	undo(): void {
		if (!this.previous || !this.previousTracks) return;
		const editor = EditorCore.getInstance();
		editor.scenes.updateSceneTimeline({
			tracks: this.previousTracks,
			transitions: this.previous,
		});
	}
}
