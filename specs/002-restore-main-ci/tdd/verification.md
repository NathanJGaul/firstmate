---
feature: 002-restore-main-ci
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: a980664d
behaviors: 30
proven: 17
likely: 3
test_after: 0
no_test: 0
not_applicable: 10
high_smells: 0
criteria_total: 14
criteria_covered: 14
mutation_score: unmeasured # no mutation tool in the profile; 6 deliberate mutants sampled, 6 caught
mutants_survived: 0
suite: per-file at HEAD, see "Suite evidence"; the repository suite is not run locally in full
---

# TDD Verification: Restore Main CI

**Verdict: PASS_WITH_GAPS.** Every behavior has red evidence or a recorded reason it has none, no high-severity smell was found, and every acceptance scenario has a test through its real entry point; the gaps are the missing mutation tool, an unreproducible stress claim, and an audit that was not independent.

## Independence

The author of the tests ran this audit, so it is not independent.
Every test and source file named below was re-opened and judged as it stands, and the git history was read for ordering, but a fresh-context reviewer may find what this pass did not.
No subagent was used for the smell pass.

## Test-first evidence

Commits in order: `d922ec8f` (Pi narrowing, source and tests together), `4c33fe46` (fake forge restored), `50587401` (Calm fixtures), `9a9ce918` (wait helper, its case, and the interruption case), `7d770409` (non-processing custom run assertion), `9c7a4d90` (Spec-Kit artifacts), `a980664d` (OpenCode guard fix and its case).

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| A1, U1 | PROVEN | cycle 1 red `TypeError: Cannot read properties of undefined (reading 'trim')`; `d922ec8f` adds tests and source together |
| A2, U2 | PROVEN | same cycle and commit; the processing request fired as a custom run is the failing stimulus |
| A5 | PROVEN | baseline red `TS2339` on Pi 1.2.0 and 1.3.0; `d922ec8f` clears it |
| A6, U7 | PROVEN | baseline red `the slow head did not consume ...`; the driving assertion pre-existed; `4c33fe46` restores the fixture it depends on (no production source involved) |
| A9, U9, U10 | PROVEN | baseline red `ERR_MODULE_NOT_FOUND`; `50587401` |
| A10, U11 | PROVEN | baseline red `Cannot find module './fm-calm-visibility-policy.ts'`; `50587401` |
| U12, U13, U14 | PROVEN | cycle 7 red `wait_for_sleep_child: command not found` then `not ok ... (status 127)`; test and helper land in `9a9ce918` |
| A14, U16 | PROVEN | cycle 9 red `Error: write EPIPE`, 5 of 5; test and fix land in `a980664d` |
| A12, U15 | LIKELY | red is statistical, not a committed failing test: 1 failure in 931 randomized runs of the unaided predicate; the fuzz harness is outside the repository (reproduction in the appendix) |
| A13 | LIKELY | a verification run, not a committed test: 1727 runs, 0 unexpected successes; recorded in cycle 8 |
| A3, A4, A7, A8, A11, U4, U5, U8 | NOT_APPLICABLE | existing or guard tests that were green before the change (retyped events, budget cases, the drain case) |
| U3, U6 | NOT_APPLICABLE | characterization of adopted upstream behavior: first run green, deliberate mutant caught (cycles 4 and 2); U3 was added after its implementation and is recorded as a characterization baseline, not as test-first |

Existing-test audit (diff `0457fccc..a980664d`, everything outside `specs/`):

- No assertion removed or loosened, no skip or exclusion added, no threshold lowered.
- `tests/fm-pi-branch-extension.test.sh:2131` previously fired the processing request as `{ prompt: pending.message.content }` and now fires `{ messageType: "custom", message: processingMsg }`; the assertions after it (`aborted`, stripped request) are unchanged. The old stimulus modelled a user-prompt run that Pi 1.1 and newer never produces for this request, so this is a stimulus correction, not a weakening.
- `tests/fm-contributions.test.sh:640` onward swaps the fork's lock-based clock helper for upstream's rename-published bump, narrows `reserve` to a single caller, and restores the `slow-wave` cases; every assertion in the file is unchanged and the file passes (cycle 5).
- All other removed lines are `prompt`-only event literals replaced by the same literal with `messageType: "user"`.

`tasks.md` against the list: no task is ticked whose behavior is not `DONE`/`BASELINE`; T020 and T021 stay open until the implement step.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | A8 (no torn fake clock under concurrent callers) has no committed deterministic test; it is covered by the existing parallel-wave cases and by stress runs whose scripts live outside the repository | `tdd/cycle-log.md` cycle 5; `tests/fm-contributions.test.sh` budget cases |
| 2 | MED | A13's fuzz harness is not in the repository, so the 1727-run claim cannot be repeated from a checkout | appendix below holds the harness text |
| 3 | MED | Eager test: `test_wait_for_sleep_child_requires_a_parked_child` pins three behaviors (no child, non-sleep child, sleep child) and unlabelled literals `3`, `200`, `200000` | `tests/fm-wake-queue.test.sh:2269` |
| 4 | MED | Fixed stalls by design: the OpenCode case stalls the host 300 ms and then waits 200 ms; under extreme load the stall may be too short and the case would pass without exercising the race (a false pass, never a false failure) | `tests/fm-pi-watch-extension.test.sh`, `test_opencode_turnend_guard_survives_a_guard_that_exits_without_reading_stdin` |
| 5 | LOW | `reap_owned` is defined inside a test function, so it leaks into the file's global namespace | `tests/fm-wake-queue.test.sh:2272` |
| 6 | LOW | The watch-extension custom-run assertion extends an existing eager heredoc case rather than being its own case | `tests/fm-pi-watch-extension.test.sh` replacement case tail |
| 7 | INFO | `tests/fm-pi-branch-live-e2e.test.sh` had two event stubs retyped but is opt-in and was not run | `FM_PI_BRANCH_LIVE_E2E=1` gate |

No finding is high severity: no assertion-free, tautological, doubled-subject, vacuous, conditional, or skipped test was found.
The Pi extension tests drive the extension default export through a fake Pi API on purpose, because the host is the boundary; the fake does not stand in for the unit under test.

Properties: the changed Pi, Calm, contributions, and wake-queue files are deterministic on repeated runs after the fixes, isolated through per-case temp roots, and slow by the repository's norm (the longest, contributions, takes 150 s because its fixture now really delays reads).

## Mutation results

No mutation tool is installed; deliberate mutants were run instead and each was restored and checked.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `fm-primary-pi-watch.ts`: consume a wake from a custom message's content | U6, A4 | No | `Pi replacement must replay a streaming follow-up before consumption: expected exit 0, got 1` |
| `fm-branch-supervision.ts`: mirror a custom message as captain dialog | U1, A1 | No | `mirror filtering, ordering, and cursor must hold ... timed out waiting for incremental mirror` |
| `fm-branch-supervision.ts`: any custom run counts as the processing request | U3 | No | `a custom run that is not the processing request was aborted as a dedicated processing turn` |
| `wake-helpers.sh`: `wait_for_sleep_child` returns 0 immediately | U12 | No | `a process without children counted as parked (status 0)` |
| `wake-helpers.sh`: helper also accepts a `tail` child | U14 | No | `a non-sleep child counted as parked (status 0)` |
| `fm-primary-turnend-guard.js`: remove the stdin error listener (the unfixed plugin) | U16, A14 | No | `Error: write EPIPE`, 5 of 5 |

Sampled: 6 mutants across the 4 behaviors an acceptance scenario depends on most; the fixture-only behaviors (A6, A9, A10) are covered by their original red.
This is a sample and not an exhaustive score.

## Traceability

| Scenario | Tests | End to end |
| -------- | ----- | ---------- |
| US1.1 | A1, U1 | Yes (extension default export, fake Pi API) |
| US1.2 | A2, U2 | Yes |
| US1.3 | A3, U4, U5 | Yes |
| US1.4 | A4, U6 | Yes |
| US1.5 | A5 | Yes (real Pi 1.2.0 and 1.3.0 declarations) |
| US2.1 | A6, U7 | Yes |
| US2.2 | A7, U8 | Yes |
| US2.3 | A8 | Partly: existing parallel-wave cases plus recorded stress runs (finding 1) |
| US3.1 | A9, U9, U10 | Yes (real Pi package, tmux for the escape case) |
| US3.2 | A10, U11 | Yes (real Pi) |
| US4.1 | A11, U15 | Yes |
| US4.2 | A12, U12, U13, U14 | Yes |
| US4.3 | A13 | Recorded run (finding 2) |
| US5.1 | A14, U16 | Yes |

Untested criteria: none.
Tests tracing to nothing: none.

## Suite evidence

Pi 1.3.0 and 1.2.0 scratch installs, machine bash 5.3.15, commit under test as noted.
Final pass at `9c7a4d90`: strict typecheck ok on both Pi releases; `tests/fm-pi-branch-extension.test.sh`, `tests/fm-calm-pi-extension.test.sh`, `tests/fm-calm-pi-queue-retention-live-e2e.test.sh` exit 0 on both; `tests/fm-pi-watch-extension.test.sh` exit 0 on Pi 1.2.0 and failed once on Pi 1.3.0 in the OpenCode case (cause found and fixed in `a980664d`); `tests/fm-contributions.test.sh` exit 0 (150 s); `tests/fm-wake-queue.test.sh` exit 0 (235 s).
Re-run of `tests/fm-pi-watch-extension.test.sh` at `a980664d`: Pi 1.3.0 three times and Pi 1.2.0 once, all exit 0 (50 to 56 s); the isolated OpenCode case passed 160 of 160 runs in groups of four after the fix (5 failures in 80 before).
`bin/fm-lint.sh` on all changed shell files with full dataflow, pinned ShellCheck 0.11.0: no findings.
`LC_ALL=C bin/fm-test-run.sh --check-coverage`: ok (252 scripts).

## What was not audited

- The repository suite in full: it was red on main by definition and takes about 15 minutes per shard on CI; the delivery pull request's 18 CI jobs are the full-suite evidence.
- Mutation testing with a tool: none installed; deliberate mutants only.
- `tests/fm-pi-branch-live-e2e.test.sh` and the other opt-in live guards that spend model tokens.
- macOS behavior of `ps -A -o ppid= -o comm=` in the new helper: Linux only; the macOS CI job runs only the Bearings snapshot compatibility suite.
- Other Pi releases than 1.0.4 (typecheck only, fails by design), 1.2.0, and 1.3.0.
- Coverage percentages: the profile defines a script-registration coverage guard, not line coverage.
- Performance and load behavior beyond the repeat counts quoted above.

## Appendix: interruption fuzz harness (finding 2)

Run under bash 5.2.21 (`ubuntu:24.04` with `jq git tmux procps python3`), with the repository mounted read-only at its own path and `$ROOT` set to it.
`MODE=old` is the unaided predicate; `MODE=new` waits for the parked drain first.
Count lines that do not end `rc=143 err=`; each `err=` also shows any trap parse error.

```bash
#!/usr/bin/env bash
set -u
. "$ROOT/tests/wake-helpers.sh"
DRAIN="$ROOT/bin/fm-wake-drain.sh"
TMP_ROOT=$(fm_test_tmproot fm-wake-fuzz)
one() { # delay_seconds
  local d=$1 dir state pid rc i err
  dir=$(make_case "c$RANDOM$RANDOM"); state="$dir/state"; err="$dir/err"
  printf 'done: x\n' > "$state/task.status"
  append_wake "$state" signal task.status "signal: task" || return 9
  FM_STATE_OVERRIDE="$state" FM_WAKE_DRAIN_TEST_DELAY_BEFORE_COMMIT=1 "$DRAIN" > "$dir/out" 2> "$err" &
  pid=$!
  i=0
  while [ "$i" -lt 200000 ]; do
    if [ "$(cat "$state/.wake-queue.lock/pid" 2>/dev/null || true)" = "$pid" ] \
      && grep -Eq '^(pending|announced):handling:' "$state/.watcher-down" 2>/dev/null; then break; fi
    i=$((i+1))
  done
  if [ "${MODE:-old}" = new ]; then
    wait_for_sleep_child "$pid" || { printf 'd=%s rc=NOPARK\n' "$d"; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; return; }
  fi
  [ "$d" = 0 ] || sleep "$d"
  kill -TERM "$pid" 2>/dev/null
  wait "$pid"; rc=$?
  printf 'd=%s rc=%s err=%s\n' "$d" "$rc" "$(tr '\n' '|' < "$err" | cut -c1-160)"
}
for rep in $(seq 1 "${REPS:-3}"); do
  for k in $(seq 1 "${PER:-40}"); do d=$(printf '0.%03d' $((RANDOM % 70))); one "$d"; done
done
```
