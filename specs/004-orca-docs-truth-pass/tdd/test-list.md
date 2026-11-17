---
feature: 004-orca-docs-truth-pass
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 18
planned_at: af20b2c9
updated_at: af20b2c9
suite_baseline: unknown
---

# Test List: Orca Documentation Truth Pass

Baseline note: the full repository suite was not run locally because it takes about 15 minutes per CI shard across many shards.
The suites that can observe this feature were run on the base commit and were green: `tests/fm-documentation-audiences.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-backend-orca.test.sh`, and `tests/fm-backend.test.sh`.
`tests/fm-control.test.sh` is run before and after the edits as part of the cycle log.
This feature changes prose and one comment, so a behavior is a claim about a document, and its test is a claim audit: `tdd/claim-audit.sh`, which greps the owning file and is committed with the red evidence as feature evidence.
The audit is the real entry point because the document text is what an operator or agent reads.
It is not registered in `tests/` or run by CI, for the reason recorded in `research.md` R5.
Planning corrections made before the first red: `U3`, `U24`, and `A11` became `example` and `PENDING` because their labeled-as-macOS requirement is new and fails today; `A15` and `A16` became `characterization` and `BASELINE` because they are invariants that hold before the edits; `U23` was folded into `U22`.
Traces use `US<story>.<scenario>` for acceptance scenarios and `FR-nnn` for functional requirements in `spec.md`.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                                                                                | traces                          | kind            | runner                      | state   | test                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | --------------- | --------------------------- | ------- | ------------------------------------------------- |
| A1  | The Orca backend document names Linux and the headless runtime, keeps the macOS app and Homebrew path labeled as macOS, and no longer says macOS-only    | US1.1, US1.2, FR-001, FR-002, FR-008 | example    | `claim-audit.sh A1`         | PENDING |                                                   |
| A2  | The Orca backend document says Orca reports a version and capability list and no longer says there is no version or protocol marker                     | US1.4, FR-003                   | example         | `claim-audit.sh A2`         | PENDING |                                                   |
| A3  | The Orca backend document says Orca exposes native agent state that firstmate does not use, and no longer says there is no native busy signal           | US1.4, FR-004                   | example         | `claim-audit.sh A3`         | PENDING |                                                   |
| A4  | The Orca backend document says the adapter delivers Enter and Ctrl+C and not Escape or Ctrl+U, attributes that to the adapter, and says it is not exercised live | US1.3, FR-005             | example         | `claim-audit.sh A4`         | PENDING |                                                   |
| A5  | The Orca backend document says Orca worktrees are linked git worktrees accepted by the trust check and no longer calls the shape unverified           | US1.1, FR-006                   | example         | `claim-audit.sh A5`         | PENDING |                                                   |
| A6  | The Orca backend document says Orca returns a startup terminal that the adapter does not adopt, and no longer says only the older shape is verified    | FR-007                          | example         | `claim-audit.sh A6`         | PENDING |                                                   |
| A7  | The Orca backend document states the three captain decisions once: ships on Herdr, folder-registered projects, away and quiet modes                      | US1.5, US1.6, US1.7, FR-009, FR-010, FR-011 | example | `claim-audit.sh A7`         | PENDING |                                                   |
| A8  | The agent-control document no longer says Orca's terminal API cannot send Escape or Ctrl+U and says the adapter does not deliver them today             | US2.2, FR-012                   | example         | `claim-audit.sh A8`         | PENDING |                                                   |
| A9  | The agent-control document keeps the no-recovery-grade-classifier refusal for exit and relaunch and its Orca capability matrix row is byte-identical    | US2.3, US2.4, FR-012, FR-013    | characterization | `claim-audit.sh A9`        | BASELINE | `claim-audit.sh A9` (green against untouched files) |
| A10 | The recovery skill gains exactly one line saying interrupt, exit, and relaunch refuse on Orca today                                                     | US2.1, FR-017                   | example         | `claim-audit.sh A10`        | PENDING |                                                   |
| A11 | The verification record keeps the macOS 1.4.116 Orca evidence and labels it as macOS                                                                    | US3.1, FR-015                   | example         | `claim-audit.sh A11`        | PENDING |                                                   |
| A12 | The verification record gains a dated Linux headless 1.4.261 entry with commands, observed fields, an explicit not-exercised list, and the regression suites | US3.2, US3.3, US3.4, FR-015, FR-016 | example | `claim-audit.sh A12`  | PENDING |                                                   |
| A13 | The trust script comment states the verified linked-worktree finding and the folder-registered residual and no longer calls Orca unverified or macOS-only | US4.1, US4.2, FR-014        | example         | `claim-audit.sh A13`        | PENDING |                                                   |
| A14 | Every changed line of the trust script is a comment or blank, and its suite, shell syntax, and lint results are unchanged                               | US4.3, FR-018                   | example         | `claim-audit.sh A14` and `bin/fm-test-run.sh tests/fm-claude-trust.test.sh` | PENDING |                          |
| A15 | The change touches only the five named files, the Spec-Kit artifacts, and the audience inventory entries that classify them, and no test file or other script | FR-018, FR-021        | characterization | `claim-audit.sh A15`       | BASELINE | `claim-audit.sh A15` (invariant, green before the edits, re-run at the end) |
| A16 | Every changed Markdown line follows one sentence per line and contains no em dash                                                                       | FR-019                          | characterization | `claim-audit.sh A16`       | BASELINE | `claim-audit.sh A16` (invariant, green before the edits, re-run at the end) |

## Inner loop: unit behaviors

### `docs/orca-backend.md`

| id  | behavior                                                                                              | traces            | kind             | state    | test                    |
| --- | ----------------------------------------------------------------------------------------------------- | ----------------- | ---------------- | -------- | ----------------------- |
| U1  | Describes Orca as running on macOS and on Linux                                                       | FR-001, A1        | example          | PENDING  | `claim-audit.sh U1`     |
| U2  | Names the headless runtime as the Linux path and readiness, not the desktop app, as the requirement   | FR-002, A1        | example          | PENDING  | `claim-audit.sh U2`     |
| U3  | Keeps `/Applications/Orca.app` and `brew install orca` and labels them as the macOS path               | FR-001, A1        | example          | PENDING  | `claim-audit.sh U3`     |
| U4  | Says the CLI must be on the `PATH` of the shell that runs firstmate                                   | FR-002, A1        | example          | PENDING  | `claim-audit.sh U4`     |
| U5  | Says the app window is the macOS way to watch a terminal and headless operators use `fm-peek.sh`      | FR-008, A1        | example          | PENDING  | `claim-audit.sh U5`     |
| U6  | Says `orca --version` and `orca status --json` report a version and capabilities and readiness is firstmate's only gate | FR-003, A2 | example         | PENDING  | `claim-audit.sh U6`     |
| U7  | Says Orca exposes native agent state and firstmate uses the harness lifecycle instead                 | FR-004, A3        | example          | PENDING  | `claim-audit.sh U7`     |
| U8  | Says the adapter delivers Enter and Ctrl+C only                                                       | FR-005, A4        | example          | PENDING  | `claim-audit.sh U8`     |
| U9  | Attributes the missing Escape and Ctrl+U to the adapter and marks the passthrough not exercised live  | FR-005, A4        | example          | PENDING  | `claim-audit.sh U9`     |
| U10 | Says Orca-created worktrees are linked and the Claude trust check accepts them                        | FR-006, A5        | example          | PENDING  | `claim-audit.sh U10`    |
| U11 | Says Orca returns `result.startupTerminal`, the adapter does not adopt it, and firstmate creates its own terminal | FR-007, A6    | example          | PENDING  | `claim-audit.sh U11`    |
| U12 | Says long or high-value ships belong on Herdr until Orca interrupt and relaunch land and Orca suits scouts and short ships | FR-009, A7 | example      | PENDING  | `claim-audit.sh U12`    |
| U13 | Says a folder-registered project, including the firstmate repository, cannot host Orca work and the per-task backend override moves it | FR-010, A7 | example | PENDING | `claim-audit.sh U13`    |
| U14 | Says away and quiet modes are refused with an Orca-hosted primary and the primary needs Herdr or tmux | FR-011, A7        | example          | PENDING  | `claim-audit.sh U14`    |
| U15 | Says interrupt, exit, and relaunch refuse on Orca today                                                | FR-017, A7        | example          | PENDING  | `claim-audit.sh U15`    |
| U16 | Contains none of the stale phrases listed in contract C1                                              | SC-001, A1 to A6  | example          | PENDING  | `claim-audit.sh U16`    |
| U17 | Keeps secondmate spawns unsupported, explicit-only selection, and the cleanup safety paragraph        | FR-021            | characterization | BASELINE | `claim-audit.sh U17`    |

### `docs/agent-control.md`

| id  | behavior                                                                                         | traces        | kind             | state    | test                    |
| --- | ------------------------------------------------------------------------------------------------ | ------------- | ---------------- | -------- | ----------------------- |
| U18 | Does not say Orca's terminal API exposes only an interrupt and an Enter                           | FR-012, A8    | example          | PENDING  | `claim-audit.sh U18`    |
| U19 | Says the adapter does not deliver Escape or Ctrl+U on Orca today and points at the Orca backend document | FR-012, A8 | example         | PENDING  | `claim-audit.sh U19`    |
| U20 | Keeps the exit and relaunch refusal for lack of a recovery-grade agent-state classifier           | FR-012, A9    | characterization | BASELINE | `claim-audit.sh U20`    |
| U21 | Leaves the Orca capability matrix row byte-identical                                              | FR-013, A9    | characterization | BASELINE | `claim-audit.sh U21`    |

### `.agents/skills/stuck-crewmate-recovery/SKILL.md`

| id  | behavior                                                                              | traces         | kind             | state    | test                    |
| --- | ------------------------------------------------------------------------------------- | -------------- | ---------------- | -------- | ----------------------- |
| U22 | Has one added line saying interrupt, exit, and relaunch refuse on Orca today           | FR-017, A10    | example          | PENDING  | `claim-audit.sh U22`    |
| U23 | Has no other changed line                                                              | FR-017, A10    | example          | DROPPED  | folded into U22, which requires exactly one added and no removed line |

### `docs/verification/runtime-backends.md`

| id  | behavior                                                                                                           | traces        | kind             | state    | test                    |
| --- | ------------------------------------------------------------------------------------------------------------------ | ------------- | ---------------- | -------- | ----------------------- |
| U24 | Labels the existing Orca evidence as macOS 1.4.116 and retains its response-shape evidence                           | FR-015, A11   | example          | PENDING  | `claim-audit.sh U24`    |
| U25 | Adds a Linux headless 1.4.261 entry with the date, `orca --version`, and the `orca status --json` fields            | FR-015, A12   | example          | PENDING  | `claim-audit.sh U25`    |
| U26 | Records the linked-worktree shape, the worktree-creation response shape, the native agent-state surfaces, and the folder-registered repository kind | FR-015, A12 | example | PENDING | `claim-audit.sh U26`    |
| U27 | Lists each behavior established only from help text or a server bundle as not exercised live                        | FR-016, A12   | example          | PENDING  | `claim-audit.sh U27`    |
| U28 | Names the fake-Orca regression suites and the absence of a live Orca lane                                           | FR-016, A12   | example          | PENDING  | `claim-audit.sh U28`    |

### `bin/fm-claude-trust.sh` (comment text only)

| id  | behavior                                                                                                       | traces        | kind             | state    | test                    |
| --- | -------------------------------------------------------------------------------------------------------------- | ------------- | ---------------- | -------- | ----------------------- |
| U29 | States that Orca's CLI-created worktrees are linked worktrees sharing the project's common dir and points at the verification record | FR-014, A13 | example   | PENDING  | `claim-audit.sh U29`    |
| U30 | Says a folder-registered project has no git worktree for the structural test and cannot host Orca work           | FR-014, A13   | example          | PENDING  | `claim-audit.sh U30`    |
| U31 | Keeps the reason the test is structural and not a path prefix                                                    | FR-014, A13   | characterization | BASELINE | `claim-audit.sh U31`    |
| U32 | Has no changed line that is not a comment or blank                                                               | FR-018, A14   | example          | PENDING  | `claim-audit.sh U32`    |

## Invariants and edge cases still to place

- None.
  Every behavior above has a home.

## Out of scope

- The header comment of `bin/backends/orca.sh` and the key-support comment in `bin/fm-control-lib.sh` still attribute the missing Escape to Orca's API: they belong to the slice that changes key delivery, and are reported as follow-up.
- Leftover Orca-made branches, adoption of the startup terminal, early refusal of folder-registered repositories, CLI discovery, and the Linux install hint: separate slices that change behavior.
- Changing `docs/configuration.md` or any other document that mentions Orca: not in the five named surfaces.
- Mutation tooling: none is installed, so test strength is shown with deliberate mutants in `tdd/verification.md`.
- A live Orca lane: nothing in this feature exercises a live Orca terminal or worktree.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time, so this file is readable on its own:

- Single test: `bin/fm-test-run.sh {file}`
- Full suite: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- Coverage: `bin/fm-test-run.sh --check-coverage`
- Mutation: none installed, deliberate mutants only
- Claim audit (feature evidence, committed under `tdd/`, not a repository test): `specs/004-orca-docs-truth-pass/tdd/claim-audit.sh <id>`
