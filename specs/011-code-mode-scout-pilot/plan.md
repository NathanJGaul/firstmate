# Implementation Plan: Code Mode Scout Pilot

**Spec**: `specs/011-code-mode-scout-pilot/spec.md`

## Design

1. `bin/fm-claude-code-mode-lib.sh` (new, sourced by `bin/fm-spawn.sh`) owns the two mechanics:
   - `fm_claude_code_mode_setting <config-dir>` prints `off` or `scouts`, or prints the refusal to stderr and returns 1.
   - `fm_claude_code_mode_accepted <store-dir>` returns 0 only when `<store-dir>/.claude.json` is a readable JSON object whose `codeModeCaveatsAcceptedV1` is `true`; it only reads.
2. `bin/fm-spawn.sh`:
   - Resolve the setting once beside `config/claude-permission-mode`, before any mutation, so a malformed file refuses.
   - Decide per launch, for non-raw `claude` only: on iff kind is `scout`, setting is `scouts`, permission mode is bypass, and the acceptance check passes against the store the worker reads (after the worker account pin exported its root).
   - Splice the result into the existing `env -u CURSOR_AGENT -u CURSOR_INVOKED_AS -u GEMINI_CLI` prefix: `-u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` when off, and a `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1` assignment after the `-u` list when on.
   - Print one `note:` line to stdout before the `spawned` line when a requested Code Mode launch was skipped.
   - The launch-env-allowlist wrapper (`env -i ... /bin/sh -c "$LAUNCH"`) already wraps the whole line, so both forms survive it.
3. `bin/fm-supervision-engine-lib.sh`: `unset CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` inside the engine's subshell before it execs the bounded engine.
4. `bin/fm-config-inherit-lib.sh`: untouched; the knob is not in `FM_INHERITABLE_CONFIG`, and a test pins that.
5. Tests:
   - `tests/fm-spawn-claude-code-mode.test.sh` (new, portable): fake tmux launch capture for every acceptance scenario of Stories 1 to 3, plus a real `env -i` execution of the captured launch with a fake `claude` that records its environment, proving the allowlist and stray-environment cases by behavior.
   - `tests/fm-supervision-engine.test.sh` or the existing engine test: engine does not inherit the variable.
   - `tests/fm-claude-codemode-live-e2e.test.sh` (new, opt-in): the TUI-driven lab of the scout's section 10.
   - Existing golden launch assertions that include the `env -u` prefix gain the new token.
   - Register new tests in `bin/fm-test-run.sh`.
6. Docs, one owner each: `docs/configuration.md` owns the knob; `bin/fm-spawn.sh` header carries the mechanics; the Claude adapter reference's Code Mode table row "Enablement" is rewritten to state what the spawn does; `docs/verification/supervision.md` records the dated live result once the live E2E has run.

## Compatibility review

- Claude: the only harness affected.
  An older client (below 2.1.323) silently ignores the variable, so the `scouts` setting is harmless there.
- Every other harness and every raw launch command: untouched.
- Runtime backends: the change is inside the launch string and the spawn's stdout, which every backend carries identically; tmux, herdr, cmux, zellij, and Orca all receive the same string.
- Relaunch: `--relaunch` re-enters the same launch construction, so a relaunch of a scout re-resolves the knob and the store each time.
- The primary and secondmate agents: never enabled.
