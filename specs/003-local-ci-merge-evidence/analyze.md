# Cross-Artifact Analysis: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Date**: 2026-10-26

## Consistency between spec, plan, tasks, and code

| Check | Result |
| --- | --- |
| Every functional requirement has at least one acceptance scenario in `spec.md` and at least one test in `tdd/test-list.md` | pass (FR-001 to FR-014 traced in the test list; FR-011 and FR-014 are verified by the unchanged existing cases and by the lint/doc gates) |
| Every user story has an independent test | pass (US1-US4 each name a runnable case or harness) |
| Every task maps to a test list entry and to a diff hunk | pass |
| No requirement is implemented twice under two owners | pass (the merge script's header owns the flag contract; the spec owns behavior; no schema copy was added to `docs/`) |
| Scope boundaries stated in the spec match what was built | pass (no merge-authority, classifier, branch-protection, or status-writing change) |

## Wording and provenance

- The captain's intent subset is the source of the spec's Overview and of FR-004 to FR-012.
- The Firstmate spec's scoped build instructions are reflected in the plan's design decisions, not in the spec's requirements.
- Out-of-scope items named in the brief appear as "Out of scope" in `checklist.md` and as follow-ups in `converge.md`.

## Risk review

| Risk | Mitigation in this change |
| --- | --- |
| Stale evidence merges unproven code | head equality with the live head, refusing on mismatch, plus the unchanged `--match-head-commit` |
| A partial local run waives jobs it never ran | coverage is name-exact and only printed jobs are recorded; a subset run waives nothing it did not prove |
| A locally produced proof looks like hosted proof | nothing is written to the forge; the evidence lives only in a file the operator passes |
| Autonomous merges on local proof | the flag is refused while the away record exists and the branch actor never reaches it |
| A malformed file crashes rather than refuses | every field is validated with `jq` before use, and the refusal is a named message with a distinct exit status |
| Aggregate checks silently waived by shard names | whole-name matching, pinned by the shard-versus-aggregate case in the tests |

## Gaps and accepted limitations

- The runner lives outside this repository, so its emission is proven by a fixture harness that extracts and runs the shipped block, plus an end-to-end hand-off to the real merge tool.
  A full real project build was not run for this feature.
- Kernel-level facts (`jq` exit statuses, bash `read` with a tab separator) are covered by the tests; no mutation tool is installed, so mutants were applied by hand and recorded in the cycle log.
