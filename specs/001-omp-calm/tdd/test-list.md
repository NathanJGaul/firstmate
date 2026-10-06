---
feature: 001-omp-calm
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 11
planned_at: 6f0f1399
updated_at: 6f0f1399
suite_baseline: green
---

# Test List: OMP Calm presentation

## Outer loop: acceptance behaviors

Each behavior is observable through the OMP extension registration and lifecycle entry points. The portable runner exercises the extension contract without a model turn; the live OMP smoke is maintained separately because no acceptance runner is installed.

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| A1 | With no preference, `/calm` enables OMP Calm, persists `on`, and emits no transcript row | FR-001, FR-002 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_command_enables_shared_preference_without_transcript_row`) |
| A2 | An OMP session restores active Calm before its first presentation when shared `config/calm` is `on` or legacy `max` | FR-002 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_session_restores_shared_preference`) |
| A3 | A second `/calm` disables OMP Calm, persists `off`, and restores ordinary presentation | FR-001, FR-002, FR-006 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_toggle_off_restores_stock_and_clears_timer`) |
| A4 | A preference write failure leaves the current OMP state unchanged and reports the failure without changing execution | FR-004, FR-007 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_write_failure_preserves_active_state`) |
| A5 | An active OMP run advances the shared working ship at its deterministic cadence and restores the default working row on settle, abort, failure, or shutdown | FR-005 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_working_timer_is_managed_across_settle_and_shutdown`) |
| A6 | Calm hides supported legacy custom-message rows while native tools, genuine prompts, and substantive responses remain visible | FR-003, FR-004 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_supported_rows_leave_native_tools_untouched`) |
| A7 | Calm off leaves OMP working and supported transcript rendering ordinary | FR-006 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_off_keeps_ordinary_working_surface`) |
| A8 | Calm presentation does not alter native tool execution, model context, session records, or exports | FR-004 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_supported_rows_leave_native_tools_untouched`) |
| A9 | A missing OMP presentation method produces a diagnostic naming only that adapter while `/calm` and other adapters remain available | FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_adapter_failures_are_isolated_and_diagnosed`) |
| A10 | An OMP transcript class without a supported renderer remains visible and is not removed through semantic or storage mutation | FR-003, FR-004 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_adapter_failures_are_isolated_and_diagnosed`) |
| A11 | Existing Pi and Claude Code Calm policy, preference, sprite, and operational-input behavior remains green after OMP support is loaded | FR-010 | example | BLOCKED | `tests/fm-calm-claude-mod.test.sh`; Pi suite has an existing interactive export-DOM failure and missing installed Pi package evidence |

## Inner loop: unit behaviors

### `.claude/mods/firstmate-calm/lib/fm-calm-presentation.ts`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | Shared preference paths, legacy values, serialization, preservation threshold, and operational-input classification return the existing cross-harness results | FR-002, FR-008 | characterization | BASELINE | `tests/fm-calm-claude-mod.test.sh` |

### `.omp/extensions/lib/fm-calm-omp-presentation.ts`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U2 | The OMP working-row projection is deterministic at narrow and wide widths and advances the shared sprite without exceeding the requested width | FR-005 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_working_ship_projection_bounds`) |
| U3 | Adapter installation reports one targeted diagnostic for a missing or throwing seam and still returns the unrelated adapter results | FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_adapter_failures_are_isolated_and_diagnosed`) |

## Invariants and edge cases still to place

- A write failure must not publish the new active state.
- A timer must not survive `agent_end` or `session_shutdown`.
- Native tools must remain host-owned and ordinary in OMP because no supported native tool-row renderer is available.
- `on`, legacy `max`, `off`, absent, and unrecognized preference values must retain the shared interpretation.
- Unsupported operational-user and assistant-working-note rows must remain ordinary in OMP 18.6.1.

## Out of scope

- OMP support for unrelated harnesses.
- A generic OMP transcript filter or any implementation that mutates model context, input semantics, session storage, exports, or the installed OMP binary.
- A second OMP-specific preference file.

## Verification commands

- Single test: `null` - Bash tests do not expose a verified test-by-name selector.
- Full suite: `bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh`
- Coverage: `null` - `bin/fm-test-run.sh --check-coverage` failed before producing coverage evidence.
- Mutation: `null` - no mutation tool is present in the repository or lockfiles.
