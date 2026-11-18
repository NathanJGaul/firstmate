# Implementation Plan: Per-Worker Browser Session

**Branch**: `fm/firstmate-worker-browser-session` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-worker-browser-session/spec.md`

## Summary

Every local worker launch exports `CHROME_DEVTOOLS_AXI_SESSION=<task id>`, and task cleanup stops that session after the leaked-process cleanup.
One helper owns the rule that decides whether a task id names a session, and both scripts call it.
The launch export rides the same channel as the existing `FM_TASK_INBOX` export, which is already proven to survive the launch-environment allowlist and to override a pane value.
The stop is best effort, bounded by the repository's one timeout runner, and never runs for the default session.

## Technical Context

**Language/Version**: Bash, targeting stock macOS `/bin/bash` 3.2 and current Linux Bash, matching the existing `bin/` scripts.

**Primary Dependencies**: `bin/fm-pr-lib.sh` (task-id rules, sourced by both scripts), `bin/fm-timeout-lib.sh` (`fm_run_timed`, already sourced by teardown), and the installed `chrome-devtools-axi` CLI (optional at teardown).

**Storage**: None.
The session name is derived from the task id, so no new metadata field exists.

**Testing**: Executable Bash tests under `tests/`, run with `bin/fm-test-run.sh`; fake binaries via `tests/lib.sh` and `tests/fixtures.sh`.

**Target Platform**: Linux and macOS developer machines running Firstmate.

**Project Type**: Shell CLI toolkit.

**Performance Goals**: The teardown stop adds at most one bounded external call.

**Constraints**: The stop must never block or fail cleanup; `bin/*.sh` must be shellcheck-clean; no new `bin/` library (many tests copy fixed library lists into sandbox homes); no change to the launch-environment allowlist file format.

**Scale/Scope**: Two scripts, one library function, two existing tests extended, one documentation line plus the spawn header.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution at `.specify/memory/constitution.md` is still the unratified Spec-Kit template, so it carries no gates.
The TDD principle in `.agents/skills/spec-kit-workflow/SKILL.md` is the operative rule set, and this plan follows it: every behavior gets a failing test first, test tasks precede implementation tasks, tests are never weakened, and every acceptance criterion has a real-entry-point test.
Changing the constitution needs the captain's approval of its exact wording, so this feature leaves it untouched and records the limitation.
The repository's own contributor rules (`firstmate-coding-guidelines`) are the second gate set: one owner per contract, mechanics in script headers, one sentence per line in Markdown, shellcheck-clean scripts, and behavior tests through public interfaces.
No gate is violated, and Complexity Tracking is empty.

**Post-design re-check**: Passed.
The design adds one library function, one export line, and one best-effort call, and states each contract once.

## Project Structure

### Documentation (this feature)

```text
specs/004-worker-browser-session/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── launch-and-cleanup.md
├── checklists/requirements.md
├── tasks.md
└── tdd/
```

### Source Code (repository root)

```text
bin/
├── fm-pr-lib.sh        # fm_browser_session_name: the one owner of the "does this id name a session" rule
├── fm-spawn.sh         # export in the launch text; header "Launch environment" paragraph updated
└── fm-teardown.sh      # bounded best-effort stop after the leaked-process cleanup; header updated
docs/
└── configuration.md    # worker launch environment contract line
tests/
├── fm-spawn-compact-adviser-disable.test.sh   # launch-export cases (file already owns the FM_TASK_INBOX export case and the env-probe machinery)
└── fm-teardown.test.sh                        # cleanup cases with a fake chrome-devtools-axi
```

**Structure Decision**: Extend the two existing test files instead of adding a new one.
The spawn file already holds the env-probe machinery and the sibling `FM_TASK_INBOX` case, and a new test file would need family and weight registration in `bin/fm-test-run.sh` for no gain.
The teardown file already holds the leaked-process and ordering cases that the stop must follow.

## Design

1. `fm_browser_session_name <id>` in `bin/fm-pr-lib.sh`, beside `fm_task_id_creation_valid`: prints the id and returns 0 when the id is creation-valid and not `default`; prints nothing and returns 1 otherwise.
2. `bin/fm-spawn.sh`: when the helper accepts `$ID`, prefix the launch text with `export CHROME_DEVTOOLS_AXI_SESSION=<id>;` next to the `FM_TASK_INBOX` export.
   The inner export survives the `env -i` wrapper and overrides a pane value, so the floor name list is unchanged.
   The header's launch-environment paragraph names the variable beside the `FM_TASK_INBOX` sentence.
3. `bin/fm-teardown.sh`: after the leaked-process cleanup and pipeline-spend block, call a `teardown_stop_browser_session` function that exits quietly when the helper refuses the id or `chrome-devtools-axi` is absent, and otherwise runs `CHROME_DEVTOOLS_AXI_SESSION=<id> fm_run_timed <bound> chrome-devtools-axi stop`, warning on a non-zero status.
   The header gains a short "Fix 4" paragraph.
4. `docs/configuration.md`: one sentence in the worker launch environment section.

## Complexity Tracking

No constitution violations to justify.
