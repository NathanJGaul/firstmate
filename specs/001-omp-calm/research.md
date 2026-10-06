# OMP Calm presentation research

## Decision: Use the native OMP extension module root and API seams that are present in OMP 18.6.1

- OMP 18.6.1 discovers TypeScript modules from `<cwd>/.omp/extensions` without a separate install or trust prompt.
- The extension factory receives `ExtensionAPI` with `registerCommand`, lifecycle `on`, `registerMessageRenderer`, and runtime UI actions.
- `ExtensionUIContext.setWorkingMessage()` replaces the native working-row label and requests the host's ordinary working-row rendering.
- `ExtensionContext.setInterval()` provides a managed timer handle that the extension clears with `clearTimer()` during session shutdown.
- `ExtensionContext.ui.setToolsExpanded()` requests the host's ordinary tool-row redraw, but it does not provide a supported custom-entry invalidation or remount seam and is not used as a substitute for one.

## Decision: Keep the shared preference and policy pure

- Reuse `.claude/mods/firstmate-calm/lib/fm-calm-presentation.ts` for `config/calm` path resolution, `on`/`max` parsing, and `on`/`off` serialization.
- Reuse the harness-neutral visibility policy at OMP's supported synthetic-message boundary; do not apply the working-note or operational-input classifiers where OMP exposes no row-rendering boundary.
- Reuse `.claude/mods/firstmate-calm/lib/fm-calm-working-ship-sprite.ts` for geometry and deterministic animation state.
- OMP projects continue to use the effective home selected by `FM_HOME`, then `FM_ROOT_OVERRIDE`, with `FM_CONFIG_OVERRIDE` naming the config directory outright.

## Decision: Use OMP's supported presentation boundaries and diagnose the rest

- `registerMessageRenderer(customType, renderer)` can control custom-message presentation, so the legacy Firstmate synthetic presentation entry can be zero-height while Calm is active when this seam is available.
- OMP exposes no supported native tool-row renderer through the extension surface used here, so native tool rows remain ordinary and Calm does not claim same-name tools.
- OMP does not expose `setWorkingVisible()` or a custom-entry invalidation/remount action in its current `ExtensionUIContext`; `setWorkingMessage()` is the verified working-row seam. Calm therefore animates a width-bounded projection of the shared ship in OMP's native working row and does not claim a second editor widget, a hidden stock row, or retroactive remounts.
- OMP's `registerAssistantThinkingRenderer()` adds supplemental UI below already-visible thinking and cannot remove the host's thinking row. OMP has no generic user-row or transcript-container filter. Operational user rows and ordinary assistant working-note rows remain visible as an explicit unsupported boundary, with a diagnostic naming the missing seam rather than mutating messages or provider context.
- Each adapter is installed independently and catches its own missing API or registration failure. The `/calm` command, shared preference, working row, and any other successful adapter remain available.

## Decision: Preserve model and session semantics by drawing only

- `/calm` writes the existing preference atomically and changes only in-process presentation state.
- Native tool rows remain host-owned; Calm does not register same-name wrappers or alter tool arguments and results.
- Message renderers return a presentation component only; they do not rewrite or remove stored messages.
- The working animation is transient UI state driven by lifecycle events and managed timers; it creates no session entry or model content.

## Alternatives rejected

- A second `config/omp-calm` file would split the existing cross-harness contract and make the last choice depend on the harness.
- Filtering `input`, `context`, or persisted session messages would change semantics rather than presentation and would violate the preservation requirement.
- A widget above the editor would leave OMP's native working row visible and add a second row, so it is not the primary OMP working path.
- Patching OMP's installed binary or reaching into undocumented internal transcript components would not be a supported extension API and would not degrade safely.

## Evidence

- OMP version observed locally: `omp v18.6.1`.
- Official extension loading documentation: https://github.com/can1357/oh-my-pi/blob/main/docs/extension-loading.md.
- Official extension API documentation: https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md.
- OMP `ExtensionUIContext` types document `setWorkingMessage`, `setWidget`, and `setToolsExpanded`, but no `setWorkingVisible`.
