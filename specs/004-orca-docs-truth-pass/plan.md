# Implementation Plan: Orca Documentation Truth Pass

**Branch**: `fm/firstmate-orca-docs-truth-pass` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-orca-docs-truth-pass/spec.md`

## Summary

Six statements about Orca in firstmate's maintained prose are stale or misleading, the recovery playbook is silent on what refuses on Orca, and three captain decisions are recorded nowhere an operator will look.
The plan rewrites the claims in place in the five files the captain's ask names, adds one Linux headless 1.4.261 verification entry beside the retained macOS 1.4.116 evidence, and states the three decisions in the Orca backend document, which is the single owner of Orca operating posture.
No executable line changes.
Proof is the existing documentation-audience check and the existing Orca, control, and trust suites staying green, plus a claim audit that is red before the edits and green after, and a comment-only check on the one script touched.

## Technical Context

**Language/Version**: Markdown, plus comment text in one Bash script.

**Primary Dependencies**: None added.
Read-only `orca --version` and `orca status --json` on the evaluated host were used to confirm the cited facts.

**Storage**: Files only.

**Testing**: Executable Bash tests in `tests/*.test.sh` run through `bin/fm-test-run.sh`; documentation structure through `bin/fm-doc-audience-check.sh` and `tests/fm-documentation-audiences.test.sh`; lint through `bin/fm-lint.sh`.

**Target Platform**: Operators on macOS and Linux; the evidence host is Linux with Orca 1.4.261 as a headless runtime.

**Project Type**: CLI scripts with maintained documentation.

**Performance Goals**: None.

**Constraints**: One sentence per line, plain dash, no em dash, no agent co-author; no behavior change; macOS facts qualified rather than deleted; no edits to the adapter, control library, spawn script, or any file outside the five named surfaces; nothing under the live home's `data/` or `state/` is edited.

**Scale/Scope**: Five edited files, the audience inventory entries for the new Spec-Kit artifacts, and the Spec-Kit artifacts.

## Constitution Check

The project constitution is still the unfilled template, so there are no ratified gates to evaluate.
The Spec-Kit-TDD working gate applies by instruction: each behavior is driven by a check that failed first and is recorded, nothing is weakened or skipped to reach green, refactoring happens only on green, and test strength is shown with deliberate mutants because no mutation tool is installed.
For a documentation change the behaviors are claims, so the failing-first checks are claim audits over the prose.
Result: pass, with that gate adopted as the working rule.
Wording of the TDD principle for the constitution still needs the captain's approval, and this is reported as a baseline limitation.

## Project Structure

### Documentation (this feature)

```text
specs/004-orca-docs-truth-pass/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/claim-audit.md
├── checklists/requirements.md
├── tasks.md
└── tdd/
```

### Source Code (repository root)

```text
docs/documentation-audiences.json               # classify the new Spec-Kit artifacts, nothing else
docs/orca-backend.md                       # rewrite: platforms, setup, limits, decisions
docs/agent-control.md                      # key-delivery reason; relaunch Orca carve-out stays
docs/verification/runtime-backends.md      # Orca section: macOS entry retained, Linux entry added
bin/fm-claude-trust.sh                     # comment text only: Orca worktree shape
.agents/skills/stuck-crewmate-recovery/SKILL.md   # one added line
```

**Structure Decision**: No new files outside `specs/`.
Each claim is corrected in the file that already owns it, following the one-owner rule: the Orca backend document owns operating posture, the agent-control document owns the control-plane refusals, the verification record owns dated evidence, and the trust script comment owns the structural-test rationale.
Other files that mention Orca stay as they are.

## Design

**D1 - `docs/orca-backend.md`**: Patch the existing sentences in place.
Replace the macOS-only framing with a macOS and Linux framing, and split the prerequisites into the macOS app path and the Linux headless runtime path, keeping every macOS fact and qualifying it.
State that the CLI must be reachable on the `PATH` of the shell that runs firstmate, because on Linux it is on `PATH` only inside Orca's own terminals.
Replace the Escape sentence with the Enter, Ctrl+C, and not-delivered statement, attributed to the adapter.
Replace the "no native busy signal" sentence with the native-signal-exists, not-used statement.
Replace the "no stable CLI version or protocol marker" limit with the version and capability statement.
Replace the verified-terminal-shape paragraph and the Claude trust limit with the startup-terminal statement and the linked-worktree statement.
Add one short "Operating posture" section holding the three captain decisions and the refusal of interrupt, exit, and relaunch, so each fact is stated once.

**D2 - `docs/agent-control.md`**: Replace the one sentence that says Orca's terminal API exposes only an interrupt and an Enter with the adapter-gap statement, and add a pointer to the Orca backend document for the posture.
The capability matrix row, the exit and relaunch refusal paragraph, and the relaunch carve-out sentence stay as written because they are already accurate.

**D3 - `docs/verification/runtime-backends.md`**: Retitle the existing Orca evidence as macOS 1.4.116, keep it verbatim in substance, and add a Linux headless 1.4.261 subsection recording the date, the commands, the observed fields, and the explicit not-exercised list.

**D4 - `bin/fm-claude-trust.sh`**: Replace the "UNVERIFIED" Orca sentences of the structural-test comment with the verified finding, keep the rationale for a structural test, and keep the retained unknown about folder-registered projects.
Edit comment lines only.

**D5 - `.agents/skills/stuck-crewmate-recovery/SKILL.md`**: Add one line directly after the reclaim sentence that closes the tmux and Herdr refusal guidance, saying interrupt, exit, and relaunch refuse on Orca today and pointing at the Orca backend document.

## Verification Design

- Claim audit (contracts/claim-audit.md): `tdd/claim-audit.sh`, a script of greps over the five files, committed before the edits so its red run is in git history, then run green after them.
  It lives under the feature's `tdd/` directory as evidence and is not registered in `tests/` or run by CI, because the repository's documentation check deliberately does not keyword-lint prose and a repository phrase pin would rot with every rewording.
- Comment-only check: the diff of `bin/fm-claude-trust.sh` has no added or removed line that is not a comment.
- Existing suites that must stay green unchanged: `tests/fm-documentation-audiences.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-backend-orca.test.sh`, `tests/fm-control.test.sh`, `tests/fm-backend.test.sh`, plus `bin/fm-doc-audience-check.sh` and `bin/fm-lint.sh`.
- Deliberate mutants: reinstate one stale sentence in each of two files and confirm the claim audit goes red.
- Appendix re-read: every changed claim is traced to the evaluation report's appendix of Orca 1.4.261 facts or to the code it describes, and recorded in the data model.

## Phase 0 and Phase 1 Outputs

research.md (decisions and evidence), data-model.md (the claim ledger), contracts/claim-audit.md, quickstart.md.
