import { z } from "zod";

const transitionParamsSchema = z.record(
	z.string(),
	z.union([z.number(), z.array(z.number())]),
);
const shotSchema = z.object({
	source_path: z.string().min(1),
	duration_seconds: z.number().positive(),
	transition: z.string().default("cut"),
	transition_params: transitionParamsSchema.optional().default({}),
});

export const slideshowShotListV1Schema = z.object({
	schema_version: z.literal(1).optional(),
	aspect_ratio: z.enum(["16:9", "9:16"]).default("16:9"),
	shots: z.array(shotSchema).min(1),
});
export type SlideshowShotListV1 = z.infer<typeof slideshowShotListV1Schema>;

function normalizePath(value: string): string {
	return value.trim().replaceAll("\\", "/").replace(/^['"]|['"]$/g, "");
}

function baseName(value: string): string {
	return normalizePath(value).split("/").pop()?.toLocaleLowerCase() ?? "";
}

export function matchShotFiles({
	shotList,
	files,
}: {
	shotList: SlideshowShotListV1;
	files: File[];
}): File[] {
	return shotList.shots.map((shot) => {
		const source = normalizePath(shot.source_path).toLocaleLowerCase();
		const relativeMatches = files.filter((file) => {
			const relative = normalizePath(file.webkitRelativePath).toLocaleLowerCase();
			return relative.length > 0 && (source === relative || source.endsWith(`/${relative}`));
		});
		if (relativeMatches.length === 1) return relativeMatches[0];
		if (relativeMatches.length > 1) throw new Error(`Média ambigu pour ${shot.source_path}`);

		const nameMatches = files.filter(
			(file) => file.name.toLocaleLowerCase() === baseName(shot.source_path),
		);
		if (nameMatches.length === 1) return nameMatches[0];
		if (nameMatches.length === 0) throw new Error(`Média introuvable : ${shot.source_path}`);
		throw new Error(`Nom de média ambigu : ${shot.source_path}`);
	});
}
