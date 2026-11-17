# Cycle Log: Orca Documentation Truth Pass

Append only.
Newest last.
Every entry's `red` block is the evidence that the check existed and failed before the edit.

## Baseline

- suites on the base commit `af20b2c9`: `bin/fm-test-run.sh tests/fm-documentation-audiences.test.sh tests/fm-claude-trust.test.sh tests/fm-backend-orca.test.sh tests/fm-backend.test.sh` -> `FM_TEST_SUMMARY total=4 failed=0 skipped_gate=0`
- full repository suite: not run locally, about 15 minutes per CI shard across many shards; `suite_baseline: unknown`
- recorded: cycle 0, before any change

## Baseline red: claim audit against the untouched documents

- audit: `specs/004-orca-docs-truth-pass/tdd/claim-audit.sh all`, committed in `docs(orca): specify the documentation truth pass and its claim audit` before any document edit
- red: 55 of 68 checks fail on the base documents, every one because the stale statement is still present or the required statement is absent; the 13 passes are the retention and invariant checks (`U17`, `U20`, `U21`, `U24` response shapes, `U28` suite name, `U29` verification pointer, `U32`, `A15`, `A16`)
- note: this output is from the audit as first committed, before the correction in the next entry

```text
FAIL U1   docs/orca-backend.md describes Orca on macOS and on Linux
FAIL U2   docs/orca-backend.md names the headless runtime and readiness, not the desktop app
FAIL U3   docs/orca-backend.md keeps the macOS app path, labeled macOS
FAIL U3   docs/orca-backend.md keeps the Homebrew install, labeled macOS
FAIL U4   docs/orca-backend.md says the CLI must be on the PATH of the firstmate shell
FAIL U5   docs/orca-backend.md points headless operators at fm-peek
FAIL S1   docs/orca-backend.md not macOS-only
FAIL S2   docs/orca-backend.md no open-the-app instruction
FAIL U6   docs/orca-backend.md names orca --version
FAIL U6   docs/orca-backend.md says status reports capabilities
FAIL S3   docs/orca-backend.md no missing-version claim
FAIL U7   docs/orca-backend.md says Orca exposes native agent state
FAIL U7   docs/orca-backend.md says firstmate does not use the native signal
FAIL S4   docs/orca-backend.md no missing-busy-signal claim
FAIL U8   docs/orca-backend.md says the adapter delivers Enter and Ctrl+C but not Escape or Ctrl+U
FAIL U9   docs/orca-backend.md attributes the missing keys to the adapter
FAIL U9   docs/orca-backend.md says the passthrough is not exercised live
FAIL S5   docs/orca-backend.md Escape not the unsupported key
FAIL U10  docs/orca-backend.md says Orca worktrees are linked and the trust check accepts them
FAIL S7   docs/orca-backend.md worktree shape not unverified
FAIL U11  docs/orca-backend.md says startupTerminal is not adopted and firstmate creates its own terminal
FAIL S8   docs/orca-backend.md not only result.terminal verified
FAIL U12  docs/orca-backend.md puts long or high-value ships on Herdr
FAIL U12  docs/orca-backend.md keeps scouts and short ships on Orca
FAIL U13  docs/orca-backend.md says a folder-registered project, including firstmate, cannot host Orca work
FAIL U13  docs/orca-backend.md names the per-task backend override
FAIL U14  docs/orca-backend.md says away and quiet modes are refused
FAIL U14  docs/orca-backend.md says the primary needs Herdr or tmux
FAIL U15  docs/orca-backend.md says interrupt, exit, and relaunch refuse on Orca
FAIL U18  docs/agent-control.md no longer says Orca's API exposes only an interrupt and an Enter
FAIL U19  docs/agent-control.md says the adapter does not deliver Escape or Ctrl+U today
FAIL U19  docs/agent-control.md points at the Orca backend document
ok   U20  docs/agent-control.md keeps the recovery-grade classifier requirement
ok   U20  docs/agent-control.md keeps zellij, orca, and cmux refused for exit and relaunch
ok   U21  docs/agent-control.md keeps the Orca capability matrix row byte-identical
FAIL U22  .agents/skills/stuck-crewmate-recovery/SKILL.md gains exactly one added line saying interrupt, exit, and relaunch refuse on Orca
FAIL U24  Orca section labels the existing evidence macOS 1.4.116
ok   U24  Orca section keeps the response-shape evidence
FAIL U25  Orca section has a dated Linux 1.4.261 entry
FAIL U25  Orca section records orca --version
FAIL U25  Orca section records the headless install mode
FAIL U26  Orca section records the linked-worktree shape
FAIL U26  Orca section records the startupTerminal response shape
FAIL U26  Orca section records the native agent-state surfaces
FAIL U26  Orca section records the folder-registered repository kind
FAIL U27  Orca section marks Escape passthrough not exercised live
ok   U28  Orca section names the fake-Orca regression suite
FAIL U28  Orca section says no live Orca lane exists
ok   U29  bin/fm-claude-trust.sh says Orca's CLI-created worktrees are linked
ok   U29  bin/fm-claude-trust.sh points at the verification record
FAIL U30  bin/fm-claude-trust.sh says a folder-registered project has no git worktree for the structural test
FAIL U31  bin/fm-claude-trust.sh keeps the structural-not-path-prefix rationale
FAIL S9   bin/fm-claude-trust.sh no longer calls Orca's worktree shape UNVERIFIED
FAIL S9   bin/fm-claude-trust.sh no longer calls Orca macOS-only
FAIL S9   bin/fm-claude-trust.sh no longer says Orca was not installed where it was written
ok   U32  bin/fm-claude-trust.sh changed comment lines only
ok   A15  only the five named files, the inventory, and the feature artifacts changed
ok   A16  changed Markdown has one sentence per line and no em dash
FAIL S1   docs/orca-backend.md no longer calls Orca macOS-only or an experimental macOS backend
FAIL S2   docs/orca-backend.md no longer says to open the Orca app to watch a terminal
FAIL S3   docs/orca-backend.md no longer says there is no CLI version marker
FAIL S4   docs/orca-backend.md no longer says there is no native busy signal
FAIL S5   docs/orca-backend.md no longer says Escape is the unsupported key
FAIL S7   docs/orca-backend.md no longer calls the worktree shape unverified
FAIL S8   docs/orca-backend.md no longer says only result.terminal is verified
ok   U17  docs/orca-backend.md keeps secondmate spawns unsupported
ok   U17  docs/orca-backend.md keeps explicit-only selection
ok   U17  docs/orca-backend.md keeps the never-raw-delete cleanup rule
claim-audit: 68 checks, 55 failed (base af20b2c9)
exit=1
```

## Test correction: two audit checks fixed before the first edit

- why: `U29` passed on the untouched script because the old "UNVERIFIED" comment line also contains the words Orca, linked, and verified, so it could not fail; `U31` failed on the untouched script because its pattern missed the existing wording, although it is a retention check
- change: `U29` now requires Orca, linked, and Linux on one line; `U31` now requires the exact existing "deliberately NOT a treehouse or orca path prefix" line
- red after correction: `claim-audit.sh U29 U31 U30` -> `FAIL U29 ... linked on Linux`, `ok U31`, `FAIL U30 ...` (2 of 4 checks fail, as intended)
- commit: the commit that carries the first document edit, `docs(orca): correct the Orca backend document`

## Cycle 1: U1 U2 U3 U4 U5 U6 (A1, A2) platform, setup, PATH, app window, version

- test: `claim-audit.sh U1 U2 U3 U4 U5 U6` (written in the baseline commit)
- red: `claim-audit.sh U1 U2 U3 U4 U5 U6` -> `claim-audit: 8 checks, 8 failed`, each `FAIL` naming the absent statement in `docs/orca-backend.md`
- green: `docs/orca-backend.md` intro, setup, prerequisites, observation paragraph, and two Active limits bullets edited; `claim-audit.sh U1 U2 U3 U4 U5 U6 A1 A2` -> `claim-audit: 19 checks, 0 failed`; `bin/fm-doc-audience-check.sh` -> `ok surfaces=221 local_links=757`
- refactor: none needed; the version statement was written once in Active limits and not repeated in Setup, following the one-owner rule
- commit: `docs(orca): correct the Orca backend document`, shared with cycles 2 and 3 because the three cycles edit adjacent paragraphs of one file

## Cycle 2: U7 U8 U9 U10 U11 (A3, A4, A5, A6) native state, keys, linked worktrees, startup terminal

- test: `claim-audit.sh A3 A4 A5 A6` (written in the baseline commit)
- red: `claim-audit.sh A3 A4 A5 A6` -> `claim-audit: 11 checks, 11 failed` (`U7` x2, `S4`, `U8`, `U9` x2, `S5`, `U10`, `S7`, `U11`, `S8`)
- green: `docs/orca-backend.md` key sentence, busy-signal sentence, lifecycle sentence plus the startup-terminal paragraph, the response-shape bullet, and the trust bullet edited; first re-run `claim-audit.sh A1 A2 A3 A4 A5 A6` -> `22 checks, 1 failed` (`S5`, the Active limits bullet `- Escape is unsupported.` survived), bullet removed so the key statement has one owner, re-run -> `22 checks, 0 failed`
- refactor: the task-shape sentence "one Orca terminal" became "one recorded Orca terminal" so it no longer contradicts the spare-terminal statement
- commit: `docs(orca): correct the Orca backend document`

## Cycle 3: U12 U13 U14 U15 (A7) the captain's three decisions and the control-plane refusal

- test: `claim-audit.sh A7` (written in the baseline commit)
- red: `claim-audit.sh A7` -> `claim-audit: 7 checks, 7 failed` (`U12` x2, `U13` x2, `U14` x2, `U15`)
- green: new "Operating posture" section in `docs/orca-backend.md` before "Regression entry points"; `claim-audit.sh A1 A2 A3 A4 A5 A6 A7 U16 U17` -> `claim-audit: 39 checks, 0 failed`; `bin/fm-doc-audience-check.sh` -> `ok surfaces=221 local_links=758`
- refactor: none needed
- commit: `docs(orca): correct the Orca backend document`

## Baseline (continued): fm-control suite on the base commit

- suite: `bin/fm-test-run.sh tests/fm-control.test.sh` on `af20b2c9` -> `FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0`
- recorded: after the four-suite baseline above, because the file takes about three minutes alone

## Cycle 4: U18 U19 (A8) and U22 (A10) agent-control reason and the recovery skill line

- test: `claim-audit.sh A8 A9 A10` (written in the baseline commit; `U20` and `U21` are retention checks that pass on the untouched file)
- red: `claim-audit.sh A8 A9 A10` -> `claim-audit: 7 checks, 4 failed` (`U18`, `U19` x2, `U22`); `U20` x2 and `U21` ok
- green: one sentence in `docs/agent-control.md` replaced (the adapter delivers only Enter and Ctrl+C today, with a pointer to `orca-backend.md`), one line added to `.agents/skills/stuck-crewmate-recovery/SKILL.md` after the reclaim sentence; `claim-audit.sh A8 A9 A10` -> `claim-audit: 7 checks, 0 failed`; `bin/fm-doc-audience-check.sh` -> `ok surfaces=221 local_links=760`
- refactor: none needed; the capability matrix row and the exit and relaunch refusal paragraph are untouched, which `U20` and `U21` verify
- commit: `docs(orca): state what refuses on Orca in agent control and the recovery skill`

## Cycle 5: U24 U25 U26 U27 U28 (A11, A12) Linux headless 1.4.261 verification entry

- test: `claim-audit.sh A11 A12` (written in the baseline commit)
- red: `claim-audit.sh A11 A12` -> `claim-audit: 12 checks, 10 failed` (`U24` label, `U25` x3, `U26` x4, `U27`, `U28` no-live-lane); `U24` response-shape and `U28` suite name ok
- green: the Orca section of `docs/verification/runtime-backends.md` split into a macOS 1.4.116 subsection (existing evidence retained, labeled) and a new Linux headless 1.4.261 subsection; first re-run -> `12 checks, 1 failed` (`U27`: the Escape bullet did not say "not exercised"), bullet reworded to "Escape and Ctrl+U passthrough is not exercised live", re-run `claim-audit.sh A8 A9 A10 A11 A12` -> `claim-audit: 19 checks, 0 failed`
- refactor: none needed
- commit: `docs(orca): record Linux headless 1.4.261 evidence beside the macOS entry`

## Cycle 6: U29 U30 U31 U32 (A13, A14) trust-check comment

- test: `claim-audit.sh A13 A14` (written in the baseline commit, `U29` and `U31` corrected before the first edit)
- red: `claim-audit.sh A13 A14` -> `claim-audit: 8 checks, 5 failed` (`U29`, `U30`, `S9` x3); `U31` and `U32` ok
- green: the Orca sentences of the structural-test comment in `bin/fm-claude-trust.sh` replaced; `claim-audit.sh A13 A14` -> `claim-audit: 8 checks, 0 failed`; `bash -n bin/fm-claude-trust.sh` ok; `git diff` shows 10 added and 11 removed lines, all comments
- refactor: none needed
- commit: `docs(orca): correct the Orca worktree-shape comment in the trust script`
