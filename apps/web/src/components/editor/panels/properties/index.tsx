"use client";

import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import {
	Tooltip,
	TooltipContent,
	TooltipProvider,
	TooltipTrigger,
} from "@/components/ui/tooltip";
import { useEditor } from "@/editor/use-editor";
import { useElementSelection } from "@/timeline/hooks/element/use-element-selection";
import { usePropertiesStore } from "./stores/properties-store";
import { getPropertiesConfig } from "./registry";
import { cn } from "@/utils/ui";
import { EmptyView } from "./empty-view";
import type { ElementRef } from "@/timeline";
import { RemoveTransitionCommand, SetTransitionCommand } from "@/commands/transitions";
import { UpdateFilmRollSixCommand } from "@/commands/transitions";
import { transitionCatalog } from "@/transitions/catalog";
import { mediaTimeFromSeconds, mediaTimeToSeconds } from "@/wasm";

export function PropertiesPanel() {
	const editor = useEditor();
	useEditor((e) => e.scenes.getActiveSceneOrNull());
	useEditor((e) => e.media.getAssets());
	const { selectedElements } = useElementSelection();
	const { activeTabPerType, setActiveTab } = usePropertiesStore();

	if (selectedElements.length === 0) {
		return (
			<div className="panel bg-background flex h-full flex-col items-center justify-center overflow-hidden rounded-sm border">
				<EmptyView />
			</div>
		);
	}

	if (selectedElements.length > 1) {
		if (selectedElements.length === 2) {
			return <TransitionProperties selectedElements={selectedElements} />;
		}
		return (
			<div className="panel bg-background flex h-full flex-col items-center justify-center overflow-hidden rounded-sm border">
				<p className="text-muted-foreground text-sm">
					{selectedElements.length} elements selected.0
				</p>
			</div>
		);
	}

	const filmRoll = editor.scenes
		.getActiveScene()
		.filmRollSix.find(
			(instance) => instance.elementId === selectedElements[0]?.elementId,
		);
	if (filmRoll) {
		return <FilmRollSixProperties instance={filmRoll} />;
	}

	const mediaAssets = editor.media.getAssets();

	const elementsWithTracks = editor.timeline.getElementsWithTracks({
		elements: selectedElements,
	});
	const elementWithTrack = elementsWithTracks[0];

	if (!elementWithTrack) return null;

	const { element, track } = elementWithTrack;
	const config = getPropertiesConfig({ element, mediaAssets });
	const visibleTabs = config.tabs;

	const storedTabId = activeTabPerType[element.type];
	const isStoredTabVisible = visibleTabs.some((t) => t.id === storedTabId);
	const activeTabId = isStoredTabVisible ? storedTabId : config.defaultTab;
	const activeTab =
		visibleTabs.find((t) => t.id === activeTabId) ?? visibleTabs[0];

	if (!activeTab) return null;

	return (
		<div className="panel bg-background flex h-full overflow-hidden rounded-sm border">
			<TooltipProvider delayDuration={0}>
				<div className="flex shrink-0 flex-col gap-0.5 border-r p-1 scrollbar-hidden overflow-y-auto">
					{visibleTabs.map((tab) => (
						<Tooltip key={tab.id}>
							<TooltipTrigger asChild>
								<Button
									variant={tab.id === activeTab.id ? "secondary" : "ghost"}
									size="icon"
									onClick={() =>
										setActiveTab({
											elementType: element.type,
											tabId: tab.id,
										})
									}
									aria-label={tab.label}
									className={cn(
										"shrink-0",
										"h-8 w-8",
										tab.id !== activeTab.id && "text-muted-foreground",
									)}
								>
									{tab.icon}
								</Button>
							</TooltipTrigger>
							<TooltipContent side="right">{tab.label}</TooltipContent>
						</Tooltip>
					))}
				</div>
			</TooltipProvider>
			<ScrollArea className="flex-1 scrollbar-hidden">
				{activeTab.content({ trackId: track.id })}
			</ScrollArea>
		</div>
	);
}

function FilmRollSixProperties({
	instance,
}: {
	instance: import("@/timeline").FilmRollSixInstance;
}) {
	const editor = useEditor();
	const images = editor.media.getAssets().filter((asset) => asset.type === "image");
	const updateSources = ({ index, mediaId }: { index: number; mediaId: string }) => {
		const mediaIds = [...instance.mediaIds] as typeof instance.mediaIds;
		mediaIds[index] = mediaId;
		editor.command.execute({
			command: new UpdateFilmRollSixCommand({ id: instance.id, patch: { mediaIds } }),
		});
	};
	return (
		<div className="panel bg-background h-full overflow-y-auto rounded-sm border p-4">
			<h3 className="mb-4 text-sm font-medium">Film Roll Six</h3>
			{instance.mediaIds.map((mediaId, index) => (
				<label key={`${index}-${mediaId}`} className="mb-3 block text-xs text-muted-foreground">
					Image {index + 1}
					<select
						value={mediaId}
						onChange={(event) =>
							updateSources({ index, mediaId: event.target.value })
						}
						className="bg-background mt-1 h-8 w-full rounded border px-2 text-foreground"
					>
						{images.map((image) => (
							<option key={image.id} value={image.id}>
								{image.name}
							</option>
						))}
					</select>
				</label>
			))}
			<label className="block text-xs text-muted-foreground">
				Largeur de pellicule ({instance.stripWidth.toFixed(2)})
				<input
					type="range"
					min={0.2}
					max={1}
					step={0.01}
					value={instance.stripWidth}
					onChange={(event) =>
						editor.command.execute({
							command: new UpdateFilmRollSixCommand({
								id: instance.id,
								patch: { stripWidth: Number(event.target.value) },
							}),
						})
					}
					className="mt-1 w-full"
				/>
			</label>
		</div>
	);
}

function TransitionProperties({
	selectedElements,
}: {
	selectedElements: ElementRef[];
}) {
	const editor = useEditor();
	const scene = editor.scenes.getActiveScene();
	const selectedIds = new Set(selectedElements.map((item) => item.elementId));
	const transition = scene.transitions.find(
		(item) => selectedIds.has(item.fromElementId) && selectedIds.has(item.toElementId),
	);
	if (!transition) {
		return (
			<div className="panel bg-background flex h-full items-center justify-center rounded-sm border p-6 text-center">
				<p className="text-muted-foreground text-sm">
					Aucune transition entre ces deux éléments.
				</p>
			</div>
		);
	}
	const definition = transitionCatalog.find((item) => item.id === transition.type);
	const update = (patch: Partial<typeof transition>) => {
		editor.command.execute({
			command: new SetTransitionCommand({ ...transition, ...patch }),
		});
	};

	return (
		<div className="panel bg-background h-full overflow-y-auto rounded-sm border p-4">
			<h3 className="mb-4 text-sm font-medium">{definition?.name ?? transition.type}</h3>
			<label className="mb-4 block text-xs text-muted-foreground">
				Durée (secondes)
				<input
					type="number"
					min={0.05}
					step={0.05}
					value={mediaTimeToSeconds({ time: transition.duration })}
					onChange={(event) =>
						update({
							duration: mediaTimeFromSeconds({
								seconds: Math.max(0.05, Number(event.target.value)),
							}),
						})
					}
					className="bg-background mt-1 h-8 w-full rounded border px-2 text-foreground"
				/>
			</label>
			{definition?.params.map((param) => (
				<label key={param.key} className="mb-3 block text-xs text-muted-foreground">
					{param.label}
					<input
						type="range"
						min={param.min}
						max={param.max}
						step={param.step}
						value={Number(transition.params[param.key] ?? param.default)}
						onChange={(event) =>
							update({
								params: {
									...transition.params,
									[param.key]: Number(event.target.value),
								},
							})
						}
						className="mt-1 w-full"
					/>
				</label>
			))}
			<Button
				variant="destructive"
				size="sm"
				onClick={() =>
					editor.command.execute({
						command: new RemoveTransitionCommand(transition.id),
					})
				}
			>
				Supprimer la transition
			</Button>
		</div>
	);
}
