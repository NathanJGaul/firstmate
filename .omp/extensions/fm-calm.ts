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
  type CalmOmpComponent,
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
  const width = Math.floor(columns) - WORKING_MESSAGE_MARGIN;
  return width > 0 ? width : undefined;
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

function clearManagedTimer(ctx: OmpExtensionContext, timer: unknown): void {
  if (!ctx.clearTimer) throw new Error("OMP extension API does not expose clearTimer");
  ctx.clearTimer(timer);
}

export default function (pi: OmpExtensionApi): void {
  const reportedAdapterFailures = new Set<string>();
  const installAdapter = (name: string, install: () => void, key = name): boolean => installCalmAdapter(name, install, (diagnostic) => {
    if (reportedAdapterFailures.has(key)) return;
    reportedAdapterFailures.add(key);
    console.error(diagnostic);
  });
  const notify = (ctx: OmpCommandContext, message: string, level: string): void => {
    installAdapter("notification", () => {
      if (!ctx.ui?.notify) throw new Error("OMP extension API does not expose ui.notify");
      ctx.ui.notify(message, level);
    });
  };
  const readCalmPreference = (fallback: boolean): boolean => {
    try {
      return parseCalmPreference(readFileSync(preferencePath, "utf8"));
    } catch (error) {
      if (typeof error === "object" && error !== null && "code" in error && (error as { code?: unknown }).code === "ENOENT") {
        return false;
      }
      installAdapter("preference read", () => {
        throw error;
      });
      return fallback;
    }
  };
  let calmActive = readCalmPreference(false);
  const ensureWorkingMessageAdapter = (ctx: OmpExtensionContext): boolean => installAdapter("working-message", () => {
    if (!ctx.ui?.setWorkingMessage) throw new Error("OMP extension API does not expose ui.setWorkingMessage");
  });
  const ensureWorkingTimerAdapter = (ctx: OmpExtensionContext): boolean => installAdapter("working-message timer", () => {
    if (!ctx.setInterval || !ctx.clearTimer) {
      throw new Error("OMP extension API does not expose the managed setInterval/clearTimer pair");
    }
  });
  const getWorkingMessageWidth = (): number | undefined => {
    const width = workingMessageWidth();
    if (width === undefined) {
      installAdapter("working-message width", () => {
        throw new Error("process.stdout.columns is unavailable, non-finite, or too narrow");
      });
      return undefined;
    }
    return width;
  };
  type OmpRun = {
    sessionId: number;
    context: OmpExtensionContext;
  };
  let activeRun: OmpRun | undefined;
  let workingTimer: unknown;
  let workingTimerContext: OmpExtensionContext | undefined;
  let workingTimerRun: OmpRun | undefined;
  let workingMessageOwned = false;
  let latestContext: OmpExtensionContext | undefined;
  let sessionId = 0;
  const workingShip: CalmWorkingShipSprite = createCalmWorkingShipSprite();
  const mountedSyntheticRows = new Set<CalmOmpComponent>();
  const invalidateMountedSyntheticRows = (): boolean => {
    let succeeded = true;
    for (const component of mountedSyntheticRows) {
      const invalidated = installAdapter(
        "legacy custom-message renderer invalidation",
        () => component.invalidate(),
        "legacy custom-message renderer invalidation",
      );
      succeeded = invalidated && succeeded;
    }
    return succeeded;
  };
  const rememberRunContext = (ctx: OmpExtensionContext): void => {
    latestContext = ctx;
    if (activeRun) activeRun.context = ctx;
  };

  const installLegacyMessageRenderer = (): void => {
    if (!pi.registerMessageRenderer) throw new Error("OMP extension API does not expose registerMessageRenderer");
    pi.registerMessageRenderer(FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE, () => {
      if (!calmOmpPresentationHides(calmActive, "synthetic-user")) return undefined;
      const component = createEmptyCalmComponent();
      mountedSyntheticRows.add(component);
      const dispose = component.dispose;
      component.dispose = () => {
        mountedSyntheticRows.delete(component);
        dispose?.();
      };
      return component;
    });
  };

  installAdapter("legacy custom-message renderer", installLegacyMessageRenderer);
  // OMP deliberately has no generic transcript-row renderer. Keep this boundary
  // explicit and visible rather than pretending unsupported rows can be hidden.
  installAdapter("generic transcript-row renderer", () => {
    throw new Error("OMP exposes no generic transcript-row renderer; unsupported rows remain visible");
  });


  const clearWorkingTimer = (): boolean => {
    const timer = workingTimer;
    const timerContext = workingTimerContext;
    let cleared = true;
    if (timer !== undefined) {
      cleared = timerContext !== undefined && installAdapter("working-message timer", () => {
        clearManagedTimer(timerContext, timer);
      }, "working-message clearTimer");
      if (cleared) {
        workingTimer = undefined;
        workingTimerContext = undefined;
        workingTimerRun = undefined;
      }
    }
    workingShip.restoreLastRendered();
    return cleared;
  };

  const setWorkingMessage = (ctx: OmpExtensionContext, message?: string): boolean => {
    if (!ensureWorkingMessageAdapter(ctx)) return false;
    const applied = installAdapter("working-message", () => {
      if (message === undefined) ctx.ui!.setWorkingMessage!();
      else ctx.ui!.setWorkingMessage!(message);
    });
    if (applied) workingMessageOwned = message !== undefined;
    return applied;
  };

  const restoreWorkingMessageOnly = (ctx: OmpExtensionContext): boolean => {
    if (!workingMessageOwned) return true;
    return setWorkingMessage(ctx);
  };

  const restoreStockWorkingMessage = (ctx: OmpExtensionContext): boolean => {
    if (!restoreWorkingMessageOnly(ctx)) return false;
    return clearWorkingTimer();
  };

  const refreshWorkingMessage = (ctx: OmpExtensionContext): boolean => {
    rememberRunContext(ctx);
    if (!calmActive || !activeRun) return restoreStockWorkingMessage(ctx);
    const width = getWorkingMessageWidth();
    if (width === undefined) {
      restoreWorkingMessageOnly(ctx);
      workingShip.restoreLastRendered();
      return false;
    }
    const applied = setWorkingMessage(ctx, renderCalmWorkingShipMessage(workingShip, width));
    if (!applied) workingShip.restoreLastRendered();
    return applied;
  };

  const startWorkingPresentation = (ctx: OmpExtensionContext): boolean => {
    rememberRunContext(ctx);
    const run = activeRun ?? { sessionId, context: ctx };
    run.context = ctx;
    activeRun = run;

    if (workingTimer !== undefined && workingTimerRun !== run) {
      if (!restoreStockWorkingMessage(ctx)) return false;
      if (workingTimer !== undefined) return false;
    }
    if (!calmActive) return true;

    const workingMessageAvailable = ensureWorkingMessageAdapter(ctx);
    if (!workingMessageAvailable) return false;
    getWorkingMessageWidth();
    const workingTimerAvailable = ensureWorkingTimerAdapter(ctx);
    if (workingTimer !== undefined) return refreshWorkingMessage(ctx);
    if (!workingTimerAvailable) return false;
    const timerRun = run;
    const callback = (): void => {
      if (workingTimerRun !== timerRun) return;
      const currentRun = activeRun;
      const activeContext = currentRun?.context ?? latestContext ?? ctx;
      if (!currentRun || currentRun !== timerRun) {
        if (!restoreStockWorkingMessage(activeContext)) return;
        if (activeRun && activeRun.sessionId === sessionId && workingTimer === undefined) {
          startWorkingPresentation(activeRun.context);
        }
        return;
      }
      if (!calmActive) {
        restoreStockWorkingMessage(activeContext);
        return;
      }
      workingShip.tick();
      refreshWorkingMessage(activeContext);
    };
    const timerStarted = installAdapter("working-message timer", () => {
      if (!ctx.setInterval) throw new Error("OMP extension API does not expose setInterval");
      const timer = ctx.setInterval(callback, CALM_WORKING_SHIP_TICK_MS);
      if (timer === undefined) throw new Error("OMP extension API did not return a managed timer handle");
      workingTimer = timer;
      workingTimerContext = ctx;
      workingTimerRun = timerRun;
    });
    if (!timerStarted) {
      restoreWorkingMessageOnly(ctx);
      return false;
    }
    return refreshWorkingMessage(ctx);
  };

  const stopWorkingPresentation = (ctx: OmpExtensionContext): boolean => {
    activeRun = undefined;
    latestContext = ctx;
    return restoreStockWorkingMessage(ctx);
  };

  installAdapter("session lifecycle", () => {
    if (!pi.on) throw new Error("OMP extension API does not expose on");
    pi.on("session_start", (_event, ctx) => {
      sessionId += 1;
      activeRun = undefined;
      calmActive = readCalmPreference(calmActive);
      invalidateMountedSyntheticRows();
      workingShip.reset();
      latestContext = ctx;
      restoreStockWorkingMessage(ctx);
    });
    pi.on("agent_start", (_event, ctx) => startWorkingPresentation(ctx));
    pi.on("agent_end", (event, ctx) => {
      if (agentEndWillContinue(event)) {
        rememberRunContext(ctx);
        return;
      }
      stopWorkingPresentation(ctx);
    });
    pi.on("session_shutdown", (_event, ctx) => stopWorkingPresentation(ctx));
  });

  installAdapter("command", () => {
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
        let presentationSucceeded = invalidateMountedSyntheticRows();
        if (activeRun) {
          rememberRunContext(ctx);
          const workingPresentationSucceeded = next
            ? startWorkingPresentation(ctx)
            : refreshWorkingMessage(ctx);
          presentationSucceeded = workingPresentationSucceeded && presentationSucceeded;
        } else if (!next) {
          presentationSucceeded = restoreStockWorkingMessage(ctx) && presentationSucceeded;
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
