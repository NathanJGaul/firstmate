---
feature: 004-orca-leak-fixes
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 9ec29c8b
behaviors: 26
proven: 23
likely: 0
test_after: 0
no_test: 0
not_applicable: 3
high_smells: 0
criteria_total: 9
criteria_covered: 9
mutation_score: not measured by a tool; 0 survivors across 25 deliberate mutant runs and one whole-feature revert (scope: bin/backends/orca.sh only)
mutants_survived: 0
suite: tests/fm-backend-orca.test.sh 73 ok, 0 not ok (212 s); tests/fm-teardown-endpoint-safety.test.sh 27 ok, 0 not ok (90 s)
---

# TDD Verification: Orca Backend Leak Fixes

**Verdict: PASS.** Every behavior that changed has a recorded red before its change and a single commit holding its test and its adapter change; every criterion is covered through a real entry point and no sampled mutant survives.

This is the second run of the audit.
The first run failed because 16 behaviors had been written green-first; the captain chose a strict redo, the branch was rebuilt as eleven red-green cycles, and this report re-derives the evidence from that history.

**This audit is not independent.**
The same session wrote the tests, the implementation, and this report, and no fresh-context subagent was used.
Every claim was re-derived from the files, the git history, and fresh runs rather than from memory, but a reader should treat the verdict as the author's own audit.

## Test-first evidence

History, from `git log --stat`: eleven commits (`18e44974` to `9ec29c8b`), each changing `tests/fm-backend-orca.test.sh`, `bin/backends/orca.sh`, and `tdd/cycle-log.md` together, so the test and its source change always land in the same commit, with the red recorded in that commit's log entry.
No commit holds a failing test.
The adapter was staged on purpose: early cycles used a deliberately naive implementation (an unconditional startup read, an unconditional strict rename) so that the next behavior's test went red against it and forced the real rule.

| Behaviors | Class | Evidence |
| --------- | ----- | -------- |
| U1, U7 | PROVEN | cycle 1 red against the unchanged adapter; `18e44974` |
| U6 | PROVEN | cycle 2 red (`got 'term-startup'`); `b11edead` |
| U3 | PROVEN | cycle 3 red; `f3e9ee3a` |
| U2 | PROVEN | cycle 4 red; `537a04b0` |
| U4, A4 | PROVEN | cycle 5 red (`got 'undefined'`, no second terminal created); `01c20dfe` |
| U5, A2 | PROVEN | cycle 6 red (`got 'term-startup'`); `3c5567b4` |
| U8, A1, U11, A3 | PROVEN | cycle 7: U8 and A1 red with no rename, then U11 and A3 red against the naive unconditional rename; `f9e6c037` |
| U12, A5 | PROVEN | cycle 8 red (titled before the path check); `60013f4d` |
| U9, U10, A6 | PROVEN | cycle 9 red (strict rename failed the create); `d12a5621` |
| A11 | PROVEN | cycle 10 red (startup-only rename); `8ee90887` |
| A8, U13, A7, A9 | PROVEN | cycle 11: twelve tests red before the release argument changed; `9ec29c8b` |
| A10, U14, U15 | NOT_APPLICABLE | existing tests, unchanged by this feature and green before and after |

Pre-existing tests: ten `worktree rm` assertions changed from `--force --json` to `--force --delete-branch --json` in cycle 11, made before the implementation as part of the U13 behavior change; each is a longer, equally specific expected sequence, so none is weakened.
The diff removes no other assertion, adds no skip, pending, or exclusion marker, and changes no coverage threshold or test filter.
The final code and tests are byte-identical to the tree the first audit examined (`git diff backup-pre-redo HEAD -- bin tests` is empty), so its sampled mutants and base-adapter results still describe this tree.

`tasks.md` against the list: every ticked task's behaviors are `DONE`; no behavioral task is unticked with its behavior `DONE`.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | Three tests loop over several result shapes in one function, so one failure stops the rest; each failure message names its shape | `tests/fm-backend-orca.test.sh`, the loops in `test_spawn_adopts_the_terminal_shape_and_prefers_it_over_a_startup_terminal`, `test_spawn_creates_a_terminal_for_an_unusable_startup_terminal`, `test_json_get_ignores_startup_terminal_without_a_handle` |
| 2 | LOW | The kept-branch teardown test repeats the setup of the matching-id teardown test instead of sharing a factory, as every sibling teardown test in this file does | `test_ship_teardown_completes_when_orca_keeps_the_branch` against `test_ship_teardown_removes_orca_worktree_when_id_path_matches` |

Not actioned: finding 1 is parametrization with named failure messages, and finding 2 matches the file's own pattern.
Not findings, checked: no assertion-free, tautological, doubled-subject, vacuous, or empty test was found; every assertion names a specific value or argument list.
The exact-argument assertions look implementation coupled, but the CLI call is the behavior under test, since the adapter's only output toward Orca is that call.
No test is sleepy, uses a real clock or network, or depends on order; every case builds its own temporary root and fake CLI through the file's existing helpers.

## Mutation results

No mutation tool is installed, so strength was measured with deliberate mutants of `bin/backends/orca.sh`, each applied alone and restored exactly.
The first audit applied 22 mutant runs during the loop and three fresh ones plus one whole-feature revert; none survived, and the redo's staged reds add a further independent check, since each naive stage is itself a failing implementation that the next test caught.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| release arguments reordered | U13 | No | caught by the exact argument list |
| rename titled with the terminal's own handle | U8, A1 | No | caught |
| startup handle read from `tabId` | U1 | No | caught |
| rename restricted to startup-shaped terminals | A11 | No | caught only by A11, which cycle 10 added |
| adapter replaced by the pre-feature file | all 20 new tests of the first audit | n/a | 12 fail and 8 pass; the 8 are guards for retained behavior or negative boundaries, each shown red in cycles 3 to 7 against a naive stage |

Coverage tooling: the profile's coverage command is the runner inventory guard; it passes under `LC_ALL=C` and exits 1 under `en_US.UTF-8` with a `comm` sort-order message, an environment issue in the runner unrelated to this feature.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| US1.1 startup terminal adopted | A1, U1, U7, U8 | Yes, `fm-spawn.sh` |
| US1.2 `terminal` shape kept, preferred, and titled | A2, A11, U5 | Yes |
| US1.3 neither shape creates one titled terminal | A3, U11 | Yes |
| US1.4 unspawned or handle-less startup terminal falls back | A4, U3, U4 | Yes |
| US1.5 pathless result closes and releases | A5, U12 | Yes |
| US2.1 release asks for safe branch deletion | A7, A9, U13 | Yes, `fm-teardown.sh` and spawn abort cleanup |
| US2.2 kept branch does not fail the release | A8 | Yes |
| US2.3 abort cleanup uses the same release | A9 | Yes |
| US2.4 refusals precede any release | A10, U14, U15 | Yes |
| edge case: failed rename | A6, U9, U10 | Yes |

Untested criteria: none. Tests tracing to nothing: none. FR-009: the branch diff adds no `git branch -d`, `-D`, or ref deletion.

## What was not audited

- Independence: see the note under the verdict.
- Live Orca behavior: no Linux Orca lab exists, so a real startup terminal, a real `terminal rename`, and real branch deletion and retention were not exercised; everything here is against the fake CLI.
- The profile's full suite (`--all`), which CI owns; only the changed file and the teardown endpoint-safety suite were run.
- Performance and load behavior: no criterion, no test, not assessed.
- Other Orca slices (folder-kind rejection, CLI discovery, version gate, Escape, recovery, receipts): out of scope.
