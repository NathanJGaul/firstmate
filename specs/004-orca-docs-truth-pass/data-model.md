# Data Model: Orca Documentation Truth Pass

The feature has no stored data.
Its entity is the claim ledger below: each row is one statement that changes, the file that owns it, and the evidence that supports the new wording.
Source codes: `E-status` is `orca --version` and `orca status --json`, `E-repo` is `orca repo list --json`, `E-help` is `orca terminal send --help`, `E-ws` is the report's linked-worktree observation, `E-create` is the report's worktree-creation response observation, `E-code` is the code the sentence describes.

| id | owner file | stale statement | new statement | evidence |
| --- | --- | --- | --- | --- |
| L1 | `docs/orca-backend.md` | Orca is an experimental macOS backend and is macOS-only | Orca runs on macOS through the app and on Linux through the headless runtime | E-status |
| L2 | `docs/orca-backend.md` | Orca exposes no stable CLI version or protocol marker, so readiness is the only gate | `orca --version` and `orca status --json` report a version and capability list; firstmate still gates on readiness only | E-status, E-code |
| L3 | `docs/orca-backend.md` | The watcher has no native Orca busy signal | Orca exposes native agent state that firstmate does not use today; worker state comes from the harness lifecycle | report section 4 gap G6, E-code |
| L4 | `docs/orca-backend.md`, `docs/agent-control.md` | Escape is the only unsupported key, and Orca's terminal API cannot send Escape or Ctrl+U | The adapter delivers Enter and Ctrl+C only; Orca's help says control bytes pass through, not exercised live | E-help, E-code |
| L5 | `docs/orca-backend.md`, `bin/fm-claude-trust.sh` | Orca's worktree shape is unverified against the trust check | Orca-created worktrees are linked git worktrees, so the check accepts them | E-ws |
| L6 | `docs/orca-backend.md` | Only `result.terminal` is a verified terminal shape | Orca returns `result.startupTerminal`, which the adapter does not adopt, so firstmate creates its own terminal | E-create, E-code |
| L7 | `docs/orca-backend.md` | Open the Orca app to watch a task's terminal | The app window is the macOS path; headless operators use `fm-peek.sh` | E-status |
| L8 | `docs/orca-backend.md` | Setup requires `/Applications/Orca.app` and `brew install orca` | Those are the macOS path; Linux needs a ready headless runtime and the CLI on the firstmate shell's `PATH` | E-status, shell check |
| L9 | `docs/orca-backend.md` | (absent) | Long or high-value ships belong on Herdr until Orca interrupt and relaunch land; Orca suits scouts and short ships | captain decision |
| L10 | `docs/orca-backend.md` | (absent) | A folder-registered project, including the firstmate repository, cannot host Orca work; use the per-task backend override | captain decision, E-repo |
| L11 | `docs/orca-backend.md` | (absent) | Away and quiet modes are refused with an Orca-hosted primary; run the primary in Herdr or tmux | captain decision, E-code |
| L12 | `.agents/skills/stuck-crewmate-recovery/SKILL.md` | (absent) | Interrupt, exit, and relaunch refuse on Orca today | E-code |
| L13 | `docs/verification/runtime-backends.md` | Only macOS 1.4.116 evidence exists | A dated Linux headless 1.4.261 entry sits beside the retained macOS entry | E-status, E-repo, E-help, E-ws, E-create |

Validation rules:

- Every row names a source before its wording is written.
- A row whose evidence is `report` or help text and not a live exercise is worded as not exercised live.
- No row removes a macOS fact; each qualifies it.
