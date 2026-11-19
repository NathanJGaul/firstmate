# TDD Verification: Orca Prompt-Blocked Receipts

Verdict: PASS, with the limitation named below.

## Test-first evidence

`tdd/cycle-log.md` records the red output against the unchanged code for every behavior test except the hook-less characterization, which is green before the change by design and is covered by mutant M7.

## Mutation evidence

No mutation tool is installed, so deliberate mutants were applied to a scratch copy and the named tests re-run.

| mutant | killed by |
| --- | --- |
| M1 `agent_prompt_blocked` joins the gone set | `test_receipt_class_matrix` |
| M2 the blocked class is dropped (reads failed) | `test_receipt_class_matrix` |
| M3 `prompt-blocked` exits 0 | `test_receipt_blocked_prompt_is_prompt_blocked` |
| M4 the blocked case is disabled | `test_receipt_blocked_prompt_is_prompt_blocked` |
| M5 the ring maps `prompt-blocked` to 3 | `test_ring_reports_a_blocked_orca_prompt_as_a_failed_ring` |
| M6 the ring drops its stderr line | `test_ring_reports_a_blocked_orca_prompt_as_a_failed_ring` |
| M7 a hook-less accepted receipt is read as unsupported | `test_receipt_class_matrix`; it first survived a fixture with the warning in the wrong place, which was corrected |

## Acceptance coverage

US1 to US3 map to the tests in `tdd/test-list.md`; the live proof is step A12 of `tests/fm-backend-orca-smoke.test.sh`.

## Limitation

The dialog is a fake that prints the Claude trust-dialog text; a real Claude harness's dialog is unobserved.
