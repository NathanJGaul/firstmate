---
feature: 004-pin-ci-runner-image
verified_from: cold context
verdict: pass-with-stated-limits
---

# TDD Verification: Pin the CI Runner Image

## Test-first evidence

`git log --oneline` for the feature, oldest first:

```
f8e859a5 docs(spec): specify pinning the CI runner image
d1d58ee5 test(ci): require every Linux job to pin its runner image
cd2ac17c ci: pin Linux jobs to ubuntu-24.04
7055ba40 test(calm): give the fake Pi host the pending bash list Pi 1.5 reads
```

The guard test (`d1d58ee5`) precedes the pin (`cd2ac17c`).
The fixture commit is a one-field correction whose red run was observed on the unchanged tree before the commit; see `tdd/cycle-log.md` cycle 2.

## Red-phase evidence

- Cycle 1 failed for the stated reason: eight jobs named with `ubuntu-latest`, none for any other reason.
- Cycle 2 failed with the exact hosted error `TypeError: this.pendingBashComponents is not iterable`, reproduced in an Ubuntu 26.04 container and natively.

## Test-smell rubric

- The guard reads parsed YAML values, the same technique as the file's neighbors, and asserts no source bytes.
- It cannot pass vacuously: it fails when the workflow carries no Linux job.
- It names every offending job rather than stopping at the first.
- The fixture change adds a property to a stand-in; no assertion in the Calm Pi file was edited.
- No test was skipped, filtered, weakened, or deleted.

## Test strength (deliberate mutants; no mutation tool is installed)

| Mutant | Test | Result |
| --- | --- | --- |
| `tests-herdr` runs on `ubuntu-latest` | `tests/fm-ci-workflow.test.sh` | killed: exit 1 naming `tests-herdr: ubuntu-latest` |
| every Linux label replaced by a non-Ubuntu label so no Linux job exists | `tests/fm-ci-workflow.test.sh` | killed: exit 1 with `no Linux job found, so the pin guard would pass vacuously` |
| `pendingBashComponents` removed from the fake host | `tests/fm-calm-pi-extension.test.sh` with Pi 1.5.2 | killed: exit 1 with the `TypeError` |

## Acceptance-criteria coverage

| Criterion | Evidence |
| --- | --- |
| US1.1, FR-001 | `ci.yml` shows eight `ubuntu-24.04` labels; guard green |
| US1.2, FR-002 | red at `d1d58ee5`; mutant killed |
| US1.3 | macOS job unnamed in the red output |
| US1.4, FR-004 | `docs/fm-test-portable-shards.md` line 8; `bin/fm-doc-audience-check.sh` ok |
| US2.1, FR-005 | native run, Pi 1.5.2 with Chromium: exit 0, no skip |
| US2.2 | native run, Pi 1.3.0: exit 0 |
| FR-003 | comment above `jobs:` (prose; review) |
| FR-006 | `git diff af20b2c9..HEAD -- tests` adds a guard and one field only |

## Suite and gate results

| Gate | Result |
| --- | --- |
| `bin/fm-test-run.sh tests/fm-ci-workflow.test.sh` | exit 0, all nine cases |
| `bin/fm-lint.sh` with ShellCheck 0.11.0 and actionlint 1.7.12 | clean |
| full-mode ShellCheck on both changed tests (`CI=true bin/fm-lint.sh <paths>`) | clean |
| `bin/fm-doc-audience-check.sh` | `ok surfaces=211 local_links=755` |

## Ubuntu 24.04 container (the pinned image's userland)

Container: `ubuntu:24.04`, Bash 5.2.21, GNU coreutils 9.4, tmux 3.4, Node 22.23.4, Pi 1.5.2, TypeScript 5.9.3.
Scripts that failed on hosted Ubuntu 26.04, run alone:

| Script | Result |
| --- | --- |
| `tests/fm-pi-primary-types.test.sh` (with `--fail-on-gate-skip`) | pass |
| `tests/fm-backend-herdr.test.sh` | pass |
| `tests/fm-control-herdr-smoke.test.sh` (real Herdr 0.7.4) | pass |
| `tests/fm-backend-tmux-smoke.test.sh` | pass |
| `tests/fm-remote-transport-lanes.test.sh` | pass |

`tests/fm-supervision-host.test.sh` is inconclusive on this host: its first two runs failed inside a container with no init process (zombie children make `kill -0` checks lie), a third run with an init process passed 41 cases and then hit a bounded engine wait after 15 minutes because the maintainer host ran at load average 15 to 20.
`tests/fm-public-followup.test.sh` and `tests/fm-remote-secondmate-lifecycle-e2e.test.sh` take 7 to 8 minutes on hosted runners and were not rerun on 24.04 locally for the same reason.
Their hosted results on the pull request are the evidence.

## Verdict

Pass.
The two behaviors are test-driven and mutant-verified; the stated limit is that the hosted run, not this host, is the proof for the long timing-sensitive scripts.
