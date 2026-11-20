# Implementation Plan: Pinned Lint Tools Visible to the No-Mistakes Pipeline

**Branch**: `fm/firstmate-pipeline-linter-provisioning` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-lint-tools-provisioning/spec.md`

## Summary

A small sourced library owns the managed pinned-tool directory and the lookup order (search path, then that directory).
`bin/fm-lint.sh` and `bin/fm-lint-workflows.sh` resolve their tool through it, and both pinned installers default their destination to it.
A new `bin/fm-install-lint-tools.sh` provisions both tools there idempotently and offers `--check`.
No daemon change is needed, because the daemon's own search path is never consulted for the managed directory: the lint entry points look there themselves.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell

**Primary Dependencies**: none new; the existing checksum-verified installers

**Storage**: `${FM_LINT_TOOLS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/firstmate/lint-tools}`, holding `shellcheck` and `actionlint`

**Testing**: new `tests/fm-lint-tools.test.sh`; extended `tests/fm-lint.test.sh` and `tests/fm-lint-workflows.test.sh`; each with `bin/fm-test-run.sh <file>`

**Target Platform**: Linux and macOS, matching the installers

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through the pinned lint; version enforcement unchanged; no daemon interaction; no new network behavior in lint itself

## Constitution Check

The TDD principle in `.specify/memory/tdd-profile.md` applies: each behavior is driven by a test that failed first and recorded in `tdd/cycle-log.md`.
The constitution file is still the unfilled template, so no further gate applies.

## Design

### D1: Where the pipeline's agents run, and why the tools are invisible

The no-mistakes daemon runs as the operator's user with the operator's home directory and a fixed search path of user and system directories, with no version-manager shims.
`commands.lint` is `bin/fm-lint.sh`, which looked up ShellCheck and actionlint on that search path only.
Workers get the tools from their own interactive environment or from CI's per-job install, neither of which the daemon shares.
The daemon's environment is not changed.
The lint entry points reach a directory the daemon can already read because it shares the home directory.

### D2: One owner for location and lookup

`bin/fm-lint-tools-lib.sh` defines `fm_lint_tools_dir` (override, else XDG cache default, else failure when no home is derivable) and `fm_lint_tool_resolve <name>` (search path first, then an executable file in the managed directory).
Search-path-first keeps CI, which stages tools on the path, and every existing stub-based test unchanged.
The version check in each entry point is untouched, so a wrong build in either location is refused.

### D3: Installers

Both installers accept no destination and then use `fm_lint_tools_dir`.
Explicit-destination behavior, checksum pins, retries, and platform tables are unchanged.

### D4: Provisioning command

`bin/fm-install-lint-tools.sh [--check]` reads each pin from the entry points' `--required-version`, probes the managed binary's own version, skips a tool already at its pin, otherwise runs that tool's installer, then re-probes.
`--check` probes only and exits 1 when either tool is missing or off-pin.

### D5: Messages

Both entry points' missing-tool message names `bin/fm-install-lint-tools.sh` and the managed directory, and still names the pinned installer.

### D6: Test isolation

Tests that assert a missing tool set `FM_LINT_TOOLS_DIR` to an empty directory so a provisioned developer machine cannot satisfy them.
The new suite never touches the real home: every case sets `FM_LINT_TOOLS_DIR` or a temporary `HOME`.
The clean-environment proof runs the real entry points under `env -i` with a daemon-like search path built from symlinks to the system tools the lint needs, excluding ShellCheck and actionlint.

### D7: Documentation

`CONTRIBUTING.md` (lint paragraph) and `docs/configuration.md` (gate defaults) describe the managed directory, the provisioning command, and why the pipeline needs it, each by pointing at the script headers for mechanics.

## Out of scope

- Any change to the shared daemon, its configuration, or its environment.
- Running the provisioning on the operator machine (an operator step, written in the PR body).
- Auto-download from inside lint.
