// OMP-specific rendering of Firstmate's harness-neutral Calm working ship.
// The sprite state and geometry stay in the shared Calm module; this file only
// maps its color classes to OMP-safe ANSI foreground sequences and owns the
// OMP lifecycle adapter helpers.
import {
  CALM_WORKING_SHIP_TICK_MS,
  CALM_WORKING_SHIP_TICKS_PER_MOVE,
  createCalmWorkingShipSprite,
  type CalmWorkingShipColor,
  type CalmWorkingShipRun,
  type CalmWorkingShipSprite,
} from "../../../.claude/mods/firstmate-calm/lib/fm-calm-working-ship-sprite.ts";
import {
  calmPresentationHides as sharedCalmPresentationHides,
  type CalmTranscriptClass,
} from "../../../.claude/mods/firstmate-calm/lib/fm-calm-visibility.ts";

export function calmOmpPresentationHides(
  active: boolean,
  itemClass: CalmTranscriptClass,
  stockExportRendering = false,
): boolean {
  return sharedCalmPresentationHides(active, itemClass, stockExportRendering);
}

export type CalmOmpComponent = {
  render: (width: number) => string[];
  invalidate: () => void;
  dispose?: () => void;
};

export function createEmptyCalmComponent(): CalmOmpComponent {
  return { render: () => [], invalidate: () => {}, dispose: () => {} };
}

export {
  CALM_WORKING_SHIP_TICK_MS,
  CALM_WORKING_SHIP_TICKS_PER_MOVE,
  createCalmWorkingShipSprite,
};
export type { CalmWorkingShipSprite };

const ANSI_FOREGROUND: Record<Exclude<CalmWorkingShipColor, "plain">, string> = {
  water: "\u001b[34m",
  boat: "\u001b[33m",
};
const RESET = "\u001b[39m";

function paintRun(run: CalmWorkingShipRun): string {
  if (run.color === "plain") return run.text;
  return `${ANSI_FOREGROUND[run.color]}${run.text}${RESET}`;
}

/** Render one shared sprite frame, recomputing its track for every requested width. */
export function renderCalmWorkingShip(sprite: CalmWorkingShipSprite, width: number): string[] {
  return sprite.frame(width).map((row) => row.map(paintRun).join(""));
}

/** Render the frame in the native working-message string form. */
export function renderCalmWorkingShipMessage(sprite: CalmWorkingShipSprite, width: number): string {
  return renderCalmWorkingShip(sprite, width).join("\n");
}

/** One diagnostic per unsupported or failed OMP presentation seam. */
export function reportCalmAdapterFailure(name: string, error: unknown, report = console.error): void {
  const detail = error instanceof Error ? error.message : String(error);
  report(`Firstmate Calm: ${name} presentation adapter unavailable, skipping. ${detail}`);
}

/** Install one adapter without allowing its OMP API seam to block other adapters. */
export function installCalmAdapter(name: string, install: () => void, report = console.error): boolean {
  try {
    install();
    return true;
  } catch (error) {
    reportCalmAdapterFailure(name, error, report);
    return false;
  }
}
