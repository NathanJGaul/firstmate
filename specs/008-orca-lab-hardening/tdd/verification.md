# TDD verification: Orca Live Lab Hardening

Verdict: PASS.

## Test-first evidence

The new `L1` cases and the changed `A5` fake CLI were written before any change to `tests/orca-lab-safety.sh`.
The first run failed at `L1: the CLI runs with the lab home, not the operator's HOME`, recorded in `cycle-log.md`.

## Deliberate mutants

No mutation tool is installed (`tdd-profile.md`), so ten deliberate mutants of `tests/orca-lab-safety.sh` were applied one at a time to a full-tree scratch copy and the guard test was run against each.
The first attempt used a partial copy whose test root came out empty, so every result from it was void and was discarded; the table below is the rerun on a full copy.

| Mutant | Result | First failing assertion |
| --- | --- | --- |
| drop the `HOME` export from the launcher | killed | the CLI runs with the lab home |
| skip home validation in the launcher write | killed | a missing home argument must be refused |
| drop the agent-config pointer `unset` | killed | `CODEX_HOME` is removed |
| operator-HOME rule disabled | survived at first, killed after a test change | the refusal names the operator's HOME rule |
| agent config directories unprotected | killed | `~/.claude` must be refused |
| agent-binary check disabled | killed | a PATH reaching `claude` must be refused |
| relative or empty PATH entry accepted | killed | `:/usr/bin` must be refused |
| runtime PATH inherits the caller's PATH | killed | the runtime PATH is the lab bin plus `/usr/bin:/bin` |
| config-path prefix check loosened | killed | a sibling directory sharing the home's name prefix |
| empty config-path report accepted | killed | a report naming no config path must be refused |

The survivor was real: a fixture HOME always holds files, so the freshness rule and the protected-path rule refused it and hid the operator-HOME rule.
The test now uses an empty operator HOME and asserts which rule refused, and the mutant is killed.
That rule still overlaps the protected-path rule for behavior, since the protected agent directories lie under the operator HOME, so only the refusal message tells them apart.

## Acceptance coverage

| Criterion | Test |
| --- | --- |
| US1.1, US1.5 | `L1` launcher case |
| US1.2-1.4 | `L1` refused-home cases, including the empty operator HOME and an unset HOME |
| US2.1-2.3 | `L1` PATH cases |
| US3.1 | `L1` config-path cases, live `H1` |
| US4 | `docs/verification/runtime-backends.md`, `bin/fm-doc-audience-check.sh` |

Live: `passed=44 findings=6` on 2026-11-19 against Orca 1.4.261, with `ok - H1` and the runtime booting on the restricted PATH.
