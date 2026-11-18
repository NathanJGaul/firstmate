# Quality Checklist: Orca Adapter Hygiene

Completed after implementation, against the code on the branch.

## Requirements coverage

- [x] FR-001 the kind is read from `repo show` and `folder` is refused (`fm_backend_orca_repo_ensure`, tests U1-U3).
- [x] FR-002 the refusal names the project, says Orca holds it as a folder, and names `--backend` (U3, A1).
- [x] FR-003 the refusal logs no registration, worktree, or terminal call (U3 asserts `repo show` is the only call; A1 asserts the absence of each mutating verb).
- [x] FR-004 `git` and kindless registrations behave as before (U4, plus the existing spawn cases whose fixtures carry no kind).
- [x] FR-005 order is `PATH`, `$ORCA_CLI_BIN_DIR`, `~/.orca/cli/bin`, executable regular file only (U5-U9).
- [x] FR-006 a CLI found off `PATH` serves every later call in the entry point (U6, U11, A2, and the mutant recorded in the cycle log).
- [x] FR-007 the absent-CLI refusal names all three locations and the fix and calls nothing (U10).
- [x] FR-008 bootstrap resolves the CLI through the adapter's check (A3).
- [x] FR-009 the hint is Homebrew on macOS and shim guidance elsewhere (A4, A5).

## Safety and scope

- [x] No test calls a live Orca: every case uses a fake `orca`, and every case that depends on discovery pins `HOME` and `ORCA_CLI_BIN_DIR`.
- [x] The operator's Orca registration is never written: the new code adds no `repo` mutation, and the folder path returns before `repo add`.
- [x] No change to teardown, spawn flow, or the Orca primitives beyond the two functions and one added call named in the plan.
- [x] No dependency added.

## Documentation and lint

- [x] `docs/orca-backend.md` states the resolution order and the folder refusal once, in its owner section.
- [x] The new spec files are classified in `docs/documentation-audiences.json`.
- [x] `bin/fm-doc-audience-check.sh` and `bin/fm-lint.sh` pass (see `tdd/verification.md`).

## Known limits

- What a real Orca does on `worktree create` for a folder repository is not proven live; the refusal is derived from Orca's own help text and the evaluation report, and the live lab step stays open.
- The `repo show` JSON shape for `kind` is read from the repository object or the result root; neither is proven against a live Orca here.
- `docs/verification/runtime-backends.md` is not updated because this work produced no live evidence to record.
