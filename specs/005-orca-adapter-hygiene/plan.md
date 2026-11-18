# Implementation Plan: Orca Adapter Hygiene

**Branch**: `fm/firstmate-orca-adapter-hygiene` | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-orca-adapter-hygiene/spec.md`

## Summary

Four small edits, each proven against fake Orca fixtures.

1. `bin/backends/orca.sh` `fm_backend_orca_json_get` gains a `repo-kind` field, reading `kind` from the same repository object `repo-id` reads.
   `fm_backend_orca_repo_ensure` reads it from the `repo show` result and refuses `folder` before `repo add` or anything else.
2. `fm_backend_orca_tool_check` resolves the CLI: `PATH`, then `$ORCA_CLI_BIN_DIR`, then `~/.orca/cli/bin`.
   A hit off `PATH` is prepended to the calling shell's `PATH`, so every following `orca` call in that shell finds it.
   `fm_backend_orca_worktree_create` calls the check itself, because its repository step runs in a command substitution whose `PATH` change would not reach the parent shell.
3. `bin/fm-backend.sh` `fm_backend_required_tool_available` routes `orca:orca` through the adapter's tool check, as it already does for cmux, so bootstrap and the adapter share one resolution.
4. `bin/fm-bootstrap.sh` `install_cmd` splits `orca` out of the shared Homebrew line: Homebrew on macOS, the Orca-installed CLI shim guidance elsewhere.

## Technical Context

**Language/Version**: Bash 4+ with an embedded Node snippet for JSON, as the adapter already is

**Primary Dependencies**: the `orca` CLI (1.4.261 observed), `node`; no new dependency

**Storage**: none

**Testing**: colocated `tests/fm-backend-orca.test.sh` and `tests/fm-bootstrap.test.sh`, run with `bin/fm-test-run.sh <file>`

**Target Platform**: Linux and macOS hosts

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; no change to the operator's Orca registration; no live Orca call from any test

## Constitution Check

`.specify/memory/constitution.md` is the unratified template, so it carries no gate.
The workflow's TDD rules apply: every behavior starts from a test seen failing, recorded in `tdd/cycle-log.md`.
Result: no violation.

## Decisions

- **D1 - PATH prepend, not a wrapper function.**
  Every adapter function already calls the tool check first and then runs a bare `orca`.
  Prepending the resolved directory keeps those call sites unchanged and keeps `command -v orca` truthful for later readers.
  The alternative, a shell function named `orca`, would shadow the real command and change `command -v` semantics for sourcing scripts.
- **D2 - Check at `worktree_create`.**
  The only bare `orca` call that follows a tool check made inside a command substitution is `worktree create`, so it gets its own check.
- **D3 - Share the resolution with bootstrap through `fm-backend.sh`.**
  The cmux case already routes through its adapter there.
  Doing the same for orca avoids a second copy of the three-location rule.
- **D4 - Kind check only on the existing registration.**
  `repo add` is how a new project is registered today and stays unchanged; refusing after our own add would leave a registration behind.

## Project Structure

```text
specs/005-orca-adapter-hygiene/
  spec.md plan.md tasks.md checklist.md analyze.md converge.md
  tdd/test-list.md tdd/cycle-log.md tdd/verification.md
bin/backends/orca.sh
bin/fm-backend.sh
bin/fm-bootstrap.sh
tests/fm-backend-orca.test.sh
tests/fm-bootstrap.test.sh
docs/orca-backend.md
```
