# Cycle Log: Orca Escape and Ctrl+U Delivery

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> `failed=0` (215 s), run from an archive of `46987259` with the task variable unset
- `bin/fm-test-run.sh tests/fm-control.test.sh` -> `failed=0` (155 s), same archive
- `bin/fm-test-run.sh --check-coverage` -> exit 1 on `main` under a UTF-8 locale (`comm: file 2 is not in sorted order`), exit 0 under `LC_ALL=C`. Not caused by this feature; fixed first as its own commit (`2617a580`, `bin/fm-test-run.sh` compares its C-sorted lists with `LC_ALL=C comm`), after which the check passes and `tests/fm-test-run.test.sh` is green.
- full profile suite: not run here, left to CI
- commit: `46987259`

Method notes:

- The suites have no per-test selector, so each red below was observed by running only the named functions, each in its own process, through a scratch wrapper that sources the same file with its call list replaced; nothing in the wrapper is committed.
- The tests and the specification are one commit (`59028a30`) and the implementation is the next (`feat(bin): deliver Escape and Ctrl+U ...`), so the history itself shows tests first. Slices 8 and 9 share both files, so the two cycles below are one pair of commits.

## Cycle 1: US3 and US2 adapter - the status facts, the floor, and the gate (U2-U12)

- tests (new, `tests/fm-backend-orca.test.sh`; the fake `orca` gained a pinned status file): `test_send_key_escape_sends_a_raw_escape_byte` (U2), `test_send_key_ctrl_u_sends_a_raw_nak_byte` (U3), `test_send_key_escape_and_ctrl_u_accept_their_spellings` (U4), `test_send_key_refuses_escape_and_ctrl_u_without_the_capability` (U5), `test_send_key_refuses_escape_when_the_status_is_unreadable` (U6), `test_send_key_enter_and_ctrl_c_ignore_the_capability_gate` (U7), `test_runtime_check_records_the_version_and_capabilities` (U8), `test_runtime_check_refuses_a_version_below_the_floor` (U9), `test_runtime_check_accepts_the_floor_and_anything_above_it` (U10), `test_runtime_check_does_not_refuse_a_missing_or_unreadable_version` (U11). The case `test_send_key_refuses_escape_until_supported`, which asserted Escape was unsupported, was replaced by U2 through U6.
- red against the unchanged adapter:
  - U2 `not ok - send_key Escape should succeed: error: unsupported Orca key 'Escape': expected exit 0, got 1`
  - U3 `not ok - send_key C-u should succeed: error: unsupported Orca key 'C-u': expected exit 0, got 1`
  - U4 `not ok - send_key should accept the spelling 'Escape'`
  - U5 `not ok - the Escape refusal should name the missing capability (missing: 'terminal.ordered-input.v1')`
  - U8 `not ok - runtime_check should record the version and the space-separated capabilities, got '|'`
  - U9 `not ok - runtime_check should refuse Orca 1.4.260, below the tested floor`
  - U11 `not ok - runtime_check should record version 'not-a-version' and no capabilities, got '[][]'`
  - U6, U7, and U10 were green before the change: they are guards. U6 (an unreadable status refuses Escape) held only because Escape was unsupported, so its strength is shown by mutant M9 below; U7 pins that Enter and Ctrl+C never read the status; U10 pins that versions at or above the floor, including a suffixed one, are accepted, which the unchanged check already did because it had no floor.
- green: `fm_backend_orca_status_read` parses the status once and records the version, the capability list, and the below-floor flag; `fm_backend_orca_runtime_check` is that read plus the floor refusal; `fm_backend_orca_control_bytes_ready` gates the two keys; `fm_backend_orca_send_key` sends them as `terminal send --text` with no `--enter`. All ten tests pass, and the full `tests/fm-backend-orca.test.sh` passes (243 s).
- refactor: the readiness test that was inline in the runtime check moved unchanged into the shared reader.

## Cycle 2: US1 and US4 control plane - interrupt and send-key on Orca (A1-A6, U1)

- tests (new, `tests/fm-control.test.sh`, with a fake `orca` that logs every call): `test_orca_delivers_an_escape_harness_interrupt` (A1), `test_orca_interrupt_follows_a_composer_restoring_harness_with_ctrl_u` (A2), `test_orca_interrupt_for_a_ctrl_c_harness_is_unchanged` (A3), `test_fm_send_delivers_escape_to_an_orca_task` (A4), `test_orca_refuses_an_escape_interrupt_without_the_capability` (A5), `test_orca_refuses_exit_and_relaunch` (A6), and the inverted `test_backend_key_capability_matrix` (U1). The case `test_orca_refuses_an_escape_harness_interrupt` was replaced by A1 and A5.
- red against the unchanged table:
  - U1 `not ok - orca should be able to deliver Escape`
  - A1 `not ok - an Escape harness on orca should be interrupted: error: harness claude interrupts with Escape, which the orca backend cannot deliver; refusing to send a different key`
  - A2 the same refusal for muse
  - A5 `not ok - the refusal should name the missing capability (missing: 'terminal.ordered-input.v1')`
  - A4 `error: unsupported Orca key 'Escape'` then `key 'Escape' not sent to term-t1`
  - A3 and A6 were green before the change: they are guards pinning that a Ctrl+C harness keeps using `--interrupt` and that `exit` and `relaunch` stay refused when Escape starts delivering.
- green: `fm_control_backend_supports_key` lists Escape and C-u for Orca, so the control plane reaches the adapter, whose gate decides. All seven tests pass, and the full `tests/fm-control.test.sh` passes (186 s).
- refactor: none.
- docs: the key-support comments in `bin/fm-control.sh`, `bin/fm-control-lib.sh`, and `bin/fm-send.sh`; `docs/orca-backend.md`; `docs/agent-control.md` text and matrix; the recovery wording in `.agents/skills/stuck-crewmate-recovery/SKILL.md`.

## Cycle 3: US1 live proof (A7)

- change: the lab prints the whole capability list, sends Escape and Ctrl+U through the adapter and `fm-send`, runs `fm-control interrupt` and the two stop verbs against the lab task, and replaces the observed `fm-send --key Escape` refusal with assertions.
- first run: `fm-send --key Escape` was accepted but no `^[` echo was read back, because the next key, Ctrl+U, erases the line discipline's echo. The assertion was moved to read before Ctrl+U; no product code changed.
- result: `tests/fm-backend-orca-smoke.test.sh` passed with the lab's own runtime at appVersion 1.4.261 (`passed=43 findings=6` on the final full run at the committed code), and left no lab process, directory, worktree, or branch.
