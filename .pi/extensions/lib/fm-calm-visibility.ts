import {
  getMarkdownTheme,
  type ExtensionAPI,
  UserMessageComponent,
} from "@earendil-works/pi-coding-agent";
import {
  calmPresentationHides as sharedCalmPresentationHides,
  calmTranscriptClassIsVisible,
  CALM_TRANSCRIPT_CLASSES,
  FIRSTMATE_CALM_PRESENTATION_EVENT,
  FIRSTMATE_SYNTHETIC_KINDS,
  FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE,
  type CalmPresentationState,
  type CalmTranscriptClass,
  type FirstmateSyntheticKind,
} from "./fm-calm-visibility-policy.ts";

export {
  calmTranscriptClassIsVisible,
  CALM_TRANSCRIPT_CLASSES,
  FIRSTMATE_CALM_PRESENTATION_EVENT,
  FIRSTMATE_SYNTHETIC_KINDS,
  FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE,
};
export type { CalmPresentationState, CalmTranscriptClass, FirstmateSyntheticKind };

let calm = false;
let stockExportRendering = false;

type FirstmateSyntheticPresentation = {
  content: string;
  kind: FirstmateSyntheticKind;
};

export function setCalmPresentation(active: boolean): void {
  calm = active;
}

export function setCalmStockExportRendering(active: boolean): void {
  stockExportRendering = active;
}

export function calmPresentationIsActive(): boolean {
  return calm;
}

export function calmPresentationHides(itemClass: CalmTranscriptClass): boolean {
  return sharedCalmPresentationHides(calm, itemClass, stockExportRendering);
}

export function registerFirstmateSyntheticPresentation(pi: ExtensionAPI): void {
  pi.registerEntryRenderer<FirstmateSyntheticPresentation>(
    FIRSTMATE_SYNTHETIC_PRESENTATION_TYPE,
    (entry) => {
      if (calmPresentationHides("synthetic-user")) return undefined;
      const data = entry.data;
      if (!data || typeof data.content !== "string") return undefined;
      return new UserMessageComponent(data.content, getMarkdownTheme());
    },
  );
}
