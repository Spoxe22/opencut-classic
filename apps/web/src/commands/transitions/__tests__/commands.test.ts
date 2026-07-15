import { beforeEach, describe, expect, mock, test } from "bun:test";
import type { ElementRef, ImageElement, TScene } from "@/timeline";

let nextId = 0;
let scene: TScene;
let selectedElements: ElementRef[] = [];

const editor = {
	scenes: {
		getActiveScene: () => scene,
		updateSceneTimeline: (patch: Partial<TScene>) => {
			scene = { ...scene, ...patch };
		},
	},
	selection: {
		getSelectedElements: () => selectedElements,
	},
};

mock.module("@/core", () => ({
	EditorCore: { getInstance: () => editor },
}));
mock.module("@/utils/id", () => ({
	generateUUID: () => `generated-${++nextId}`,
}));
mock.module("@/wasm", () => ({
	mediaTime: ({ ticks }: { ticks: number }) => ticks,
	ZERO_MEDIA_TIME: 0,
}));

const { CreateFilmRollSixCommand } = await import("../create-film-roll-six");
const { RemoveTransitionCommand } = await import("../remove-transition");
const { SetTransitionCommand } = await import("../set-transition");
const { mediaTime } = await import("@/wasm");

beforeEach(() => {
	nextId = 0;
	const images = Array.from({ length: 6 }, (_, index) =>
		image({ id: `image-${index}`, startTime: index * 100, duration: 100 }),
	);
	scene = {
		id: "scene",
		name: "Scene",
		isMain: true,
		tracks: {
			main: {
				id: "main",
				name: "Main",
				type: "video",
				muted: false,
				hidden: false,
				elements: images,
			},
			overlay: [],
			audio: [],
		},
		transitions: [],
		filmRollSix: [],
		bookmarks: [],
		createdAt: new Date(0),
		updatedAt: new Date(0),
	};
	selectedElements = [];
});

describe("transition commands", () => {
	test("applies, changes, removes and restores a transition atomically", () => {
		const originalTracks = scene.tracks;
		const initial = {
			id: "transition",
			fromElementId: "image-0",
			toElementId: "image-1",
			type: "crossfade",
			duration: mediaTime({ ticks: 40 }),
			params: {},
		};
		const set = new SetTransitionCommand(initial);
		set.execute();
		expect(scene.tracks.main.elements[1]).toMatchObject({
			startTime: 60,
			duration: 140,
		});
		expect(scene.transitions).toEqual([initial]);

		const changed = new SetTransitionCommand({
			...initial,
			duration: mediaTime({ ticks: 20 }),
		});
		changed.execute();
		expect(scene.tracks.main.elements[1]).toMatchObject({
			startTime: 80,
			duration: 120,
		});
		changed.undo();
		expect(scene.tracks.main.elements[1]).toMatchObject({
			startTime: 60,
			duration: 140,
		});

		const remove = new RemoveTransitionCommand("transition");
		remove.execute();
		expect(scene.tracks).toEqual(originalTracks);
		expect(scene.transitions).toEqual([]);
		remove.undo();
		expect(scene.transitions).toEqual([initial]);
		set.undo();
		expect(scene.tracks).toEqual(originalTracks);
		expect(scene.transitions).toEqual([]);
	});
});

describe("FilmRollSix command", () => {
	test("replaces five consecutive images and undo restores the scene", () => {
		const originalTracks = scene.tracks;
		const originalTransitions = [
			{
				id: "cut",
				fromElementId: "image-4",
				toElementId: "image-5",
				type: "crossfade",
				duration: mediaTime({ ticks: 20 }),
				params: {},
			},
		];
		scene = { ...scene, transitions: originalTransitions };
		selectedElements = Array.from({ length: 5 }, (_, index) => ({
			trackId: "main",
			elementId: `image-${index}`,
		}));

		const command = new CreateFilmRollSixCommand();
		const result = command.execute();
		expect(scene.tracks.main.elements).toHaveLength(2);
		expect(scene.tracks.main.elements[0]).toMatchObject({
			id: "generated-1",
			name: "Film Roll Six",
			startTime: 0,
			duration: 500,
		});
		expect(scene.filmRollSix).toEqual([
			{
				id: "generated-2",
				elementId: "generated-1",
				mediaIds: ["image-0", "image-1", "image-2", "image-3", "image-4"],
				stripWidth: 0.9,
			},
		]);
		expect(scene.transitions).toEqual([]);
		expect(result?.selection?.selectedElements).toEqual([
			{ trackId: "main", elementId: "generated-1" },
		]);

		command.undo();
		expect(scene.tracks).toEqual(originalTracks);
		expect(scene.transitions).toEqual(originalTransitions);
		expect(scene.filmRollSix).toEqual([]);
	});
});

function image({
	id,
	startTime,
	duration,
}: {
	id: string;
	startTime: number;
	duration: number;
}): ImageElement {
	return {
		id,
		type: "image",
		mediaId: id,
		name: id,
		startTime: mediaTime({ ticks: startTime }),
		duration: mediaTime({ ticks: duration }),
		trimStart: mediaTime({ ticks: 0 }),
		trimEnd: mediaTime({ ticks: 0 }),
		params: {},
	};
}
