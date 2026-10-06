// Firstmate Calm presentation for OMP (Oh My Pi).
//
// The extension deliberately keeps preference policy in the harness-neutral Calm
// module. OMP's presentation adapters are installed independently below so an API
// seam can degrade without disabling /calm or another adapter.
import { randomUUID } from "node:crypto";
import {
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  calmPreferencePath,
  parseCalmPreference,
  serializeCalmPreference,
} from "../../.claude/mods/firstmate-calm/lib/fm-calm-presentation.ts";
import {
  CALM_WORKING_SHIP_TICK_MS,
  calmOmpPresentationHides,
  createCalmWorkingShipSprite,
  createEmptyCalmComponent,
  installCalmAdapter,
  renderCalmWorkingShipMessage,
  type CalmWorkingShipSprite,
} from "./lib/fm-calm-omp-presentation.ts";
import {
  FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE,
} from "../../.claude/mods/firstmate-calm/lib/fm-calm-visibility.ts";
type OmpUi = {
  notify?: (message: string, level?: string) => void;
  setWorkingMessage?: (message?: string) => void;
};

type OmpExtensionContext = {
  ui?: OmpUi;
  setInterval?: (callback: () => void, milliseconds: number) => unknown;
  clearTimer?: (timer: unknown) => void;
};

type OmpCommandContext = OmpExtensionContext;

type OmpMessageRenderer = (message: { customType?: string; content?: unknown }, options: unknown, theme: unknown) => unknown;

type OmpExtensionApi = {
  on?: (event: string, handler: (event: unknown, ctx: OmpExtensionContext) => unknown) => void;
  registerCommand?: (name: string, command: { description: string; handler: (args: string, ctx: OmpCommandContext) => Promise<void> | void }) => void;
  registerMessageRenderer?: (customType: string, renderer: OmpMessageRenderer) => void;
};

const extensionFile = fileURLToPath(import.meta.url);
const extensionRoot = resolve(dirname(extensionFile), "../..");
const sharedPolicyRoot = resolve(extensionRoot, ".claude/mods/firstmate-calm");
const preferencePath = calmPreferencePath(process.env, sharedPolicyRoot);
const WORKING_MESSAGE_MARGIN = 2;

function agentEndWillContinue(event: unknown): boolean {
  return typeof event === "object" && event !== null && "willContinue" in event && (event as { willContinue?: unknown }).willContinue === true;
}

function workingMessageWidth(): number | undefined {
  const columns = process.stdout.columns;
  if (typeof columns !== "number" || !Number.isFinite(columns)) return undefined;
  return Math.max(0, Math.floor(columns) - WORKING_MESSAGE_MARGIN);
}

function loadCalmPreference(): boolean {
  try {
    return parseCalmPreference(readFileSync(preferencePath, "utf8"));
  } catch {
    return false;
  }
}

function persistCalmPreference(active: boolean): void {
  mkdirSync(dirname(preferencePath), { recursive: true });
  const temporaryPath = `${preferencePath}.${process.pid}.${randomUUID()}.tmp`;
  try {
    writeFileSync(temporaryPath, serializeCalmPreference(active), {
      encoding: "utf8",
      flag: "wx",
      mode: 0o600,
    });
    renameSync(temporaryPath, preferencePath);
  } finally {
    rmSync(temporaryPath, { force: true });
  }
}

function notify(ctx: OmpCommandContext, message: string, level: string): void {
  installCalmAdapter("notification", () => {
    if (!ctx.ui?.notify) throw new Error("OMP extension API does not expose ui.notify");
    ctx.ui.notify(message, level);
  });
}

function clearManagedTimer(ctx: OmpExtensionContext, timer: unknown): void {
  if (!ctx.clearTimer) throw new Error("OMP extension API does not expose clearTimer");
  ctx.clearTimer(timer);
}

export default function (pi: OmpExtensionApi): void {
  let calmActive = loadCalmPreference();
  let workingMessageAdapterAvailable: boolean | undefined;
  let workingMessageWidthAvailable: boolean | undefined;
  let workingTimerAdapterAvailable: boolean | undefined;
  const ensureWorkingMessageAdapter = (ctx: OmpExtensionContext): boolean => {
    if (workingMessageAdapterAvailable !== undefined) return workingMessageAdapterAvailable;
    workingMessageAdapterAvailable = installCalmAdapter("working-message", () => {
      if (!ctx.ui?.setWorkingMessage) throw new Error("OMP extension API does not expose ui.setWorkingMessage");
    });
    return workingMessageAdapterAvailable;
  };
  const ensureWorkingTimerAdapter = (ctx: OmpExtensionContext): boolean => {
    if (workingTimerAdapterAvailable !== undefined) return workingTimerAdapterAvailable;
    workingTimerAdapterAvailable = installCalmAdapter("working-message timer", () => {
      if (!ctx.setInterval || !ctx.clearTimer) {
        throw new Error("OMP extension API does not expose the managed setInterval/clearTimer pair");
      }
    });
    return workingTimerAdapterAvailable;
  };
  const getWorkingMessageWidth = (): number | undefined => {
    const width = workingMessageWidth();
    if (width === undefined) {
      if (workingMessageWidthAvailable !== false) {
        workingMessageWidthAvailable = installCalmAdapter("working-message width", () => {
          throw new Error("process.stdout.columns is unavailable or non-finite");
        });
      }
      return undefined;
    }
    workingMessageWidthAvailable = true;
    return width;
  };
  let agentRunActive = false;
  let workingTimer: unknown;
  let workingTimerContext: OmpExtensionContext | undefined;
  let workingMessageOwned = false;
  let latestContext: OmpExtensionContext | undefined;
  const workingShip: CalmWorkingShipSprite = createCalmWorkingShipSprite();

  const installLegacyMessageRenderer = (): void => {
    if (!pi.registerMessageRenderer) throw new Error("OMP extension API does not expose registerMessageRenderer");
    pi.registerMessageRenderer(FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE, () => {
      if (!calmOmpPresentationHides(calmActive, "synthetic-user")) return undefined;
      return createEmptyCalmComponent();
    });
  };

  installCalmAdapter("legacy custom-message renderer", installLegacyMessageRenderer);
  // OMP deliberately has no generic transcript-row renderer. Keep this boundary
  // explicit and visible rather than pretending unsupported rows can be hidden.
  installCalmAdapter("generic transcript-row renderer", () => {
    throw new Error("OMP exposes no generic transcript-row renderer; unsupported rows remain visible");
  });


  const clearWorkingTimer = (): boolean => {
    const timer = workingTimer;
    const timerContext = workingTimerContext;
    let cleared = true;
    if (timer !== undefined) {
      cleared = timerContext !== undefined && installCalmAdapter("working-message timer", () => {
        clearManagedTimer(timerContext, timer);
      });
      if (cleared) {
        workingTimer = undefined;
        workingTimerContext = undefined;
      }
    }
    workingShip.restoreLastRendered();
    return cleared;
  };

  const setWorkingMessage = (ctx: OmpExtensionContext, message?: string): boolean => {
    if (!ensureWorkingMessageAdapter(ctx)) return false;
    const applied = installCalmAdapter("working-message", () => {
      if (message === undefined) ctx.ui!.setWorkingMessage!();
      else ctx.ui!.setWorkingMessage!(message);
    });
    if (applied) workingMessageOwned = message !== undefined;
    return applied;
  };

  const restoreStockWorkingMessage = (ctx: OmpExtensionContext): boolean => {
    if (workingMessageOwned && !setWorkingMessage(ctx)) return false;
    return clearWorkingTimer();
  };

  const refreshWorkingMessage = (ctx: OmpExtensionContext): boolean => {
    latestContext = ctx;
    if (!calmActive || !agentRunActive) return restoreStockWorkingMessage(ctx);
    const width = getWorkingMessageWidth();
    if (width === undefined) {
      restoreStockWorkingMessage(ctx);
      return false;
    }
    return setWorkingMessage(ctx, renderCalmWorkingShipMessage(workingShip, width));
  };

  const startWorkingPresentation = (ctx: OmpExtensionContext): boolean => {
    latestContext = ctx;
    if (!agentRunActive && (workingTimer !== undefined || workingMessageOwned)) {
      if (!restoreStockWorkingMessage(ctx)) return false;
    }
    agentRunActive = true;
    const workingMessageAvailable = ensureWorkingMessageAdapter(ctx);
    const workingTimerAvailable = calmActive && ensureWorkingTimerAdapter(ctx);
    if (!workingMessageAvailable || !refreshWorkingMessage(ctx)) return false;
    if (!calmActive || workingTimer !== undefined || !workingTimerAvailable) return true;
    const callback = (): void => {
      workingShip.tick();
      const activeContext = latestContext ?? ctx;
      if (!refreshWorkingMessage(activeContext) && !workingMessageOwned) clearWorkingTimer();
    };
    const timerStarted = installCalmAdapter("working-message timer", () => {
      if (!ctx.setInterval) throw new Error("OMP extension API does not expose setInterval");
      workingTimer = ctx.setInterval(callback, CALM_WORKING_SHIP_TICK_MS);
      workingTimerContext = ctx;
    });
    if (!timerStarted) {
      workingTimerAdapterAvailable = false;
      return false;
    }
    return true;
  };

  const stopWorkingPresentation = (ctx: OmpExtensionContext): boolean => {
    agentRunActive = false;
    latestContext = ctx;
    return restoreStockWorkingMessage(ctx);
  };

  installCalmAdapter("session lifecycle", () => {
    if (!pi.on) throw new Error("OMP extension API does not expose on");
    pi.on("session_start", (_event, ctx) => {
      calmActive = loadCalmPreference();
      agentRunActive = false;
      workingShip.reset();
      latestContext = ctx;
      restoreStockWorkingMessage(ctx);
    });
    pi.on("agent_start", (_event, ctx) => startWorkingPresentation(ctx));
    pi.on("agent_end", (event, ctx) => {
      if (!agentEndWillContinue(event)) stopWorkingPresentation(ctx);
    });
    pi.on("session_shutdown", (_event, ctx) => stopWorkingPresentation(ctx));
  });

  installCalmAdapter("command", () => {
    if (!pi.registerCommand) throw new Error("OMP extension API does not expose registerCommand");
    pi.registerCommand("calm", {
      description: "Toggle Firstmate Calm presentation.",
      handler: async (_args, ctx) => {
        const next = !calmActive;
        try {
          persistCalmPreference(next);
        } catch (error) {
          const detail = error instanceof Error ? error.message : String(error);
          notify(ctx, `Firstmate Calm: could not save preference. ${detail}`, "warning");
          return;
        }
        calmActive = next;
        let presentationSucceeded = true;
        if (latestContext && agentRunActive) {
          presentationSucceeded = next
            ? startWorkingPresentation(latestContext)
            : refreshWorkingMessage(latestContext);
        } else if (!next) {
          presentationSucceeded = restoreStockWorkingMessage(ctx);
        }
        notify(
          ctx,
          `Firstmate Calm: ${next ? "on" : "off"}${presentationSucceeded ? "" : " (presentation update pending)"}`,
          presentationSucceeded ? "info" : "warning",
        );
      },
    });
  });
}
