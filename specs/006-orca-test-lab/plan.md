# Implementation Plan: Orca Live Test Lab

**Branch**: `fm/firstmate-orca-test-lab` | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-orca-test-lab/spec.md`

## Summary

Three new files plus registration and a verification record.

1. `tests/orca-lab-safety.sh` is a sourced library, in the style of `tests/cmux-test-safety.sh`.
   It owns every guard: environment validation, protected-path refusal, lab creation, launcher generation, runtime start and stop, the own-child proof, and the leftover scan.
2. `tests/fm-backend-orca-lab-guard.test.sh` is a portable test that sources the library and proves each refusal with fake runtime processes, no Orca installed.
3. `tests/fm-backend-orca-smoke.test.sh` is the opt-in live lane.
   It runs report assertions 1 to 10, records 11 as not run, then the Firstmate-level section, then the inventory.
4. `bin/fm-test-run.sh` classifies the lane in `live-harness-optin` and the guard test in the `orca` family.
5. `docs/verification/runtime-backends.md` gains a Linux headless 1.4.261 lab entry.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell, `jq` for JSON reads

**Primary Dependencies**: none new; the Orca headless runtime and its node binary, discovered from the command-line shim

**Storage**: a `mktemp -d` lab directory removed on exit

**Testing**: `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh`; the live lane with `FM_ORCA_LIVE_E2E=1 bin/fm-test-run.sh tests/fm-backend-orca-smoke.test.sh`

**Target Platform**: Linux for the live lane; the guard test runs wherever bash runs

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; the lane never touches `~/.orca`, `~/.orca-remote`, or the live runtime

**Scale/Scope**: three test files, one runner edit, one documentation edit

## Constitution Check

The constitution is the unfilled template, so the only gate is the TDD principle in `.specify/memory/tdd-profile.md`, applied to the guard library through `specs/006-orca-test-lab/tdd/`.
The live lane is itself the acceptance test and runs only against its own runtime.

## Design

### D1: The launcher pins the data directory

Orca's own command-line shim exports a fixed data directory unconditionally, so a caller's variable cannot redirect it.
The lab writes its own launcher that exports the lab data directory and runs the same node and CLI entry the real shim names, with every other `ORCA_*` variable and `NODE_OPTIONS` removed.
Because the launcher is first on `PATH`, Firstmate's adapter resolves it, and a forgotten variable cannot fall back to the operator's runtime.

### D2: The runtime is a direct child of the lane

The lab runs the bundled node binary on `orcad.js` directly, as the default `orca serve` path refuses outside an installed app.
Its home is the lab's own directory so default workspace roots and tool configuration never land in the operator's home, and the repository's worktree base path is also set to the lab.
The child id comes from `$!` of a `setsid` launch; the wrapper id and the runtime id differ, so the runtime id is read from the runtime record and then verified.

### D3: Own-child proof before every mutation

`orca_lab_assert_own_runtime` checks, in order: the record file lives in the lab data directory, its pid is a live process, that process's environment names the lab data directory, the pid is not the operator runtime's, and `status --json` reports the recorded runtime id.
The lane calls it before creating repositories, before every signal, and again after the restart.
Signals go only through `orca_lab_signal`, which re-proves the pid first.

### D4: Stop sequence

Stop sends SIGTERM to the proven runtime, waits, then proves and terminates the terminal-host process named in the lab's pid record (its socket path must lie in the lab data directory), then scans `/proc` for any process whose command line or environment names the lab directory.
A survivor is killed only after the same proof, and a survivor that cannot be proven fails the run loudly.

### D5: Protected paths

A candidate data directory is resolved with `cd -P`.
It is refused when it equals, contains, or lies inside the resolved `~/.orca` or `~/.orca-remote`, and when it equals `/` or `$HOME` or contains them (the parent case).
A caller-supplied directory must be absent or empty.

### D6: Observations are not passes

The lane has `ok` for hard assertions, `# observe:` for recorded shapes, `# finding:` for contradictions of a slice assumption, and `# not run:` with a reason.
Only `ok` lines count toward the pass total, and a lane that counted none fails.

### D7: Firstmate-level section

A lab firstmate home (`FM_HOME`) is built in the lab directory with the scratch repository registered as a project.
Spawn runs with `--backend orca --harness 'sh -c cat'`, then peek, send, crew state, teardown refusals on dirty and unlanded work, and a clean teardown, driving the real scripts.

### D8: Nightly workflow

Left as a documented follow-up: the runtime artifact source, license, and mirror are unknown, so a workflow could not be written to fail soft honestly.
