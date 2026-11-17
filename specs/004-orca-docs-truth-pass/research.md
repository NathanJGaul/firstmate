# Research: Orca Documentation Truth Pass

## R1 - Evidence base for each changed claim

Decision: Treat the 2026-11-17 evaluation report's appendix of Orca 1.4.261 facts, the code each statement describes, and read-only Orca commands run during this task as the only evidence for a changed claim.
Rationale: The captain's ask names the report and its appendix as the source, and the repository's verification rules require a dated, versioned record of what was actually observed.
Alternatives considered: Re-running the full evaluation was rejected because it would create Orca worktrees and terminals the task is fenced off from, and the report already holds those observations.

Confirmed again in this task with read-only commands on the same host:

- `orca --version` prints `1.4.261`.
- `orca status --json` reports `runtime.state=ready`, `runtime.reachable=true`, `runtime.appVersion=1.4.261`, `remoteUpdateSupport.installMode=unsupported-headless-serve`, `app.desktopWindowStatus=blocked`, and a capability list.
- `orca repo list --json` reports the firstmate home as `kind=folder` and the pricing-sheet clone as `kind=git`.
- `orca terminal send --help` says that without `--enter` the text is written to the PTY verbatim so control bytes pass through, and that `--wait-submit` and `--retry-request` exist.
- `command -v orca` is empty in this worker's shell, while the CLI shim exists under `~/.orca/cli/bin`.

Taken from the report and not re-run, because re-running would touch worktrees or terminals this task did not create:

- Orca-created worktrees are linked git worktrees (`git rev-parse --git-dir` names `<project>/.git/worktrees/<name>`, `--git-common-dir` names `<project>/.git`), and Claude trust entries exist for them.
- `worktree create` returns `result.worktree` and `result.startupTerminal` with no `result.terminal`, and each task ends with two live terminals.
- `worktree ps`, `terminal show`, and `terminal wait` expose native agent state.

## R2 - How to word the key-delivery fact

Decision: State that the adapter delivers Enter and Ctrl+C and does not deliver Escape or Ctrl+U today, attribute that to the adapter, and say the control-byte passthrough is documented in Orca's help text but has not been exercised on a live terminal.
Rationale: The code and the capability matrix both say Escape and Ctrl+U are undeliverable, and that stays true until the adapter changes; only the stated reason ("Orca has no such primitive") is wrong.
Alternatives considered: Saying Escape works on Orca was rejected as unproven.
Keeping "Escape is the only missing key" was rejected because the matrix and the control library show Ctrl+U missing too.

## R3 - Where the three captain decisions live

Decision: State each decision once, in a new short "Operating posture" section of `docs/orca-backend.md`, and point at it from the other surfaces.
Rationale: The one-owner rule says a contract is stated in full once; the Orca backend document is the page an operator reads to choose a backend.
Alternatives considered: Repeating the decisions in `docs/agent-control.md` and the skill was rejected as duplication that drifts.
Putting them in `AGENTS.md` was rejected because they matter only when choosing the Orca backend.

## R4 - The startup terminal

Decision: Record in the Orca backend document that Orca returns the first terminal as `result.startupTerminal`, that the adapter does not adopt it today, and that firstmate therefore creates its own terminal.
Rationale: The old "only `result.terminal` is verified" claim is one of the six stale statements and must be replaced by what the runtime actually returns.
Alternatives considered: Omitting the spare-terminal consequence was rejected because it hides why each Orca task shows two terminals.
Documenting the leftover Orca-made branch and the CLI install hint was rejected as belonging to the slices that fix them, though the Linux prerequisite sentence about `PATH` is kept because the macOS-only setup text cannot be corrected without saying how Linux operators reach the CLI.

## R5 - Test strategy for a prose-only change

Decision: Use a claim audit, `tdd/claim-audit.sh`, as the failing-first check, commit it with the feature before the edits so its red run is in git history, run it green after them, record both runs, and keep the repository tests unchanged.
Rationale: There is no behavior to drive.
The repository's documentation check already validates classification, links, and owner pointers and deliberately does not keyword-lint prose.
A phrase pin registered in `tests/` would break on every harmless rewording and would assert source text, which the repository's test rules forbid for implementation files.
The audit therefore stays under the feature's `tdd/` evidence directory, is not run by CI, and records a point-in-time check of this one change.
Alternatives considered: A new `tests/` file pinning phrases was rejected for those reasons and because a new file would need runner and lane registration.
A scratch audit outside the repository was rejected because a cold audit could not then see test-first evidence in git history.
Extending `tests/fm-documentation-audiences.test.sh` was rejected because it is structural by design.

## R6 - The script comment

Decision: Edit only the comment lines in `bin/fm-claude-trust.sh`, and prove it with a diff filter showing no non-comment line changed, plus the unchanged trust suite.
Rationale: The comment is a claim about Orca that is now false, but the script's behavior is correct and must not move.
Alternatives considered: Leaving the comment and correcting only the documents was rejected because the stale text names a "macOS-only, not installed" Orca that misleads readers of the script.

## R7 - Code comments left for their own slices

Decision: Leave the header comment of `bin/backends/orca.sh` and the key-support comment in `bin/fm-control-lib.sh`, which still attribute the missing Escape to Orca's API, for the slice that changes key delivery, and report them as follow-up.
Rationale: The captain's ask lists the surfaces to change, other slices are editing the adapter concurrently, and FR-021 keeps this slice out of those files.
Alternatives considered: Fixing them here was rejected to avoid rebase conflicts in the most edited file of the plan and to keep "no code behavior" trivially checkable.

## R8 - Spec-Kit approvals

Decision: Treat the supervising firstmate's brief, which fixes the problem, the five surfaces, and the three decisions, as the approval of the specification, plan, and task list, and record that in the convergence record.
Rationale: A worker never addresses the captain, and the brief states the captain's approved scope.
Alternatives considered: Stopping for a decision after each artifact was rejected because nothing in the scope is open.
