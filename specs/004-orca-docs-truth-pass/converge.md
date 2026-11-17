# Convergence Report: Orca Documentation Truth Pass

**Outcome**: Converged within the feature scope, with no task appended and three follow-ups recorded for other slices.

## Scope checked

- `spec.md` functional requirements FR-001 through FR-021 and success criteria SC-001 through SC-006.
- User stories US1 through US4 and all 18 acceptance scenarios.
- `plan.md` design decisions D1 through D5 and the five surfaces it names.
- `tasks.md` T001 through T026.

## Approvals

The supervising firstmate's instructions fixed the problem, the five surfaces, and the three operating decisions, and were treated as the approval of the specification, plan, and task list, because a worker does not address the captain (`research.md` R8).
Merge authority stays with the captain.

## Findings

No missing, partial, contradicting, or unrequested work remains in the specified scope, so `tasks.md` was left as it is.

- FR-001, FR-002, FR-008: `docs/orca-backend.md` describes macOS through the app and Linux through the headless runtime, keeps the macOS app and Homebrew facts labeled as macOS, names the `PATH` requirement, and points headless operators at `bin/fm-peek.sh`.
- FR-003, FR-004: it says Orca reports a version and capability list, that Firstmate gates on readiness alone, and that Orca exposes native agent state which Firstmate does not use.
- FR-005, FR-012, FR-013: both documents say the adapter delivers Enter and Ctrl+C and does not deliver Escape or Ctrl+U, attribute it to the adapter, and mark the passthrough not exercised live; the exit and relaunch refusal and the capability matrix row are unchanged.
- FR-006, FR-007, FR-014: the documents and the trust script comment say Orca's worktrees are linked and accepted by the trust check, and that Orca returns `result.startupTerminal`, which the adapter does not adopt.
- FR-009, FR-010, FR-011: the new "Operating posture" section states the Herdr placement, the folder-registered project rule with the per-task backend override, and the away and quiet mode refusal.
- FR-015, FR-016: the verification record keeps the macOS 1.4.116 evidence and gains a dated Linux headless 1.4.261 entry with commands, observed fields, and an explicit not-exercised list.
- FR-017: the recovery skill gained one line (`analyze.md` I2 records its placement).
- FR-018, FR-021: the only non-prose change is comment text in `bin/fm-claude-trust.sh` plus 14 audience inventory entries, and no test, adapter, control library, or other document changed (`claim-audit.sh A15`, `U32`).
- FR-019: the added Markdown lines follow one sentence per line with no em dash (`claim-audit.sh A16`).
- FR-020: every changed claim was re-read against the evaluation report's appendix and the code it describes, below.

### Re-read of the changed claims

| Ledger rows | Evidence checked | Result |
| --- | --- | --- |
| L1, L2, L7, L8 | `orca --version`, `orca status --json` (`appVersion`, `installMode=unsupported-headless-serve`, `desktopWindowStatus=blocked`, capability list), `command -v orca` empty in a non-Orca shell, shim present under `~/.orca/cli/bin`, appendix item on `ORCA_CLI_BIN_DIR` | supported |
| L3 | appendix `terminal wait --for tui-idle`, `worktree ps`, `terminal show`; busy lib uses harness hooks | supported |
| L4 | `fm_backend_orca_send_key` handles `C-c` and `Enter` only; `orca terminal send --help` states verbatim control bytes | supported, passthrough marked not exercised |
| L5 | evaluation report lead 2 and the verification record | supported, marked Linux only |
| L6 | appendix `worktree create` shape; `fm_backend_orca_json_get` takes the worktree terminal only from `result.terminal`; `liveTerminalCount=2` | supported; the shape itself is read from the runtime bundle, marked so in the verification record |
| L9, L10, L11 | the captain's recorded decisions; `orca repo list --json` shows one `kind=folder` repository; `repo add --help` says `--kind folder` is an ordinary directory; the adapter has no `kind` check; the away daemon supports tmux and Herdr only | supported; the reason for the folder rule is worded from Orca's own help |
| L12 | `fm_control_backend_supports_key`, `fm_control_backend_state_verified`, `fm-spawn.sh` relaunch refusal | supported; Grok's Ctrl+C interrupt is named as the one exception in the Orca document |
| L13 | the commands above | supported |

One claim was tightened during the re-read: the adapter takes a worktree's terminal handle only from `result.terminal`, and a terminal-create handle from `result.terminal` or the root terminal object.

### Documentation change review

| Surface | Audience | Owner of the fact | Safety fact that removal could lose | Result |
| --- | --- | --- | --- | --- |
| `docs/orca-backend.md` | operator-current | operating posture and limits | the trust check still refusing a non-linked path is kept in the Active limits bullet; the macOS app and Homebrew facts are kept and labeled | two version-scoped statements remain, each pointing to the verification record at the end of the page |
| `docs/agent-control.md` | maintainer-architecture | control-plane refusals | the exit and relaunch refusal and the matrix row are unchanged | one sentence replaced |
| `docs/verification/runtime-backends.md` | maintainer-verification | dated evidence | the macOS 1.4.116 entry is kept in full | Linux entry added with commands, fields, and the not-exercised list |
| `.agents/skills/stuck-crewmate-recovery/SKILL.md` | agent-runtime | recovery steps | none removed | one line added |
| `bin/fm-claude-trust.sh` | code comment | structural-test rationale | the path-prefix rationale and the primary-checkout reasoning are kept | Orca sentences replaced |

## Verification evidence

- `claim-audit.sh all` -> 68 checks, 0 failed; red on the base documents with 55 of 68 failing (`tdd/cycle-log.md`).
- Thirteen deliberate mutants across six files, twelve caught and one equivalent (`tdd/verification.md`).
- `tests/fm-documentation-audiences.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-backend-orca.test.sh`, `tests/fm-backend.test.sh`, `tests/fm-control.test.sh`: 5 passed, 0 failed; the first two re-run on the final tree, 2 passed, 0 failed.
- `bin/fm-doc-audience-check.sh`: ok, 225 surfaces, 761 local links.
- `bin/fm-lint.sh` and `bin/fm-lint.sh bin/fm-claude-trust.sh` with ShellCheck 0.11.0 and actionlint 1.7.12: exit 0.
- `git diff af20b2c9 --stat -- tests`: empty.
- `tdd/verification.md` verdict: PASS_WITH_GAPS.

## Remaining delivery work

- The delivery pipeline's review, tests, and CI run on the pull request.
- Reviewer sign-off on `checklist.md` items CHK001 to CHK021 stays with the reviewer.
- Spec-Kit constitution: `.specify/memory/constitution.md` is still the unfilled template, so the TDD principle could not be applied to it without the captain approving its wording; the TDD gate was applied as the working rule.

## Risk

- Residual: the claims about the linked worktree shape, the native agent-state surfaces, and the worktree-creation response rest on read-only observations and a runtime bundle on one Linux host with Orca 1.4.261, and are marked as such; a later Orca release can change them.
- Residual: the Escape and Ctrl+U passthrough and the folder-repository behavior are not exercised live; the documents say so.
- Residual: the full repository suite was not run locally; CI is the full-suite evidence.
- Observed, out of scope, recorded as follow-up for other slices:
  - `bin/backends/orca.sh` (header, line 4) and `bin/fm-control-lib.sh` (lines 273 to 275) still attribute the missing Escape to Orca's terminal API, which the corrected documents no longer say.
  - `docs/architecture.md` (line 265) still says Orca exposes no native busy primitive at all.
  - The install hint in `bin/fm-bootstrap.sh` still says `brew install orca` for every platform, and the Orca document's Linux `PATH` sentence will need revising when CLI discovery changes.
