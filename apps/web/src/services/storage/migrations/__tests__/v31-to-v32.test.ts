import { describe, expect, test } from "bun:test";
import { transformProjectV31ToV32 } from "../transformers/v31-to-v32";
import { asRecordArray } from "./helpers";

describe("V31 to V32 Migration", () => {
	test("additively initializes scene transitions", () => {
		const existing = [{ id: "t1", type: "crossfade" }];
		const result = transformProjectV31ToV32({
			project: {
				id: "project-v31",
				version: 31,
				scenes: [{ id: "s1", name: "One" }, { id: "s2", transitions: existing }],
			},
		});

		expect(result.skipped).toBe(false);
		expect(result.project.version).toBe(32);
		const scenes = asRecordArray(result.project.scenes);
		expect(scenes[0]).toMatchObject({ id: "s1", name: "One", transitions: [] });
		expect(scenes[1]?.transitions).toEqual(existing);
	});

	test("skips newer and unrelated versions", () => {
		expect(
			transformProjectV31ToV32({ project: { id: "p", version: 32 } }).skipped,
		).toBe(true);
		expect(
			transformProjectV31ToV32({ project: { id: "p", version: 30 } }).skipped,
		).toBe(true);
	});
});
