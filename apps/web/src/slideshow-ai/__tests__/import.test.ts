import { describe, expect, test } from "bun:test";
import {
	matchShotFiles,
	slideshowShotListV1Schema,
} from "../schema";

function folderFile({ name, path }: { name: string; path: string }): File {
	const file = new File(["image"], name, { type: "image/jpeg" });
	Object.defineProperty(file, "webkitRelativePath", { value: path });
	return file;
}

describe("Slideshow AI import", () => {
	test("accepts legacy and schema v1 shot lists", () => {
		const legacy = slideshowShotListV1Schema.parse({
			aspect_ratio: "9:16",
			shots: [{ source_path: "C:\\photos\\one.jpg", duration_seconds: 2 }],
		});
		expect(legacy.schema_version).toBeUndefined();
		expect(legacy.shots[0].transition).toBe("cut");
		expect(
			slideshowShotListV1Schema.parse({ ...legacy, schema_version: 1 }).schema_version,
		).toBe(1);
	});

	test("matches Windows paths by relative folder before basename", () => {
		const preferred = folderFile({ name: "one.jpg", path: "trip/a/one.jpg" });
		const duplicate = folderFile({ name: "one.jpg", path: "other/one.jpg" });
		const shotList = slideshowShotListV1Schema.parse({
			shots: [
				{
					source_path: "C:\\users\\me\\trip\\a\\one.jpg",
					duration_seconds: 2,
				},
			],
		});
		expect(matchShotFiles({ shotList, files: [duplicate, preferred] })).toEqual([
			preferred,
		]);
	});

	test("rejects missing and ambiguous basenames", () => {
		const shotList = slideshowShotListV1Schema.parse({
			shots: [{ source_path: "/photos/one.jpg", duration_seconds: 2 }],
		});
		expect(() => matchShotFiles({ shotList, files: [] })).toThrow("introuvable");
		expect(() =>
			matchShotFiles({
				shotList,
				files: [
					folderFile({ name: "one.jpg", path: "a/one.jpg" }),
					folderFile({ name: "one.jpg", path: "b/one.jpg" }),
				],
			}),
		).toThrow("ambigu");
	});
});
