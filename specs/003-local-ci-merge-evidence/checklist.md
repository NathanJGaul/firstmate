# Implementation Checklist: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Date**: 2026-10-26 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Functional requirements

- [x] FR-001 The runner writes a result file with the full head and one name/exit-code record per printed job and aggregate line.
- [x] FR-002 The runner's printed summary, aggregate lines, and exit status keep their current meaning.
- [x] FR-003 The recorded head is the full 40-character commit, and the consumer refuses an abbreviated one.
- [x] FR-004 The flag is accepted once with a separate path; the inline-value and repeated forms refuse.
- [x] FR-005 Local evidence is active only when the file's head equals the live head read at merge time.
- [x] FR-006 A head mismatch refuses and reports both commits.
- [x] FR-007 Any recorded failed job refuses before the forge is read, naming the jobs.
- [x] FR-008 A red or unreported check is waived only by an exact passing job name, and uncovered checks keep their own refusal plus the coverage line.
- [x] FR-009 The flag refuses while the away record exists and on a forge whose merge requires its head pipeline.
- [x] FR-010 No forge write other than the merge command happens on the evidence path.
- [x] FR-011 No existing gate changed: open, non-draft, mergeable, no conflicts, captain hold, away authority, head-bound merge, post-merge read-back, outcome recording, and the per-name waivers.
- [x] FR-012 An unusable or wrongly shaped file refuses before metadata is recorded and before any forge read.
- [x] FR-013 Every new refusal names its cause and leaves the merge unperformed.
- [x] FR-014 The script header and usage line own the flag contract, and the prose that names the attended waivers is accurate.

## Acceptance scenarios

- [x] US1.1 Required checks that never reported are waived by a matching full run, and exactly one head-bound merge lands.
- [x] US1.2 A red check with a passing job of the same name is waived.
- [x] US1.3 No commit status, comment, or other forge artifact is written.
- [x] US2.1 A head mismatch refuses and names both commits.
- [x] US2.2 A failed job refuses and is named.
- [x] US2.3 An uncovered check keeps its refusal and is named as uncovered.
- [x] US2.4 An unusable file refuses before recording state.
- [x] US3.1 The flag is refused while the away record exists.
- [x] US3.2 The flag works again once the record is archived.
- [x] US3.3 A forge that requires its head pipeline refuses the flag.
- [x] US4.1 A completed run records the full head and every printed job and aggregate line.
- [x] US4.2 A subset run records only the jobs that ran.
- [x] US4.3 A failing job is recorded with its nonzero exit while the printed summary and exit status are unchanged.

## Engineering gates

- [x] `bin/fm-lint.sh bin/fm-pr-merge.sh tests/fm-pr-merge.test.sh` is clean at ShellCheck 0.11.0.
- [x] The private runner's new block introduces no new ShellCheck finding; the file's pre-existing findings are unchanged.
- [x] `tests/fm-pr-merge.test.sh` passes in full.
- [x] Deliberate mutants kill the head comparison, the failed-job refusal, whole-name matching, the away refusal, and the version check.
- [x] `bin/fm-doc-audience-check.sh` passes.
- [x] No agent co-author in the commit; one sentence per line in every tracked Markdown file.
- [x] The worktree contains no scratch artifacts and no change outside the planned files.

## Out of scope, deliberately

- Merge-authority policy and the auto-mode classifier are untouched.
- No commit status is ever written to any forge.
- Hosted-check handling beyond what the flag reads (branch protection edits, required-context changes) is untouched.
