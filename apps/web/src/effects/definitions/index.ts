import { effectsRegistry } from "../registry";
import { blurEffectDefinition } from "./blur";
import { super8FrameEffectDefinition } from "./super8-frame";

const defaultEffects = [blurEffectDefinition, super8FrameEffectDefinition];

export function registerDefaultEffects(): void {
	for (const definition of defaultEffects) {
		if (effectsRegistry.has(definition.type)) {
			continue;
		}
		effectsRegistry.register({
			key: definition.type,
			definition,
		});
	}
}
