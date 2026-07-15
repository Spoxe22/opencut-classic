import type { MigrationResult, ProjectRecord } from "./types";
import { getProjectId, isRecord } from "./utils";

export function transformProjectV31ToV32({
	project,
}: {
	project: ProjectRecord;
}): MigrationResult<ProjectRecord> {
	if (!getProjectId({ project })) {
		return { project, skipped: true, reason: "no project id" };
	}
	if (typeof project.version !== "number") {
		return { project, skipped: true, reason: "invalid version" };
	}
	if (project.version >= 32) {
		return { project, skipped: true, reason: "already v32" };
	}
	if (project.version !== 31) {
		return { project, skipped: true, reason: "not v31" };
	}

	return {
		project: {
			...project,
			version: 32,
			scenes: Array.isArray(project.scenes)
				? project.scenes.map((scene) =>
						isRecord(scene) && !Array.isArray(scene.transitions)
							? { ...scene, transitions: [] }
							: scene,
					)
				: project.scenes,
		},
		skipped: false,
	};
}
