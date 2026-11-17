# TDD Verification: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Profile**: `.specify/memory/tdd-profile.md` | **Date**: 2026-10-26

Audited from the branch's own artifacts and re-run commands, not from conversation memory.

## Test-first evidence

| Requirement | Failing test written first | Red evidence | Green evidence |
| --- | --- | --- | --- |
| A1 matching head merges | `test_local_ci_result_waives_unreported_required_checks` | `expected` merge, got a refusal naming both unreported required checks | recorded in `cycle-log.md`, green in the full run |
| A2 red check waived | `test_local_ci_result_waives_a_red_check_of_the_same_name` | `a red check proven locally must merge` | green |
| A3 no forge writes | `test_local_ci_result_writes_nothing_to_the_forge` | `the evidence merge should land` | green |
| A4 head mismatch | `test_local_ci_result_head_mismatch_refuses` | `both commits were not named` | green |
| A5 failed job | `test_local_ci_result_failed_job_refuses` | `expected exit 1, got 0` | green |
| A6 uncovered check | `test_local_ci_result_uncovered_check_refuses` | `the uncovered checks were not named` | green |
| A7 unusable file | `test_local_ci_result_unusable_file_refuses` | `expected exit 2, got 0` | green |
| A8 wrong shape | `test_local_ci_result_invalid_shape_refuses` | `expected exit 2, got 0` | green |
| A9 attended only | `test_local_ci_result_is_attended_only` | `expected exit 2, got 1` | green |
| A10 GitHub only | `test_local_ci_result_refuses_on_gitlab` | `expected exit 2, got 0` | green |
| A11 argument shape | `test_local_ci_result_argument_shape` | `the flag without a path must be refused`, `expected exit 2, got 0` | green |
| A12 runner emission | private fixture harness over the shipped summary block | no result file existed | green, see below |

## Full-suite runs

Baseline, the branch point's own test file (`git show HEAD:tests/fm-pr-merge.test.sh`), run before any production change:

```text
bash tests/.tmp-baseline.sh            # byte-identical copy of the branch-point file
ok - ... (107 assertions), not ok: 0, exit 0
```

Feature run, through the repository's own runner:

```text
bin/fm-test-run.sh tests/fm-pr-merge.test.sh
FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0 duration_ms=514349
ok - ... (118 assertions), not ok: 0, exit 0
```

The eleven added cases are the acceptance and refusal paths listed above; every pre-existing case still passes.

## Runner emission and hand-off

The runner is private home state at `data/pricing-sheet-local-ci/local-ci.sh`.
Its summary-and-result block was extracted verbatim and run over three fixture job sets (full, subset, one failing shard) with the real code:

- full: 9 job records (7 jobs plus both aggregates), head `0123456789abcdef0123456789abcdef01234567`, all exit 0;
- subset: 2 records, only the selected job and no aggregate;
- failing: 4 records, the failing shard and its aggregate both recorded as exit 1, and the runner still printed `== FAILED` and exited nonzero.

The emitted full-run file was then handed to the real `bin/fm-pr-merge.sh` against a fixture pull request whose two required checks never reported:

```text
without the flag: exit 1, forge merge calls 0
with the flag:    exit 0, verified ... waived 2 check names the forge did not prove
                  pr merge 120 --repo example/repo --match-head-commit 0123456789abcdef0123456789abcdef01234567 --squash
```

## Lint

```text
bin/fm-lint.sh bin/fm-pr-merge.sh tests/fm-pr-merge.test.sh
fm-lint.sh: ShellCheck 0.11.0 (pinned 0.11.0)
fm-lint.sh: full ShellCheck extended analysis enabled        # no findings
```

The private runner's new block adds no ShellCheck finding.
Its five pre-existing findings (SC2155 at the `mise` PATH export, SC2329 on two functions, SC1007 on `CI=` in the prestart path, SC2086 on `return $rc`) are unchanged and outside this feature's scope.

## Documentation gates

```text
bin/fm-doc-audience-check.sh
fm-doc-audience-check: ok surfaces=189 local_links=747
```

## Test-smell review

| Smell | Assessment |
| --- | --- |
| Assertion on implementation source bytes | none; every case runs the real script and reads its exit status, stderr, recorded state, or the recorded forge log |
| Over-mocking | the forge CLI is faked, which is the existing fixture pattern in this file; no firstmate code is stubbed |
| Sleep or timing dependence | none added; the cases assert recorded state, not elapsed time |
| Order dependence | each case builds a fresh sandbox and a fresh fake bin directory |
| Weak assertions | each refusal case asserts both the exit status and one specific message, and the acceptance cases assert the exact head-bound merge line and the absence of forge writes |
| Silent skips | none; the private-runner checks are fixture harnesses, not skips, and their commands are recorded above |

## Deliberate mutants (no mutation tool installed)

| Mutant | Killed by |
| --- | --- |
| head comparison always true | A4 |
| failed-job refusal disabled | A5 |
| substring name matching | A6 (the shard name would waive its aggregate) |
| away refusal deleted | A9 |
| schema version check deleted | A8 |

## Acceptance-criteria coverage

Every functional requirement FR-001 to FR-014 and every acceptance scenario US1.1 to US4.3 is either covered by a named case in `tdd/test-list.md` or, for FR-011 and FR-014, verified by the unchanged existing cases, the lint gate, and the documentation gate.
No criterion is left uncovered.

## Accepted limitations

- The runner's emission is proven by a fixture harness over the shipped block plus a real hand-off to the merge tool, not by a full real project build, because the runner is private home state and a real build needs a project toolchain and network this feature does not own.
- No mutation tool is installed, so mutants were applied by hand, each recorded above with the case that killed it.
- The project constitution is still the unfilled Spec-Kit template, so the TDD principle was adopted as a working gate by instruction rather than by a ratified constitution.
