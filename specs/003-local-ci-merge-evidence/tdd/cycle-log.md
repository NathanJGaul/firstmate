# TDD Cycle Log: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Test list**: [test-list.md](test-list.md) | **Date**: 2026-10-26

Baseline: the branch point's `tests/fm-pr-merge.test.sh` passes (103 cases plus the suite-level assertions recorded in `verification.md`).
Every behavior below was driven red first against the real script and the real fixtures, with no production change in the tree, and the red output is quoted as recorded.

## Cycle A1 - the flag merges on a matching head with every job passing

- Behavior: A1 in `test-list.md`.
- RED: `not ok - local-ci-result-required-merged: a matching head with every job passing must merge` and `error: refusing to merge ... required check 'End-to-end tests' has not reported at head 1b1b1b1b...`.
  The flag did not exist, so the two required checks stayed unreported and the merge refused.
- GREEN: `ok - fm-pr-merge merges on a local CI result file that proves the live head and waives only the checks it records`, including `waived 2 check names the forge did not prove` and the attended authority record.
- Refactor: the evidence set is stored newline-delimited behind a sentinel so one check name can never match as a prefix of another, which is what the deliberate `name-matching` mutant below proves.

## Cycle A2 - a red check of the same name is waived

- Behavior: A2.
- RED: `not ok - local-ci-result-red-merged: a red check proven locally must merge`.
  Without the flag the case still refuses on `check 'lint' is not green`, which stayed the control assertion.
- GREEN: `ok - fm-pr-merge waives a red check whose exact name the local CI result file records as passing`.
- Refactor: both the red-check loop and the required-missing loop call one `local_ci_evidence_covers` helper, so a later change to name matching cannot fix one path and miss the other.

## Cycle A3 - nothing is written to the forge

- Behavior: A3, U4-adjacent (no status writing).
- RED: `not ok - local-ci-result-no-forge-writes: the evidence merge should land`.
- GREEN: `ok - fm-pr-merge writes nothing to the forge besides the merge itself on the local evidence path`, asserting exactly one `pr merge` line and no `statuses`, `--method `, or `pr comment` call in the recorded forge log.

## Cycle A4 - a head mismatch refuses

- Behavior: A4.
- RED: `not ok - local-ci-result-head-mismatch: both commits were not named`.
- GREEN: `ok - fm-pr-merge refuses a local CI result file that proves a different commit`, naming both commits and leaving the forge merge uncalled.

## Cycle A5 - a recorded failed job refuses

- Behavior: A5.
- RED: `not ok - local-ci-result-failed-job: a recorded failure must refuse: expected exit 1, got 0`.
- GREEN: `ok - fm-pr-merge refuses a local CI result file that records any failed job`, with the forge log empty and `pr=` unrecorded, which pins that the refusal happens before any forge read.

## Cycle A6 - an uncovered check keeps its refusal and is named

- Behavior: A6, U4 (prefix collision).
- RED: `not ok - local-ci-result-uncovered: the uncovered checks were not named`.
- GREEN: `ok - fm-pr-merge refuses when the local CI result file does not cover a check the forge still needs`.
  The case records a passing `End-to-end tests (1/4)` job and requires the aggregate `End-to-end tests`, so whole-name matching is pinned by a real shard-versus-aggregate collision.

## Cycle A7 - an unusable file refuses before anything is recorded

- Behavior: A7.
- RED: `not ok - local-ci-result-unusable-missing: an unusable file must refuse as a usage error: expected exit 2, got 0`.
- GREEN: `ok - fm-pr-merge refuses an unreadable, absent, or malformed local CI result file before recording anything`, covering absent, directory, mode-000, and non-JSON files.

## Cycle A8 - a wrongly shaped file refuses

- Behavior: A8.
- RED: `not ok - local-ci-result-shape-version: a wrongly shaped file must refuse: expected exit 2, got 0`.
- GREEN: `ok - fm-pr-merge refuses a local CI result file with an unknown version, an abbreviated head, no jobs, or an unlineable name`.
  The abbreviated-head case is the one that stops a 12-character summary head from ever standing in for a commit.

## Cycle A9 - attended only

- Behavior: A9.
- RED: `not ok - local-ci-result-away: the evidence flag must be refused while away: expected exit 2, got 1`.
- GREEN: `ok - fm-pr-merge refuses --local-ci-result while the away record exists and honours it after the captain returns`, which also proves the archived record restores the merge.

## Cycle A10 - GitHub only

- Behavior: A10.
- RED: `not ok - gitlab-local-ci-result: the evidence flag must not apply on GitLab: expected exit 2, got 0`.
- GREEN: `ok - fm-pr-merge refuses --local-ci-result on a forge whose merge already requires its head pipeline`, with the `glab` log left empty.

## Cycle A11 - argument shape

- Behavior: A11.
- RED: `not ok - local-ci-result-args: the flag without a path must be refused: expected exit 2, got 0`.
- GREEN: `ok - fm-pr-merge accepts --local-ci-result once with a separate path and refuses every other spelling`, covering the missing value, the inline value, and a repeated flag.

## Cycle A12 - the runner emits the evidence

- Behavior: A12, U1, U2, U3.
- RED: the runner had no result file at all, so the fixture harness found `local-ci-result.json` absent.
- GREEN: the extracted summary block, run over a full, a subset, and a failing fixture job set, emitted:

```json
{"version":1,"head_sha":"0123456789abcdef0123456789abcdef01234567","n":9,"jobs":[{"name":"Format, lint, types, and build","exit_code":0},{"name":"Unit and component tests (1/2)","exit_code":0},{"name":"Unit and component tests (2/2)","exit_code":0},{"name":"End-to-end tests (1/4)","exit_code":0},{"name":"End-to-end tests (2/4)","exit_code":0},{"name":"End-to-end tests (3/4)","exit_code":0},{"name":"End-to-end tests (4/4)","exit_code":0},{"name":"Unit and component tests","exit_code":0},{"name":"End-to-end tests","exit_code":0}]}
{"version":1,"head_sha":"0123456789abcdef0123456789abcdef01234567","n":2,"jobs":[{"name":"Format, lint, types, and build","exit_code":0},{"name":"End-to-end tests (3/4)","exit_code":0}]}
{"version":1,"head_sha":"0123456789abcdef0123456789abcdef01234567","n":4,"jobs":[{"name":"Format, lint, types, and build","exit_code":0},{"name":"Unit and component tests (1/2)","exit_code":1},{"name":"Unit and component tests (2/2)","exit_code":0},{"name":"Unit and component tests","exit_code":1}]}
```

  The printed summary and the `== ALL PASSED`/`== FAILED` line and the exit status are byte-identical to before the change for the same fixtures.
- End-to-end loop: the emitted full-run file was then handed to the real `bin/fm-pr-merge.sh` against a fixture pull request whose required checks never reported.
  Without the flag it refused with zero forge merge calls; with the flag it printed `verified: ... waived 2 check names the forge did not prove` and logged exactly one head-bound merge.

## Deliberate mutants

Each mutant was applied to `bin/fm-pr-merge.sh`, one at a time, then the corresponding case was run and the file restored.

| Mutant | Change | Result |
| --- | --- | --- |
| `head-equality` | the file's head is treated as matching unconditionally | killed by A4 (`expected exit 1, got 0`) |
| `failed-job` | the failed-job refusal is disabled | killed by A5 (`expected exit 1, got 0`) |
| `name-matching` | coverage falls back to substring matching | killed by A6 (`the unreported check kept its own refusal` failed: the aggregate was waived by a shard name) |
| `away-refusal` | the away refusal is deleted | killed by A9 (`expected exit 2, got 0`) |
| `version-check` | the schema version check is deleted | killed by A8 (`expected exit 2, got 0`) |

## Notes

- Two assertions in A1 were corrected during the loop, not weakened: the merge-authority record assertion now greps the recorded `attended` line instead of assuming a line number in that record.
- `assert_grep` was used with a pattern that does not begin with `--`; the first attempt passed `--` as a separator and the helper read it as a file name.
