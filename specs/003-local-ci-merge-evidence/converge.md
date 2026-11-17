# Convergence: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Date**: 2026-10-26

## Merge readiness

The feature is implemented, tested, linted, and documented inside its branch.
Every acceptance criterion in `spec.md` has a passing test named in `tdd/test-list.md`, and every refusal path the brief named is covered by a case that also proves no merge reached the forge.

## Evidence

| Gate | Result |
| --- | --- |
| `tests/fm-pr-merge.test.sh` (full) | recorded in `tdd/verification.md` |
| Branch-point baseline of the same file | recorded in `tdd/verification.md` |
| `bin/fm-lint.sh` on the changed shell files at the pinned ShellCheck | clean |
| `bin/fm-doc-audience-check.sh` | `ok surfaces=189 local_links=747` |
| Deliberate mutants | five applied, five killed (see `tdd/cycle-log.md`) |
| Runner hand-off | the emitted file carried a real head-bound merge through `bin/fm-pr-merge.sh` with the fixture forge |

## Risk

Low.
The flag is inert unless an operator passes it, it cannot waive anything outside the exact head it proves, it cannot waive a name it does not record as passing, it is refused while away, and it writes nothing to the forge.
The only shared surface it touches is the merge gate itself, whose existing conditions are unchanged and whose test file keeps passing.

## Follow-ups worth shipping separately

- The local CI runner could gain a `--parallel` mode for quiet hosts, where the network namespaces already make concurrent shards safe.
- The runner could rerun a shard automatically when it failed only on a 5 s test timeout while host load was high, which the report found to be the dominant false failure mode.
- The pricing-sheet project could take `webServer.timeout` from an environment variable, so managed mode would stop needing the fallback on a loaded host.
- A future task could decide whether the auto-mode classifier should accept a locally proven head; this feature deliberately leaves that classifier untouched.

## Not built, by instruction

- No merge-authority change: a merge on local proof still needs the captain's explicit word for that pull request.
- No commit status, check run, comment, or label is ever written to a forge.
- No change to branch protection, required contexts, or hosted-check handling beyond what the flag reads.
- No change to `--allow-red` or `--allow-missing`.
