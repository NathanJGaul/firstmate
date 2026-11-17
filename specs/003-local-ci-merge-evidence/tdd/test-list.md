---
feature: 003-local-ci-merge-evidence
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 15
planned_at: 00000000
updated_at: 00000000
suite_baseline: green
---

# TDD Test List: Local CI Merge Evidence

Baseline: `tests/fm-pr-merge.test.sh` passes on the branch point before this feature's changes.
The whole file is the acceptance runner for this feature because every behavior here is a merge outcome, and the file's fixtures (`make_case`, `add_gh_mocks`, `write_github_live_json`, `run_pr_merge`) already drive the real script with no network.
Traces use `US<story>.<scenario>` for acceptance scenarios and `FR-nnn` for functional requirements in `spec.md`.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | runner | state | test |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | A matching head with every job passing and a required check that never reported merges once and records the landed merge | US1.1, FR-003, FR-005, FR-008, FR-011 | acceptance | `bin/fm-test-run.sh tests/fm-pr-merge.test.sh` | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_waives_unreported_required_checks` |
| A2 | A red hosted check whose exact name is a passing job in the file is waived and the merge proceeds | US1.2, FR-008 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_waives_a_red_check_of_the_same_name` |
| A3 | No forge write other than the merge command happens on the evidence path | US1.3, FR-010 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_writes_nothing_to_the_forge` |
| A4 | A head mismatch refuses and names both commits | US2.1, FR-005, FR-006 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_head_mismatch_refuses` |
| A5 | A recorded failed job refuses and names the job | US2.2, FR-007 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_failed_job_refuses` |
| A6 | A check outside the file's coverage refuses and says the file does not cover it | US2.3, FR-008 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_uncovered_check_refuses` |
| A7 | An unusable file refuses before any metadata or forge read | US2.4, FR-012 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_unusable_file_refuses` |
| A8 | Valid JSON of the wrong shape refuses like an unusable file | US2.4, FR-012 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_invalid_shape_refuses` |
| A9 | The flag is refused while the away record exists and honoured once archived | US3.1, US3.2, FR-009 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_is_attended_only` |
| A10 | The flag is refused for a forge whose merge already requires its head pipeline | US3.3, FR-009 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_refuses_on_gitlab` |
| A11 | The flag is accepted once per call and its inline-value spelling is refused | FR-004 | acceptance | same | PENDING | `tests/fm-pr-merge.test.sh::test_local_ci_result_argument_shape` |
| A12 | The runner emits a result file naming its full head and every printed job and aggregate line, and a subset run records only what ran | US4.1, US4.2, US4.3, FR-001, FR-002, FR-003 | acceptance | `bin/fm-test-run.sh tests/fm-local-ci-result-file.test.sh` | PENDING | `tests/fm-local-ci-result-file.test.sh` |

## Inner loop: unit behaviors

| id | behavior | traces | runner | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | The emitter writes one job entry per job, with its exit code and the aggregate lines appended in summary order | FR-001 | `bin/fm-test-run.sh tests/fm-local-ci-result-file.test.sh` | PENDING | same file |
| U2 | A failing job's nonzero exit is recorded and the runner still exits nonzero | FR-001, FR-002 | same | PENDING | same file |
| U3 | The recorded head is the full 40-character commit, never an abbreviation | FR-003 | same | PENDING | same file |
| U4 | A job name carrying a tab or newline is refused by the consumer instead of forging an evidence line | FR-012 | `bin/fm-test-run.sh tests/fm-pr-merge.test.sh` | PENDING | `test_local_ci_result_invalid_shape_refuses` |

## Notes

- A12, U1, U2, and U3 are proven against a fixture harness that reproduces the runner's own summary loop, because the runner is private home state outside this repository and a real project build cannot run in this test environment.
  `tdd/verification.md` records this as an accepted limitation.
- Mutation evidence for the merge-side behaviors is recorded in `tdd/cycle-log.md` and `tdd/verification.md`.
