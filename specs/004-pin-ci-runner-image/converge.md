# Convergence: Pin the CI Runner Image

**Feature**: `004-pin-ci-runner-image` | **Date**: 2026-11-17

## Merge readiness

The change is committed, linted, and tested inside its branch.
Both acceptance behaviors have a red run, a green run, and a deliberate mutant that the test kills.
The hosted verdict on the delivery PR is the remaining evidence and is reported with the PR.

## Evidence

| Gate | Result |
| --- | --- |
| `tests/fm-ci-workflow.test.sh` | red at `d1d58ee5`, green at `cd2ac17c` |
| `tests/fm-calm-pi-extension.test.sh` against Pi 1.5.2 and 1.3.0 | red without the field, green with it |
| Previously failing scripts on an Ubuntu 24.04 container | recorded in `tdd/verification.md` |
| `bin/fm-lint.sh` (default and full-mode on changed tests) | clean |
| `bin/fm-doc-audience-check.sh` | `ok` |

## Risk

Low.
The workflow change only selects the image the jobs ran on until 2026-10-16 and that upstream has pinned since 2026-10-26.
The test change adds one property to a stand-in object and one guard that reads the parsed workflow.
No production script changed.

## Follow-ups worth shipping separately

- Port the upstream multicall-safe agent stand-ins (commit 329ad4ed) and run the two closed-standard-output tests through `bash`, so the suite is green on an Ubuntu 26.04 host.
- Decide how mkdir-based claims become exclusive on uutils hosts: `fm_remote_job_next_seq`, the remote job worker lock and claim, the AFK launch lock, and the busy-event lock.
- Move the runner pin forward once both land, and report the uutils `mkdir` behavior upstream to the uutils project.
- Watch the next hosted runs for the three unproven failures named in `analyze.md`.

## Not built, by instruction

- No pin of Pi or TypeScript in CI, so Pi drift stays visible.
- No change to the compliance workflow or the macOS job.
- No test skipped, quarantined, weakened, or deleted.
