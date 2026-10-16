# Implementation Plan: Restore Main CI

**Branch**: `fm/firstmate-ci-green` | **Date**: 2026-10-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-restore-main-ci/spec.md`

## Summary

Four independent defects keep four CI jobs red, and a fifth, found while verifying, makes a fifth check intermittent.
One is a runtime defect in two shipped Pi extensions (they read a prompt that custom-message runs do not carry).
Two are test fixtures left inconsistent by a conflicted merge and by a later module split.
One is a test that signals a process at a moment where bash 5.2 can lose the signal handler.
The plan fixes each at its cause with the smallest change that matches how the same file or upstream already does it, and adds regression coverage where behavior was previously unpinned.

## Technical Context

**Language/Version**: Bash scripts and TypeScript Pi extensions run by Node; bash 5.3 locally and 5.2.21 on the CI runner.

**Primary Dependencies**: `@earendil-works/pi-coding-agent` (installed unpinned in CI, newest 1.3.0), `tsc`, `jq`, `tmux`.

**Storage**: Files only; no schema change.

**Testing**: Executable Bash tests in `tests/*.test.sh` run through `bin/fm-test-run.sh`; lint through `bin/fm-lint.sh`.

**Target Platform**: Linux CI runners, macOS stock-bash job, operator machines running Pi.

**Project Type**: CLI scripts plus agent-host extensions.

**Performance Goals**: None; no time budget changes (FR-010).

**Constraints**: One sentence per line in tracked Markdown, plain dash, shellcheck-clean scripts, no agent co-author, no `commands.test` suite walks in no-mistakes config.

**Scale/Scope**: Two production extension files, four test files, one shared test helper file, and the Spec-Kit artifacts.

## Constitution Check

The project constitution is still the unfilled template, so there are no ratified gates to evaluate.
The Spec-Kit workflow's TDD principle applies by instruction: every behavior change is driven by a test that failed first and is recorded; tests are never weakened, skipped, or deleted; refactoring happens only on green; test strength is shown by deliberate mutants because no mutation tool is installed.
Result: pass, with the TDD rules adopted as the working gate.

## Project Structure

### Documentation (this feature)

```text
specs/002-restore-main-ci/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/test-contracts.md
├── tasks.md
└── tdd/
```

### Source Code (repository root)

```text
.pi/extensions/fm-branch-supervision.ts      # R1 production narrowing
.pi/extensions/fm-primary-pi-watch.ts        # R1 production narrowing
.opencode/plugins/fm-primary-turnend-guard.js # R5 stdin error listener
tests/fm-pi-branch-extension.test.sh         # R1 event typing and custom-run regression
tests/fm-pi-branch-live-e2e.test.sh          # R1 event typing
tests/fm-pi-watch-extension.test.sh          # R1 event typing and custom-run regression; R5 broken-pipe regression
tests/fm-contributions.test.sh               # R2 fake forge block restored
tests/fm-calm-pi-extension.test.sh           # R3 policy module copies
tests/fm-calm-pi-queue-retention-live-e2e.test.sh  # R3 policy module copy
tests/wake-helpers.sh                        # R4 parked-drain wait helper
tests/fm-wake-queue.test.sh                  # R4 interruption case and helper case
```

**Structure Decision**: No new files outside `specs/`; each fix lands in the file that owns the behavior, mirroring the surrounding convention.

## Design

**R1**: In `fm-branch-supervision.ts` replace the unconditional `event.prompt` read with the upstream shape: compute `processingOpenedThisRun` from a custom event whose message is the queued processing request, then return unless `event.messageType === "user"`, then read `event.prompt`.
In `fm-primary-pi-watch.ts` return unless `event.messageType === "user"` before consuming a wake.
Tests: type user-prompt events with `messageType: "user"`, fire the processing request as `{ messageType: "custom", message }`, and add the custom-run regression for the mirror and for the watch extension.

**R5**: In `.opencode/plugins/fm-primary-turnend-guard.js` add a no-op `error` listener on the child's stdin before the payload write, and add a case in `tests/fm-pi-watch-extension.test.sh` that stalls the host between spawning the guard and writing its payload.

**R2**: Replace the `gh` wrapper block in `wrap_forge` with the 388d56c6 version (clock_bump with rename publish, single-caller `reserve`, `slow-wave` cases, `exhaust`, `fail-late`).

**R3**: Add `cp "$SHARED_VISIBILITY" .../fm-calm-visibility-policy.ts` after each of the two unpaired copies in the Calm extension test, and the equivalent copy of `$ROOT/.claude/mods/firstmate-calm/lib/fm-calm-visibility.ts` in the live guard.

**R4**: Add `wait_for_sleep_child <pid> [tries]` to `tests/wake-helpers.sh` (poll `ps -A -o ppid= -o comm=` for a child of `<pid>` whose basename is `sleep`), use it in the interruption case in place of the unaided lock-and-marker predicate while keeping that predicate, and keep the failure message naming the read boundary.
Cover the helper with a deterministic case in `tests/fm-wake-queue.test.sh`.

## Phase 0 and Phase 1 Outputs

research.md (decisions and evidence), data-model.md, contracts/test-contracts.md, quickstart.md.
