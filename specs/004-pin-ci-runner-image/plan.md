# Implementation Plan: Pin the CI Runner Image

**Branch**: `fm/firstmate-main-ci-red` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

Pin every Linux job in `.github/workflows/ci.yml` to `ubuntu-24.04`, guard the pin with a contract test in the existing workflow test, update the one documentation line that names the image, and add the missing field to the Calm Pi test's fake Pi host.
This is an environment correction plus a fixture correction, so no production script changes.

## Technical Context

**Language/Version**: Bash tests under `tests/`, GitHub Actions YAML, Ruby (already required by the workflow test) to parse YAML.
**Testing**: `bin/fm-test-run.sh tests/fm-ci-workflow.test.sh`, `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh`, `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`.
**Target Platform**: GitHub-hosted `ubuntu-24.04` and `macos-latest`.
**Constraints**: Assertions are never weakened, skipped, or deleted; each sentence in tracked Markdown sits on its own line; no em dash.

## Constitution Check

The project constitution file is the unfilled template, so the TDD rule in `spec-kit-workflow` governs: every behavior change starts from a failing test, and tests are never weakened.
The pin is an environment correction: its guard test is written first and observed red.
The fixture correction is driven by the existing red run of the Calm Pi test against Pi 1.5.2.

## Design

### Runner pin (FR-001, FR-002, FR-003, FR-004)

- Replace `runs-on: ubuntu-latest` with `runs-on: ubuntu-24.04` on the eight Linux jobs of `ci.yml` (lint, coverage guard, parallel 1 and 2, serial shards, Herdr, timing aggregate, invariants).
- Add one comment above `jobs:` that states the reason (the floating label moved to 26.04, whose Rust coreutils behaves differently from GNU), the evidence pointer (this feature's spec), and the condition for moving the pin (the follow-up work in the spec's out-of-scope list has landed).
- Extend `tests/fm-ci-workflow.test.sh` with `test_linux_jobs_pin_a_runner_image`: parse the YAML, collect each job whose `runs-on` names an `ubuntu` label, and fail naming every job whose label is not a pinned `ubuntu-NN.NN`.
  The macOS job and any non-Ubuntu label are ignored.
- Change `docs/fm-test-portable-shards.md` line 8 to name `ubuntu-24.04`.
- Leave `no-mistakes-required.yml` unchanged: its one job does not depend on the userland.

### Fake Pi host (FR-005)

- Add `pendingBashComponents: []` beside the other fields of `makeHost` in `tests/fm-calm-pi-extension.test.sh`.

## Alternatives Considered

- Install GNU coreutils on every 26.04 job (`coreutils-from-gnu`): keeps the newer image but adds about 25 seconds of package swap to nineteen jobs and still tests a userland no Ubuntu 26.04 user runs.
- Harden the suite and the product for uutils now: correct long term, but it changes lock protocols and is a design decision, so it is follow-up work.
- Pin Pi and TypeScript in CI: not needed for green and removes the early Pi drift signal, so it stays out.

## Risks

- `ubuntu-24.04` is retired by GitHub in the future; the guard test names the pinned shape, not the version, so moving the pin is one reviewed change.
- Failures that were not reproduced (tmux smoke, remote lifecycle watcher bound, Herdr presentation recovery) may recur on the new image; they are reported with their evidence rather than hidden.
