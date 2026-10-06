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

function ordinaryCalmContentRows(content: unknown): string[] {
  if (typeof content === "string") return content.split(/\r?\n/u);
  if (!Array.isArray(content)) return [];
  return content.flatMap((part) => {
    if (typeof part !== "object" || part === null || !("type" in part) || !("text" in part)) return [];
    const text = (part as { type?: unknown; text?: unknown }).text;
    return (part as { type?: unknown }).type === "text" && typeof text === "string"
      ? text.split(/\r?\n/u)
      : [];
  });
}

export function createCalmSyntheticComponent(
  content: unknown,
  hidden: () => boolean,
): CalmOmpComponent {
  const ordinaryRows = ordinaryCalmContentRows(content);
  return {
    render: () => hidden() ? [] : ordinaryRows,
    invalidate: () => {},
    dispose: () => {},
  };
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

/** Report an unsupported or failed OMP presentation seam. */
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
