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
  type CalmTranscriptClass,
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

type OmpToolInfo = {
  name: string;
  description: string;
  parameters: unknown;
  sourceInfo?: { source?: string };
};

type OmpToolContext = OmpExtensionContext & {
  invokeTool?: (params: Record<string, unknown>, options?: { signal?: unknown; onUpdate?: unknown }) => Promise<unknown>;
};

type OmpToolDefinition = {
  name: string;
  label: string;
  description: string;
  parameters: unknown;
  execute: (toolCallId: string, params: Record<string, unknown>, signal: unknown, onUpdate: unknown, ctx: OmpToolContext) => Promise<unknown>;
  renderCall?: () => unknown;
  renderResult?: () => unknown;
};

type OmpMessageRenderer = (message: { customType?: string; content?: unknown }, options: unknown, theme: unknown) => unknown;

type OmpExtensionApi = {
  on?: (event: string, handler: (event: unknown, ctx: OmpExtensionContext) => unknown) => void;
  registerCommand?: (name: string, command: { description: string; handler: (args: string, ctx: OmpCommandContext) => Promise<void> | void }) => void;
  registerMessageRenderer?: (customType: string, renderer: OmpMessageRenderer) => void;
  getAllTools?: () => OmpToolInfo[];
  registerTool?: (tool: OmpToolDefinition) => void;
};

const extensionFile = fileURLToPath(import.meta.url);
const extensionRoot = resolve(dirname(extensionFile), "../..");
const sharedPolicyRoot = resolve(extensionRoot, ".claude/mods/firstmate-calm");
const preferencePath = calmPreferencePath(process.env, sharedPolicyRoot);
const WORKING_MESSAGE_WIDTH = 40;

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
  ctx.ui?.notify?.(message, level);
}

function clearManagedTimer(ctx: OmpExtensionContext, timer: unknown): void {
  ctx.clearTimer?.(timer);
}

export default function (pi: OmpExtensionApi): void {
  let calmActive = loadCalmPreference();
  let workingMessageAdapterAvailable: boolean | undefined;
  const ensureWorkingMessageAdapter = (ctx: OmpExtensionContext): boolean => {
    if (workingMessageAdapterAvailable !== undefined) return workingMessageAdapterAvailable;
    workingMessageAdapterAvailable = installCalmAdapter("working-message", () => {
      if (!ctx.ui?.setWorkingMessage) throw new Error("OMP extension API does not expose ui.setWorkingMessage");
    });
    return workingMessageAdapterAvailable;
  };
  let agentRunActive = false;
  let workingTimer: unknown;
  let latestContext: OmpExtensionContext | undefined;
  const workingShip: CalmWorkingShipSprite = createCalmWorkingShipSprite();
  let nativeToolAdaptersInstalled = false;
  const nativeToolNames = ["read", "bash", "edit", "write", "grep", "find", "ls"];

  const installLegacyMessageRenderer = (): void => {
    if (!pi.registerMessageRenderer) throw new Error("OMP extension API does not expose registerMessageRenderer");
    pi.registerMessageRenderer(FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE, () => {
      if (!calmOmpPresentationHides(calmActive, "synthetic-user")) return undefined;
      return createEmptyCalmComponent();
    });
  };

  const installNativeToolAdapters = (): void => {
    if (nativeToolAdaptersInstalled) return;
    if (!pi.getAllTools) throw new Error("OMP extension API does not expose getAllTools");
    if (!pi.registerTool) throw new Error("OMP extension API does not expose registerTool");
    const tools = pi.getAllTools();
    for (const name of nativeToolNames) {
      const native = tools.find((tool) => tool.name === name);
      if (!native) continue;
      if (native.sourceInfo && native.sourceInfo.source !== "builtin") continue;
      const wrapper: OmpToolDefinition = {
        name: native.name,
        label: native.name,
        description: native.description,
        parameters: native.parameters,
        async execute(toolCallId, params, signal, onUpdate, ctx) {
          if (!ctx.invokeTool) throw new Error(`OMP native tool ${name} cannot be delegated: invokeTool is unavailable`);
          return ctx.invokeTool(params, { signal, onUpdate });
        },
        renderCall: () => calmActive ? createEmptyCalmComponent() : undefined,
        renderResult: () => calmActive ? createEmptyCalmComponent() : undefined,
      };
      pi.registerTool(wrapper);
    }
    nativeToolAdaptersInstalled = true;
  };

  installCalmAdapter("legacy custom-message renderer", installLegacyMessageRenderer);
  // OMP deliberately has no generic transcript-row renderer. Keep this boundary
  // explicit and visible rather than pretending unsupported rows can be hidden.
  installCalmAdapter("generic transcript-row renderer", () => {
    throw new Error("OMP exposes no generic transcript-row renderer; unsupported rows remain visible");
  });


  const clearWorkingTimer = (): void => {
    if (workingTimer === undefined || latestContext === undefined) return;
    clearManagedTimer(latestContext, workingTimer);
    workingTimer = undefined;
    workingShip.restoreLastRendered();
  };

  const restoreStockWorkingMessage = (ctx: OmpExtensionContext): void => {
    clearWorkingTimer();
    if (!ensureWorkingMessageAdapter(ctx)) return;
    ctx.ui!.setWorkingMessage!();
  };

  const refreshWorkingMessage = (ctx: OmpExtensionContext): void => {
    latestContext = ctx;
    if (!ensureWorkingMessageAdapter(ctx)) return;
    if (!calmActive || !agentRunActive) {
      restoreStockWorkingMessage(ctx);
      return;
    }
    ctx.ui!.setWorkingMessage!(renderCalmWorkingShipMessage(workingShip, WORKING_MESSAGE_WIDTH));
  };

  const startWorkingPresentation = (ctx: OmpExtensionContext): void => {
    latestContext = ctx;
    agentRunActive = true;
    if (!ensureWorkingMessageAdapter(ctx)) return;
    refreshWorkingMessage(ctx);
    if (!calmActive || workingTimer !== undefined) return;
    if (!ctx.setInterval || !ctx.clearTimer) return;
    workingTimer = ctx.setInterval(() => {
      workingShip.tick();
      refreshWorkingMessage(ctx);
    }, CALM_WORKING_SHIP_TICK_MS);
  };

  const stopWorkingPresentation = (ctx: OmpExtensionContext): void => {
    agentRunActive = false;
    latestContext = ctx;
    restoreStockWorkingMessage(ctx);
  };

  installCalmAdapter("session lifecycle", () => {
    if (!pi.on) throw new Error("OMP extension API does not expose on");
    pi.on("session_start", (_event, ctx) => {
      calmActive = loadCalmPreference();
      if (calmActive) installCalmAdapter("native built-in tool wrappers", installNativeToolAdapters);
      agentRunActive = false;
      workingShip.reset();
      latestContext = ctx;
      restoreStockWorkingMessage(ctx);
    });
    pi.on("agent_start", (_event, ctx) => startWorkingPresentation(ctx));
    pi.on("agent_end", (_event, ctx) => stopWorkingPresentation(ctx));
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
        if (next) {
          installCalmAdapter("native built-in tool wrappers", installNativeToolAdapters);
        }
        if (latestContext && agentRunActive) refreshWorkingMessage(latestContext);
        else if (!next) restoreStockWorkingMessage(ctx);
        notify(ctx, `Firstmate Calm: ${next ? "on" : "off"}`, "info");
      },
    });
  });
}
