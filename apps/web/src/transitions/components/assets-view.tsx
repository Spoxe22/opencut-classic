"use client";

import { toast } from "sonner";
import { PanelView } from "@/components/editor/panels/assets/views/base-panel";
import { useEditor } from "@/editor/use-editor";
import {
	CreateFilmRollSixCommand,
	SetTransitionCommand,
} from "@/commands/transitions";
import { Button } from "@/components/ui/button";
import { generateUUID } from "@/utils/id";
import { mediaTimeFromSeconds, mediaTimeToSeconds } from "@/wasm";
import {
	defaultTransitionParams,
	transitionCatalog,
	type TransitionPresetDefinition,
} from "../catalog";

export function TransitionsView() {
	const editor = useEditor();
	return (
		<PanelView title="Transitions">
			<p className="text-muted-foreground mb-3 px-1 text-xs">
				Sélectionnez deux images adjacentes de la piste principale, puis cliquez
				sur un preset.
			</p>
			<Button
				variant="outline"
				className="mb-3 w-full"
				onClick={() => {
					try {
						editor.command.execute({ command: new CreateFilmRollSixCommand() });
						toast.success("Film Roll Six créé");
					} catch (error) {
						toast.error(
							error instanceof Error ? error.message : "Sélection invalide",
						);
					}
				}}
			>
				Film Roll Six (5 images)
			</Button>
			<div className="grid grid-cols-2 gap-2">
				{transitionCatalog.map((preset, index) => (
					<TransitionCard key={preset.id} preset={preset} index={index} />
				))}
			</div>
		</PanelView>
	);
}

function TransitionCard({
	preset,
	index,
}: {
	preset: TransitionPresetDefinition;
	index: number;
}) {
	const editor = useEditor();

	const apply = () => {
		const scene = editor.scenes.getActiveScene();
		const selected = new Set(
			editor.selection
				.getSelectedElements()
				.filter((item) => item.trackId === scene.tracks.main.id)
				.map((item) => item.elementId),
		);
		const ordered = scene.tracks.main.elements
			.slice()
			.sort((a, b) => a.startTime - b.startTime);
		const indexes = ordered
			.map((element, elementIndex) => (selected.has(element.id) ? elementIndex : -1))
			.filter((elementIndex) => elementIndex >= 0);
		if (indexes.length !== 2 || indexes[1] !== indexes[0] + 1) {
			toast.error("Sélectionnez deux images adjacentes de la piste principale");
			return;
		}
		const from = ordered[indexes[0]];
		const to = ordered[indexes[1]];
		if (from.type !== "image" || to.type !== "image") {
			toast.error("Ce premier lot applique les transitions aux images");
			return;
		}
		const seconds = Math.min(
			1,
			mediaTimeToSeconds({ time: from.duration }) / 2,
			mediaTimeToSeconds({ time: to.duration }) / 2,
		);
		editor.command.execute({
			command: new SetTransitionCommand({
				id: generateUUID(),
				fromElementId: from.id,
				toElementId: to.id,
				type: preset.id,
				duration: mediaTimeFromSeconds({ seconds }),
				params: defaultTransitionParams(preset),
			}),
		});
		toast.success(`${preset.name} appliquée`);
	};

	return (
		<button type="button" className="group text-left" onClick={apply}>
			<div className="bg-accent relative aspect-video overflow-hidden rounded-sm border">
				<div
					className="absolute inset-y-0 left-0 w-[58%] transition-transform duration-500 group-hover:-translate-x-1/3"
					style={{
						background: `linear-gradient(135deg, hsl(${205 + index * 13} 70% 58%), hsl(${255 + index * 9} 65% 22%))`,
					}}
				/>
				<div
					className="absolute inset-y-0 right-0 w-[58%] transition-transform duration-500 group-hover:translate-x-0"
					style={{
						background: `linear-gradient(315deg, hsl(${20 + index * 17} 85% 60%), hsl(${340 + index * 7} 60% 28%))`,
						clipPath: "polygon(18% 0, 100% 0, 100% 100%, 0 100%)",
					}}
				/>
				<div className="absolute inset-0 bg-white/0 transition-colors duration-300 group-hover:bg-white/20" />
			</div>
			<span className="text-muted-foreground mt-1 block truncate text-[0.7rem]" title={preset.name}>
				{preset.name}
			</span>
		</button>
	);
}
