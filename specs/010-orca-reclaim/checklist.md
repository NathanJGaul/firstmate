# Quality Checklist: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

- [X] Every behavior test was seen failing for the right reason before its implementation (`tdd/cycle-log.md`).
- [X] `exit` and `relaunch` on Orca act only on `dead`, a locally proven `missing`, or an explicit close of an `alive` agent; `ambiguous`, `unverified`, `unreadable`, and a non-local runtime refuse and name the state (A1-A3, A8).
- [X] The close receipt is never trusted alone: the endpoint must read missing and no local process may carry the handle (A6, lab step A15).
- [X] The reclaim closes the dead terminal first, creates one terminal by the recorded worktree id, republishes `terminal=` atomically, and leaves exactly one live terminal (A5, A9, lab step A15).
- [X] No path calls `worktree rm` or closes by worktree; the worktree, branch, commits, and uncommitted changes are untouched (A4, A5, A7, A9, lab step A15).
- [X] The abort cleanup of a relaunch closes only a terminal the reclaim created and never removes a worktree (A9).
- [X] `fm-spawn --relaunch` checks the runtime before any mutation and refuses an Orca secondmate (U6, secondmate case).
- [X] Teardown still refuses unlanded work after a reclaim (lab step A15).
- [X] No other backend changed behavior: tmux and herdr tests, zellij and cmux refusals, and the secondmate restart suite pass.
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0 for the changed files; `bin/fm-doc-audience-check.sh` passes.
- [X] `docs/agent-control.md`, `docs/orca-backend.md`, the `stuck-crewmate-recovery` skill, the script headers, and `docs/verification/runtime-backends.md` are updated.
- [X] The live lab ran only in its isolated runtime with a pinned `HOME`, no staged build was activated, no real harness ran, and its final inventory assertion held.
