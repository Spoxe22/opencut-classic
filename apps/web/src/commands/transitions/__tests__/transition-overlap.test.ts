import { describe, expect, mock, test } from "bun:test";
import type { ImageElement, SceneTracks } from "@/timeline";

mock.module("@/wasm", () => ({
	mediaTime: ({ ticks }: { ticks: number }) => ticks,
}));

const { applyTransitionOverlap } = await import("../transition-overlap");
const { mediaTime } = await import("@/wasm");

describe("transition overlap", () => {
	test("applies and reverses an overlap without moving the target end", () => {
		const tracks: SceneTracks = {
			overlay: [],
			audio: [],
			main: {
				id: "main",
				name: "Main",
				type: "video" as const,
				muted: false,
				hidden: false,
				elements: [
					image({ id: "a", startTime: 0, duration: 300 }),
					image({ id: "b", startTime: 300, duration: 300 }),
					image({ id: "c", startTime: 600, duration: 300 }),
				],
			},
		};
		const applied = applyTransitionOverlap({
			tracks,
			fromElementId: "a",
			toElementId: "b",
			delta: mediaTime({ ticks: 100 }),
		});
		expect(applied.main.elements[1]).toMatchObject({
			startTime: 200,
			duration: 400,
		});
		expect(applied.main.elements[2]?.startTime).toBe(mediaTime({ ticks: 600 }));

		const restored = applyTransitionOverlap({
			tracks: applied,
			fromElementId: "a",
			toElementId: "b",
			delta: mediaTime({ ticks: -100 }),
		});
		expect(restored).toEqual(tracks);
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
		type: "image" as const,
		mediaId: id,
		name: id,
		startTime: mediaTime({ ticks: startTime }),
		duration: mediaTime({ ticks: duration }),
		trimStart: mediaTime({ ticks: 0 }),
		trimEnd: mediaTime({ ticks: 0 }),
		params: {},
	};
}
