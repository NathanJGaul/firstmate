# Feature Specification: Orca Documentation Truth Pass

**Feature Branch**: `fm/firstmate-orca-docs-truth-pass`

**Created**: 2026-11-17

**Status**: Draft

**Input**: User description: "Correct the stale Orca statements in firstmate's documentation (slice P1-D of the Orca compatibility plan). On this Linux host Orca 1.4.261 runs as a headless runtime. Rewrite the Orca backend document, the Orca trust-check comment in the Claude trust script, the Orca text in the agent-control document, and the Orca section of the runtime-backends verification record (adding a Linux headless 1.4.261 entry), and add one line to the stuck-crewmate-recovery skill saying interrupt, exit and relaunch refuse on Orca today. Qualify the macOS facts rather than deleting them. State the captain's decisions: long or high-value ships belong on Herdr until Orca interrupt and relaunch land, folder-registered projects such as the firstmate repo itself cannot host Orca work and use the per-task backend override, and away and quiet modes are refused with an Orca-hosted primary and need the primary in Herdr or tmux. No code behavior changes."

## Overview

Firstmate's Orca documentation was written against macOS evidence (Orca 1.4.116) and is now wrong in ways that mislead.
An evaluation on 2026-11-17 against Orca 1.4.261 on Linux, running as the headless runtime, found six stale statements.
The documents call Orca macOS-only, call Escape the only key Orca cannot receive, say Orca has no native busy signal and no version marker, call Orca's worktree shape unverified against the Claude trust check, and describe only one verified terminal shape when the runtime returns another.
The same evaluation found that the stuck-worker recovery playbook never says that interrupt, exit and relaunch refuse on Orca.
The captain then took the evaluation's recommendations on three operating-posture questions that no document states yet.

This feature corrects the prose and the one code comment that carry those claims, records what was observed in the maintainer verification record, and states the captain's three decisions where an operator or agent will look for them.
It changes no behavior: every script, test fixture, and runtime path stays exactly as it is.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An operator learns what Orca supports on Linux and which backend to pick (Priority: P1)

An operator, or an agent acting for one, opens the Orca backend document to decide whether Orca can host a given task on a Linux host, and what to expect when it does.

**Why this priority**: This is the page that decides backend choice.
Today it tells a Linux operator that Orca does not apply, which is false, and it omits the three operating decisions the captain made, so a wrong backend can be picked for a long ship, a folder-registered project, or an away session.

**Independent Test**: Read the rewritten Orca backend document with no other context and answer, from it alone: which platforms it covers, how to confirm the runtime and its version, which keys the adapter can deliver, where a worker's busy state comes from, which projects cannot host Orca work and what to do instead, which ships belong on Herdr, and what happens to away and quiet modes.

**Acceptance Scenarios**:

1. **Given** a Linux host running Orca as a headless runtime, **When** the operator reads the setup section, **Then** it states that Orca works there, names the runtime-readiness requirement, and says the desktop app is not required.
2. **Given** a macOS operator, **When** they read the same page, **Then** the macOS app and Homebrew facts are still present and qualified as the macOS path, not removed.
3. **Given** the limits section, **When** it describes keys, **Then** it says the adapter delivers Enter and Ctrl+C only and does not deliver Escape or Ctrl+U today, and attributes that to the adapter rather than to Orca having no such primitive.
4. **Given** the limits section, **When** it describes busy state and version, **Then** it says Orca reports a version and capability list and exposes native agent state, and says which of these firstmate uses today and which it does not.
5. **Given** the operator has a project that Orca registered as a folder, including the firstmate repository, **When** they read the limits section, **Then** it says such a project cannot host Orca work and that the per-task backend override moves that task to another backend.
6. **Given** the operator is choosing a backend for a long-running or high-value ship, **When** they read the page, **Then** it says those ships belong on Herdr until Orca interrupt and relaunch land, and that Orca suits scouts and short ships.
7. **Given** the operator runs the primary inside an Orca terminal, **When** they read about away and quiet modes, **Then** it says both are refused and that the primary needs to be in Herdr or tmux.

---

### User Story 2 - An agent recovering a stuck Orca worker is told what refuses and why (Priority: P1)

A firstmate agent follows the stuck-worker recovery playbook for a worker whose backend is Orca and reaches the steps that interrupt, exit or relaunch the worker.

**Why this priority**: The playbook is the only place such an agent looks, and its steps cannot be followed on Orca.
Without a statement of that, the agent retries refused verbs or improvises a respawn that could put two agents in one worktree.

**Independent Test**: Read the recovery skill and the agent-control document and confirm each says, in one place each, that interrupt, exit and relaunch refuse on Orca today and that the capability table agrees with the prose.

**Acceptance Scenarios**:

1. **Given** the recovery skill, **When** an agent reads its Orca guidance, **Then** one added line says interrupt, exit and relaunch refuse on Orca today.
2. **Given** the agent-control document, **When** it explains why Orca refuses a key, **Then** it does not claim Orca's terminal API cannot send Escape, and instead states that the adapter does not deliver Escape or Ctrl+U today.
3. **Given** the agent-control document, **When** it explains why exit and relaunch refuse on Orca, **Then** it gives the unchanged reason that no recovery-grade agent-state classifier exists for Orca.
4. **Given** the capability matrix, **When** it is compared with the prose, **Then** the Orca row is unchanged and still consistent with it.

---

### User Story 3 - A maintainer finds Linux evidence beside the macOS evidence (Priority: P2)

A maintainer reading the runtime-backends verification record wants to know what has actually been observed for Orca and on which platform and version.

**Why this priority**: The record holds only macOS 1.4.116 evidence, so no document shows that the Linux and headless shapes were ever observed.
Later slices that depend on those shapes need a dated entry to cite.

**Independent Test**: Read the Orca section and confirm it holds both a macOS 1.4.116 entry and a Linux headless 1.4.261 entry, each dated and versioned, each naming the commands run and the fields observed, and each saying what it does not establish.

**Acceptance Scenarios**:

1. **Given** the Orca section, **When** a maintainer reads it, **Then** the macOS 1.4.116 evidence is retained and labeled as macOS evidence.
2. **Given** the new Linux entry, **When** a maintainer reads it, **Then** it records the date, the platform, the version, the headless install mode, the readiness fields, the linked-worktree shape, the worktree-creation response shape, and the native agent-state surfaces, each with the command or source that showed it.
3. **Given** the new entry, **When** it names behavior that was read from help text or a server bundle rather than exercised on a live terminal, **Then** it says so explicitly and does not present it as verified.
4. **Given** the new entry, **When** a later change alters Orca behavior, **Then** the entry names the regression suite that refreshes it and the live check that does not yet exist.

---

### User Story 4 - A maintainer reading the Claude trust check sees Orca's worktree shape as established (Priority: P2)

A maintainer reads the comment in the Claude workspace-trust script that explains why it refuses anything that is not a linked git worktree.

**Why this priority**: The comment says Orca's shape is unverified, macOS-only, and not installed where it was written.
It now misleads anyone deciding whether an Orca spawn can pass this check.

**Independent Test**: Read the comment and confirm it states that Orca creates linked worktrees on Linux, cites where that is recorded, and keeps the structural-test rationale and the folder-registered residual unknown.

**Acceptance Scenarios**:

1. **Given** the trust script comment, **When** it discusses Orca, **Then** it states that the worktrees Orca's command line creates are linked git worktrees sharing the project's git common directory, and points at the verification record.
2. **Given** the comment, **When** it discusses a project Orca registered as a folder, **Then** it says that project has no git worktree for the structural test to accept and that the question does not arise because such a project cannot host Orca work.
3. **Given** the comment is edited, **When** the script runs, **Then** its behavior and every existing test result are identical to before the edit.

---

### Edge Cases

- A sentence that is true only on macOS must be qualified as macOS, never deleted, because it is real evidence for a different platform.
- A fact established only from help text or a server bundle, such as Escape passthrough, must be worded as not exercised live.
- The documentation audience inventory must keep classifying every touched file, and every local link in a touched file must still resolve.
- Nearby slices that touch the same files for other reasons will need ordinary rebase work, so edits should patch the existing wording in place rather than reflow whole sections.
- The firstmate repository is itself a folder-registered project in the evaluated installation, so the folder-project statement must read correctly for a reader whose own repository is the one affected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Orca backend document MUST describe Orca as available on macOS and on Linux, with the macOS app and its install path retained and qualified as the macOS path.
- **FR-002**: The Orca backend document MUST describe the Linux headless runtime as a supported way to run Orca, including that readiness of the runtime, not the desktop app, is what firstmate requires.
- **FR-003**: The Orca backend document MUST state that Orca reports its version and a capability list through its status command, and MUST NOT say Orca exposes no version or protocol marker.
- **FR-004**: The Orca backend document MUST state that Orca exposes native agent state, and MUST say that firstmate's busy state for Claude workers comes from the harness lifecycle hooks and that the native Orca signal is not used by firstmate today.
- **FR-005**: The Orca backend document MUST state that the adapter delivers Enter and Ctrl+C but not Escape or Ctrl+U, MUST attribute this to the adapter and not to Orca lacking a primitive, and MUST say the passthrough has not been exercised on a live terminal.
- **FR-006**: The Orca backend document MUST state that Orca's worktrees are linked git worktrees and that the Claude workspace-trust check therefore accepts them, and MUST remove the claim that the shape is unverified.
- **FR-007**: The Orca backend document MUST describe the worktree-creation response as returning a startup terminal that the adapter does not adopt today, MUST say that firstmate creates its own terminal as a result, and MUST remove the claim that only the older terminal shape is verified.
- **FR-008**: The Orca backend document MUST remove the instruction to open the Orca app to watch a task's terminal, or qualify it to the macOS app, and MUST point headless operators at the supervision commands.
- **FR-009**: The Orca backend document MUST state the captain's decision that long-running or high-value ships belong on Herdr until Orca interrupt and relaunch land, and that Orca is for scouts and short ships.
- **FR-010**: The Orca backend document MUST state that a project Orca registered as a folder, including the firstmate repository itself, cannot host Orca work and that the per-task backend override on spawn moves that task to another backend.
- **FR-011**: The Orca backend document MUST state that away mode and quiet mode are refused with an Orca-hosted primary and that the primary needs to be in Herdr or tmux for them.
- **FR-012**: The agent-control document MUST NOT claim that Orca's terminal API cannot deliver Escape or Ctrl+U, MUST state that the adapter does not deliver them today, and MUST keep the unchanged statement that exit and relaunch refuse on Orca for lack of a recovery-grade agent-state classifier.
- **FR-013**: The agent-control document's capability matrix row for Orca MUST remain unchanged.
- **FR-014**: The Claude trust script comment MUST replace the unverified-shape paragraph with the verified linked-worktree finding, the platform and version it was observed on, and a pointer to the verification record, while keeping the reason the test is structural and not path-based.
- **FR-015**: The runtime-backends verification record MUST retain the macOS 1.4.116 evidence, labeled as macOS, and MUST add a Linux headless 1.4.261 entry giving the date, the commands, and the observed fields for runtime readiness, install mode, version, capability list, linked-worktree shape, worktree-creation response shape, native agent-state surfaces, and folder-registered repositories.
- **FR-016**: The new verification entry MUST mark every behavior established only from help text or a server bundle as not exercised live, and MUST name the regression suite that covers the fake-Orca side and the absence of a live Orca lane.
- **FR-017**: The stuck-crewmate-recovery skill MUST gain exactly one line saying that interrupt, exit and relaunch refuse on Orca today, placed where the Orca inventory guidance already sits.
- **FR-018**: No script, test, fixture, configuration schema, or runtime path MAY change behavior, and every edit to a script file MUST be to comment text only.
  The one permitted non-prose edit is the documentation audience inventory, which MUST gain a classification entry for each new tracked Spec-Kit document and no other change.
- **FR-019**: Every changed Markdown line MUST follow the repository style of one sentence per line and a plain dash, with no em dash.
- **FR-020**: Every claim that changed MUST be checked against the evaluation report's appendix of Orca 1.4.261 facts and against the code it describes, and a claim that cannot be supported MUST be softened or dropped, not asserted.
- **FR-021**: Statements outside this slice's named files MUST be left to their own slices; in particular the adapter's own header comment, the install hint, and the other documents that mention Orca are unchanged.

### Key Entities

- **Orca claim**: A single statement in a maintained document or comment about what Orca can or cannot do, with the platform and version it holds on and the source that supports it.
- **Operating decision**: One of the captain's three recorded calls (ship placement, folder-registered projects, away and quiet modes) that an operator must be able to find in the Orca backend document.
- **Verification entry**: A dated, versioned, platform-labeled record in the maintainer verification record naming commands, observed fields, and what it does not prove.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After the change, none of the six stale statements remains in any touched file: macOS-only, no version marker, no native busy signal, Escape as the only missing key and attributed to Orca, trust shape unverified, and only the older terminal shape verified.
- **SC-002**: A reader answers each of the seven questions in User Story 1 correctly from the Orca backend document alone.
- **SC-003**: The Linux headless 1.4.261 entry and the macOS 1.4.116 entry are both present in the verification record, each with a date, a version, and a platform label.
- **SC-004**: The documentation audience check, the repository lint, and every test in the existing Orca, control, and documentation suites pass unchanged, and the diff touches no executable line.
- **SC-005**: Re-reading every changed claim against the evaluation report's appendix and the code finds zero claims that the evidence does not support.
- **SC-006**: The recovery skill gains one line and no other change, and the capability matrix is byte-identical.

## Assumptions

- The evaluation report in the live firstmate home is the authoritative source of the 2026-11-17 observations, and the worker confirms what it can with read-only Orca status commands and leaves every Orca terminal, worktree, and running worker untouched.
- The captain's three decisions are exactly those the task states, and the document records them as the current operating posture, not as permanent product limits.
- The statements about startup terminals, leftover branches, and command-line discovery belong to other slices, so this feature records the startup-terminal shape only because the old verified-shape claim is one of the six stale statements, and leaves branches and discovery to the slices that fix them.
- Pointing documentation at the Orca interrupt and relaunch slices by name is unnecessary because their landing is the trigger for revising these statements, and the documents state the current refusal only.
- The project constitution is still the unfilled template, so the Spec-Kit-TDD principle cannot be applied without the captain approving its wording, and this limitation is reported in the convergence record.
