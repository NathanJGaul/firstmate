# Research: Restore Main CI

Evidence below was gathered on 2026-10-16 from the red run on main (run 38557743360, 2026-10-14) and from local reproduction.
Each failure was reproduced before any change.

## R1 - Pi extension typecheck and runtime failure (parallel 1)

**Evidence**:
The strict no-emit typecheck fails with TS2339 on `event.prompt` at `.pi/extensions/fm-branch-supervision.ts` and `.pi/extensions/fm-primary-pi-watch.ts`.
It passes against Pi 1.0.4 and fails against 1.2.0 and 1.3.0 (scratch installs of each release).
In Pi 1.2.0 `BeforeAgentStartEvent` is a union: `BeforeAgentStartUserEvent` (has `messageType: "user"` and `prompt`) or `BeforeAgentStartCustomEvent` (has `messageType: "custom"` and `message`).
A run started by `pi.sendMessage(..., { triggerTurn: true })` is the custom variant, and Firstmate's own branch processing request is sent that way.
So `event.prompt.trim()` throws a TypeError on those runs, which is a runtime defect and not only a type error.

**Decision**: Adapt the extensions by narrowing on `event.messageType`, exactly as upstream's merged fix (#7248) and its regression case (#7387) do, and do not pin Pi.

**Rationale**:
Pinning Pi in CI would turn the check green while leaving the defect live for every operator on a current Pi (the maintainer's own Pi is 1.3.0).
The CI comment states the install is unpinned on purpose so drift is caught on the next run.
Matching upstream's hunks keeps later upstream merges free of conflicts, which matters because a conflicted merge caused R2.
No new policy decision exists: the unpinned tracking policy is unchanged.

**Alternatives considered**:
Pin `@earendil-works/pi-coding-agent` in CI (hides the runtime defect; rejected).
Support both event shapes with `"prompt" in event` (works on Pi 1.0.x too, but diverges from upstream and Pi 1.0.x is no longer current; rejected).
Both pin and adapt (the pin adds nothing once the code adapts; rejected).

**Port set**:
Production hunks of 8c9c67de in the two extensions.
The test-event typing hunks of 8c9c67de (`messageType: "user"` on user-prompt events, and the processing request fired as a custom message).
The custom-run regression hunk of 5f2b81bc.

## R2 - Contributions slow-head budget (serial 5)

**Evidence**:
`test_unmeasured_url_does_not_starve_the_tail` writes the `slow-wave` fault but the fake forge in `wrap_forge` has no `slow-wave` case, so the first poll returns in about a second and the assertion `elapsed >= 8` fails.
History: commit 388d56c6 (merge of upstream) had the cases and upstream's atomic `clock_bump`.
Commit 7faca578 (merge of origin/main) resolved the conflicted block in favor of the fork's older mkdir-lock `advance_clock` and so removed the two `slow-wave` lines and upstream's single-caller `reserve:'api repos/o/r/issues/9'` narrowing.
The failure reproduces locally in about 100 seconds.

**Decision**: Restore the fake-forge block exactly as it stood at 388d56c6 (upstream's version).

**Rationale**:
The test and `bin/fm-contributions.sh` at HEAD are the upstream pair, so the fixture that pairs with them is upstream's.
The fork's lock fixed a lost-update race that only exists when several callers bump the clock; upstream narrowed `reserve` to one caller per wave and publishes every bump by rename, which removes the race at its source.

**Alternatives considered**:
Keep the fork's `advance_clock` and add only the two `slow-wave` lines (leaves the `reserve` semantics diverged from the upstream test it pairs with; rejected).
Lower the `elapsed >= 8` assertion (forbidden by FR-010).

**Risk**: The shard 7 clock race the fork fixed on 2026-10-06 must stay fixed; verify with repeated parallel runs of the file.

## R3 - Calm Pi fixtures missing the policy module (serial 6 and serial 9)

**Evidence**:
`.pi/extensions/lib/fm-calm-visibility.ts` imports `./fm-calm-visibility-policy.ts`, which is a symlink to `.claude/mods/firstmate-calm/lib/fm-calm-visibility.ts` (added by the OMP Calm work).
Fixtures in `tests/fm-calm-pi-extension.test.sh` and the live guard `tests/fm-calm-pi-queue-retention-live-e2e.test.sh` copy only `fm-calm-visibility.ts`.
Node then fails with `ERR_MODULE_NOT_FOUND` for `fm-calm-visibility-policy.ts` (serial 6) and Pi fails to load the probe extension (serial 9).
Both reproduce locally; the file-level failure appears in every fork CI run since the OMP merge.
Sites that already copy the pair: all other cases in the same file and `tests/fm-pi-branch-responsiveness-live-e2e.test.sh`.
Sites that do not: the `queued-operational-rows` fixture, the `queued-escape` project, and the live guard.

**Decision**: Add the missing policy-module copy at each site, using the same `SHARED_VISIBILITY` variable the file already defines.

**Rationale**:
This is the established convention in the same file and a fixture defect, not a production defect: the symlink resolves inside the repository checkout.
No production script copies `.pi/extensions` without following symlinks.

**Alternatives considered**:
Make the Pi visibility module self-contained (duplicates the shared policy and undoes the OMP work; rejected).
A shared copy helper for all fifteen sites (larger refactor than the failure justifies; deferred as follow-up).

**Risk**: With the module error gone, later cases may expose failures against Pi 1.3.0 that the module error hid; run the whole file against 1.2.0 and 1.3.0.

## R4 - Wake-drain interruption flake (serial 6)

**Evidence**:
One failure in four recent main runs (run 38557743360) with this log signature: `fm-wake-lib.sh: trap: line 2: unexpected EOF while looking for matching ')'`, then the drain printing its acknowledgement hint, then `pre-commit interruption unexpectedly succeeded`.
The other serial 6 runs did not fail this case.
It passes locally on bash 5.3 (about 84 runs) and on bash 5.2.21 in a container (120 runs at the test's own timing).
A fine-grained fuzz of TERM timing after the recovery marker appears, under bash 5.2.21 (Ubuntu 24.04, the CI shell), reproduced the full signature once in 931 runs: TERM was sent about one millisecond after the marker became visible, bash printed the trap parse error, `exit 143` never ran, and the drain completed with status 0.
The parse error text means bash evaluated the trap string while a command-substitution parse was in progress, which is the same class of bash 5.2 fault the repository already documents for a CHLD trap in `fm-wake-lib.sh`.
The inner mechanism is inferred from that text and is not proven; what is observed is that the loss needs TERM to land between the marker write and the delay, a span that forks command substitutions.
The test intends to interrupt the drain at its serialized read boundary (its own failure message says so) but detects that boundary only as "lock held and marker pending", which is true well before the boundary.

**Decision**: Make the test signal the drain only once the drain is parked in its test delay (it has a `sleep` child), and bound and name that wait.

**Rationale**:
A bash process blocked on a foreground child defers the trap until the child exits, so TERM at that point cannot hit a parse in progress.
The boundary the test names is the delay; waiting for it is the faithful reading of the test.
The production drain needs no change: the fault is in bash 5.2 trap handling and the repository already documents avoiding it for CHLD.

**Alternatives considered**:
Retry the case on unexpected success (masks the cause; rejected).
Add a readiness file written by the drain's test hook (puts more test-only code in the production script; the child-process check needs none).
Replace the TERM trap string with a function (the same parser state would still apply; rejected).

**Portable detection**: `ps -A -o ppid= -o comm=` works on Linux and macOS; `comm` may be a full path on macOS, so match the basename.

## R5 - Verification plan

Run each named test file against Pi 1.2.0 and 1.3.0 scratch installs and the machine's Pi.
Run the interruption case 1500 times under bash 5.2.21 with randomized TERM timing before and after.
Run `fm-contributions.test.sh` repeatedly in parallel for the clock race.
Run `bin/fm-lint.sh` and `bin/fm-test-run.sh --check-coverage`.
