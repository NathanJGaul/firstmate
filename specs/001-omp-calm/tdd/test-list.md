---
feature: 001-omp-calm
loop: outside-in
profile: unavailable
spec_criteria: 14
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
| A3 | A second `/calm` disables OMP Calm, persists `off`, restores ordinary working presentation, and affects newly rendered synthetic rows | FR-001, FR-002, FR-006 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_toggle_off_restores_stock_and_clears_timer`, `test_omp_supported_rows_leave_native_tools_untouched`) |
| A4 | A preference write failure leaves the current OMP state unchanged and reports the failure without changing execution | FR-004, FR-007 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_write_failure_preserves_active_state`) |
| A5 | An active OMP run advances the shared working ship at its deterministic cadence and restores the default working row on settle, abort, failure, or shutdown | FR-005 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_working_timer_is_managed_across_settle_and_shutdown`) |
| A6 | Calm hides supported legacy custom-message rows, invalidates mounted rows on toggle, while native tools, genuine prompts, substantive responses, and unsupported transitions remain host-owned | FR-003, FR-004 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_supported_rows_leave_native_tools_untouched`) |
| A7 | Calm off leaves OMP working and supported transcript rendering ordinary | FR-006 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_off_keeps_ordinary_working_surface`) |
| A8 | Calm presentation does not alter native tool execution, model context, session records, or exports | FR-004 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_supported_rows_leave_native_tools_untouched`) |
| A9 | A missing OMP presentation method produces a diagnostic naming only that adapter while `/calm` and other adapters remain available | FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_adapter_failures_are_isolated_and_diagnosed`) |
| A10 | An OMP transcript class without a supported renderer remains visible and is not removed through semantic or storage mutation | FR-003, FR-004 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_adapter_failures_are_isolated_and_diagnosed`) |
| A11 | Existing Pi and Claude Code Calm policy, preference, sprite, and operational-input behavior remains green after OMP support is loaded | FR-010 | example | BLOCKED | `tests/fm-calm-claude-mod.test.sh`; Pi suite has an existing interactive export-DOM failure and missing installed Pi package evidence |
| A12 | A failed working-message frame update remains retryable and emits at most one diagnostic for the failing seam | FR-005, FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_frame_update_failure_is_retryable`) |
| A13 | A new logical run is active immediately and resumes presentation after retained timer cleanup succeeds | FR-005 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_pending_agent_start_retries_after_timer_clear_failure`) |
| A14 | A non-positive usable working width leaves OMP's stock working surface untouched and reports the width seam | FR-005, FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_unusable_width_leaves_stock_working_surface`) |
| A15 | A deferred logical run survives continuing events and presentation-only Calm toggles and resumes in the same session after cleanup | FR-005, FR-006 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_pending_agent_start_survives_presentation_toggle`) |
| A16 | A non-missing preference read failure preserves the last known Calm state and emits one bounded diagnostic | FR-002, FR-007 | contract | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_calm_preference_read_failure_preserves_state`) |
| A17 | A temporary timer seam failure is retried when a later agent context provides the managed timer API | FR-005, FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_timer_adapter_retries_after_temporary_unavailability`) |

## Inner loop: unit behaviors

### `.claude/mods/firstmate-calm/lib/fm-calm-presentation.ts`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | Shared preference paths, legacy values, and serialization retain the existing cross-harness results; Pi and Claude retain their own preservation and operational-input policy baseline | FR-002, FR-008, FR-010 | characterization | BASELINE | `tests/fm-calm-claude-mod.test.sh` |

### `.omp/extensions/lib/fm-calm-omp-presentation.ts`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U2 | The OMP working-row projection is deterministic at narrow and wide widths and advances the shared sprite without exceeding the requested width | FR-005 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_working_ship_projection_bounds`) |
| U3 | Adapter installation reports one targeted diagnostic for a missing or throwing seam and still returns the unrelated adapter results | FR-007 | example | DONE | `tests/fm-calm-omp-extension.test.sh` (`test_omp_adapter_failures_are_isolated_and_diagnosed`) |

## Invariants and edge cases still to place

- A write failure must not publish the new active state.
- A timer must not survive terminal `agent_end` or `session_shutdown`, and a failed clear must retain its handle for retry.
- A `willContinue: true` `agent_end` must not stop the logical run.
- Calm must not call stock working-message restoration unless it owns the working surface.
- Native tools must remain host-owned and ordinary in OMP because no supported native tool-row renderer is available.
- A mounted synthetic custom entry is invalidated on toggle through the component seam; unsupported transcript rows remain host-owned.
- A new logical run must survive deferred presentation cleanup, continuing events, and presentation-only toggles within its session, then resume after cleanup or re-enabling Calm.
- `on`, legacy `max`, `off`, absent, and unrecognized preference values must retain the shared interpretation.
- Unsupported operational-user and assistant-working-note rows must remain ordinary in OMP 18.6.1.

## Out of scope

- OMP support for unrelated harnesses.
- A generic OMP transcript filter or any implementation that mutates model context, input semantics, session storage, exports, or the installed OMP binary.
- A second OMP-specific preference file.

## Verification commands

- Single test: `null` - Bash tests do not expose a verified test-by-name selector.
- Baseline focused suite: `bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh`
- Coverage: `null` - `bin/fm-test-run.sh --check-coverage` failed before producing coverage evidence.
- Mutation: `null` - no mutation tool is present in the repository or lockfiles.
