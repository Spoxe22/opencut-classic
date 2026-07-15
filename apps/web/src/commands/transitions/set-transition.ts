import { Command } from "@/commands/base-command";
import { EditorCore } from "@/core";
import type { TransitionInstance } from "@/timeline";
import type { SceneTracks } from "@/timeline";
import { mediaTime } from "@/wasm";
import { applyTransitionOverlap } from "./transition-overlap";

export class SetTransitionCommand extends Command {
	private previous: TransitionInstance[] | null = null;
	private previousTracks: SceneTracks | null = null;

	constructor(private transition: TransitionInstance) {
		super();
	}

	execute(): undefined {
		const editor = EditorCore.getInstance();
		const scene = editor.scenes.getActiveScene();
		this.previous = scene.transitions;
		this.previousTracks = scene.tracks;
		const existing = scene.transitions.find(
			(item) =>
				item.fromElementId === this.transition.fromElementId &&
				item.toElementId === this.transition.toElementId,
		);
		const from = scene.tracks.main.elements.find(
			(element) => element.id === this.transition.fromElementId,
		);
		const to = scene.tracks.main.elements.find(
			(element) => element.id === this.transition.toElementId,
		);
		const targetBaseDuration = (to?.duration ?? 0) - (existing?.duration ?? 0);
		const maximumDuration = Math.floor(
			Math.min(from?.duration ?? 0, targetBaseDuration) / 2,
		);
		if (this.transition.duration <= 0 || this.transition.duration > maximumDuration) {
			throw new Error("La transition est limitée à la moitié du clip le plus court");
		}
		const delta = mediaTime({
			ticks: this.transition.duration - (existing?.duration ?? 0),
		});
		const tracks = applyTransitionOverlap({
			tracks: scene.tracks,
			fromElementId: this.transition.fromElementId,
			toElementId: this.transition.toElementId,
			delta,
		});
		const next = scene.transitions.filter(
			(item) =>
				item.fromElementId !== this.transition.fromElementId ||
				item.toElementId !== this.transition.toElementId,
		);
		editor.scenes.updateSceneTimeline({
			tracks,
			transitions: [...next, this.transition],
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
