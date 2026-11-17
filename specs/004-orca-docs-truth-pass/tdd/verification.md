---
feature: 004-orca-docs-truth-pass
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 72375980
behaviors: 48
proven: 38
likely: 0
test_after: 0
no_test: 0
not_applicable: 9
dropped: 1
high_smells: 0
criteria_total: 18
criteria_covered: 18
mutation_score: unmeasured
mutants_survived: 1
suite: targeted suites 5 passed, 0 failed, 808s; final re-run of 2 passed, 0 failed, 98s; full repository suite not run
---

# TDD Verification: Orca Documentation Truth Pass

**Verdict: PASS_WITH_GAPS.** Every behavior that can fail has recorded red evidence that git history corroborates, and every acceptance scenario reaches a claim-audit check on the real documents, but the audit was authored and graded by the same session, no mutation tool exists, and the full repository suite was not run.

## Audit independence

The same session that wrote the claim audit also performed this audit, so it is not independent.
Every test and source file named below was re-read for this report rather than recalled.
No fresh-context subagent was used for the smell pass, because delegation was not part of the authorized task.
A reviewer who wants an independent grade should read `tdd/claim-audit.sh` against the rubric once more.

## Test-first evidence

The "test" for this feature is `tdd/claim-audit.sh`, a script that greps the five owning files, because the change is prose and one comment.
It was committed in `ff32cb98`, before any document edit (`3bb2c36d` is the first), and its red run is recorded in `tdd/cycle-log.md`.

| Behaviors | Class | Evidence |
| --- | --- | --- |
| A1 to A8, A10 to A13, U1 to U16, U18, U19, U22, U24 to U30 | PROVEN | cycle log records the red (`FAIL` lines, 55 of 68 on the full baseline, and per-cycle reds 1 to 6); the audit is in `ff32cb98`, the document edit that satisfies each is in a later commit (`3bb2c36d`, `f9caff5d`, `f898e6f1`, `5f653d61`) |
| A9, A14, A15, A16, U17, U20, U21, U31, U32 | NOT_APPLICABLE | characterization baselines and invariants, green by definition against the untouched files; each was shown able to fail with a deliberate mutant (M6, M7, M8, M10, and the two in "Mutation results" below) |
| U23 | dropped | folded into U22 before the first red, recorded in the test list |

Discrepancies between the three sources:

- The two audit corrections (`U29`, `U31`) were committed with the first document edit in `3bb2c36d`, not in a commit of their own, but before the trust-script edit they govern (`5f653d61`), and the cycle log says so.
- The wording refactor in `72375980` was committed before it was logged and is logged after cycle 6, which the log states.
- Cycles 1 to 3 share one commit and cycles 4 to 6 have one commit each, so "one commit per cycle" holds only for the later cycles; the log records the reason (adjacent paragraphs of one file).

## Existing tests

No test file changed: `git diff af20b2c9..HEAD -- tests` is empty, and no assertion, filter, skip, threshold, or exclusion was touched.
The only non-prose file changed is `bin/fm-claude-trust.sh`, and `U32` shows every changed line is a comment or blank.
The one other non-document edit is the audience inventory, which gained 14 classification entries and nothing else.

## Tasks against the list

Every `[X]` task in `tasks.md` names behaviors that are `DONE` or `BASELINE` on the list.
No behavioral task is unticked with its behavior `DONE`.
T022 to T026 are non-behavioral closing tasks left for `/speckit.implement`.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | MED | Foreign style and bypassed utility: the audit does not use `tests/lib.sh` assertions or the repository runner, and it is not registered in `tests/` | `tdd/claim-audit.sh`; deliberate, recorded in `research.md` R5 because a registered phrase pin would break on harmless rewording and the repository's documentation check does not keyword-lint prose |
| 2 | MED | Implementation coupled by design: each check pins phrases, so a legitimate rewording fails it and needs the audit updated | `tdd/claim-audit.sh:90-170`; mitigated by line-level term sets, not exact sentences, and by keeping the audit out of CI |
| 3 | LOW | The style check `A16` is a heuristic: it flags `[a-z0-9)`][.!?]  *[A-Z]` on added lines of four documents and any em dash in the feature's Markdown, so it can miss an abbreviation-style split and does not scan Markdown the feature did not add to | `tdd/claim-audit.sh` `style_ok` |
| 4 | LOW | Three checks are vacuously green until the edits exist (`U32`, `A15`, `A16`); they were classified BASELINE and each has a mutant that turns it red | cycle log "Deliberate mutants" |
| 5 | LOW | One mutant survived: deleting the macOS label from one retained sentence leaves the subsection heading carrying the same label | M9; judged equivalent because the heading is the label, and the stricter mutant M9b is caught |
| 6 | LOW | `A8` to `A13` verify wording, not truth: the audit cannot tell whether a sentence is correct, only that it is present, so correctness rests on the manual re-read recorded in `data-model.md` and `converge.md` | requirement FR-020 has no automated test by design |

No HIGH smell: no assertion-free, tautological, re-implemented, doubled-subject, vacuous, conditional, or always-skipped check was found.
Each audit function names the file and the term set it requires, uses its own `has_line` helper with PCRE lookaheads, and fails with the behavior id and a description.

## Mutation results

No mutation tool is installed (`tdd-profile.md` records `mutation: null`), so strength was measured with deliberate mutants on the committed files, each restored with `git checkout -- <file>` and re-checked with `claim-audit.sh all` (68 checks, 0 failed).
Sampled: 13 mutants across 6 files, covering the acceptance behaviors A1, A2, A8, A10, A12, A16 and the invariants U17, U20, U21, U24, U31, U32, and A15.

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| reinstate "Orca is macOS-only" and the no-version limit | A1, A2 | No | caught by `S1`, `U6`, `S3` |
| reinstate the "terminal API exposes only an interrupt and an Enter" reason | A8 | No | caught by `U18`, `U19` |
| em dash and two sentences on one line | A16 | No | both reported |
| second added line in the recovery skill | A10 | No | caught by `U22` |
| replace the dated Linux entry sentence | A12 | No | caught by `U25` |
| change the capability matrix row | U21 | No | caught |
| delete the secondmate-unsupported limit | U17 | No | caught |
| replace the recovery-grade classifier phrase | U20 | No | caught |
| delete one macOS label | U24 | Yes | equivalent: the heading carries the label |
| delete both macOS labels | U24 | No | caught |
| add an unexpected file | A15 | No | caught |
| replace the structural-not-path-prefix sentence | U31 | No | caught |
| add a non-comment line to `bin/fm-claude-trust.sh` | U32 | No | caught |

Not sampled with a mutant: `A3` to `A7`, `A9`, `A11`, `A13`, and the individual `U` checks inside them beyond those shown; their reds in the cycle log (each `FAIL` was observed before the edit and cleared by it) are the only strength evidence for them.

## Traceability

| Scenario or requirement | Behaviors | Real entry point |
| --- | --- | --- |
| US1.1, US1.2 (Linux setup, macOS retained) | A1, U1 to U5 | the document text, through `claim-audit.sh` |
| US1.3 (keys) | A4, U8, U9 | yes |
| US1.4 (version, native state) | A2, A3, U6, U7 | yes |
| US1.5, US1.6, US1.7 (decisions) | A7, U12 to U15 | yes |
| US2.1 (recovery line) | A10, U22 | yes |
| US2.2 (key reason) | A8, U18, U19 | yes |
| US2.3, US2.4 (refusal and matrix retained) | A9, U20, U21 | yes |
| US3.1 (macOS retained) | A11, U24 | yes |
| US3.2, US3.3, US3.4 (Linux entry) | A12, U25 to U28 | yes |
| US4.1, US4.2 (trust comment) | A13, U29 to U31 | yes |
| US4.3 (no behavior change) | A14, U32, and `tests/fm-claude-trust.test.sh` | yes |
| FR-006, FR-007 | A5, A6 | yes |
| FR-018, FR-021 | A14, A15 | yes |
| FR-019 | A16 | heuristic, finding 3 |
| FR-020 (re-read against the appendix) | none | manual, `data-model.md` and `converge.md` |
| SC-001 | A1 to A6 stale-statement checks | yes |
| SC-004 | existing suites and lint | yes |

Untested criteria: none among the 18 acceptance scenarios.
Untested requirement: FR-020 and SC-005 are manual by nature, recorded as finding 6.
Tests tracing to nothing: none; `S1` to `S9` serve the stale-statement success criterion SC-001.

## What was not audited

- The full repository suite was not run; only the suites that can observe this change were: `tests/fm-documentation-audiences.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-backend-orca.test.sh`, `tests/fm-backend.test.sh`, and `tests/fm-control.test.sh`, plus `bin/fm-lint.sh` with the pinned ShellCheck 0.11.0 and actionlint 1.7.12.
- Mutation was by sampled deliberate mutants, not a tool, and its scope was the five owning files.
- Truth of the new claims against live Orca was not re-audited here: the claims rest on read-only Orca commands run during this task and on the evaluation report's observations, and `converge.md` lists what stays unexercised.
- The macOS facts were retained, not re-verified; no macOS host was available.
- Performance of the audit: it runs in about a second and was not otherwise assessed.
- Independence of the grader, as stated above.
