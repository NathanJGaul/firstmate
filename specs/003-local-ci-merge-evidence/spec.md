# Feature Specification: Local CI Merge Evidence

**Feature Branch**: `fm/firstmate-local-ci-merge-evidence`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "Allow local CI checks to take the place of hosted GitHub CI checks while hosted credits are exhausted. Billing will not be fixed: local CI is the standing way to check every project from now on, not only pricing-sheet. The chosen design is option C of the local-CI report (data/pricing-sheet-local-ci/report.md): a new attended flag in the merge tool that accepts a runner result file - recording the head SHA and each job's exit codes - and treats every job as waived when the SHA equals the live PR head and every job passed; refused while an away record exists; no fake statuses written to GitHub. The runner needs to emit that JSON result file. Boundaries already stated: a merge on local proof still needs the captain's explicit merge word per PR, the auto-mode classifier keeps blocking bypass of failed or missing hosted checks unless the captain runs the merge or adds a permission rule, and the existing per-name waivers stay as they are."

## Overview

Hosted GitHub actions cannot run while the account's credits stay exhausted, and the captain has stated billing will not be fixed.
The local CI runner already reproduces every job of a hosted workflow on this machine, but its result can only reach a merge today through one named waiver per check, which does not scale to the nine running names a single workflow reports.
The chosen design (option C of the local-CI report) is a head-bound local-evidence file: the runner records which commit it proved and the exit code of every job, and the merge tool accepts that file as proof for exactly that commit, only when a person runs the merge, and only when nothing is on record as away.
Nothing is written to the forge, so no check on GitHub ever claims a proof the local machine produced.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Merge a locally proven pull request whose hosted checks never ran (Priority: P1)

The captain asks for a pull request to be merged while hosted checks are absent.
A crewmate ran the local CI runner against that pull request's head and every job passed.
Firstmate merges on the captain's word, passing the runner's result file to the merge tool.

**Why this priority**: This is the whole point of the feature.
Without it, no pull request can be merged while hosted checks cannot report.

**Independent Test**: Run the merge tool against a fixture pull request whose checks never reported, with a result file naming that pull request's head and every job passing, and confirm the forge merge runs once and the merge is recorded.

**Acceptance Scenarios**:

1. **Given** a pull request whose hosted checks have not reported and a result file proving its live head with every job passing, **When** an attended merge passes that file, **Then** every unwaived check the forge requires is treated as waived, the merge runs exactly once, and the landed merge is recorded.
2. **Given** a check that is red on the forge and a result file proving that same head with a passing job of that exact name, **When** an attended merge passes that file, **Then** the red check is waived and the merge proceeds.
3. **Given** a result file proving the head and every job passing, **When** the merge runs, **Then** no commit status, check run, comment, or other artifact is written to the forge by this feature, and the only forge write is the merge itself.

---

### User Story 2 - Refuse a merge whose local proof does not stand (Priority: P1)

The captain's merge word must never outrun the evidence.
When the local proof belongs to another commit, records a failed job, or does not cover a check the forge still needs, the merge refuses and says which.

**Why this priority**: A merge on local proof is only honest if the proof is head-bound and complete.
A silent gap here would merge unproven code.

**Independent Test**: Drive the merge tool with each of the three broken proofs against an otherwise mergeable fixture and confirm each refuses with nothing sent to the forge.

**Acceptance Scenarios**:

1. **Given** a result file whose head commit differs from the pull request's live head, **When** the merge is attempted, **Then** it refuses and names both commits.
2. **Given** a result file with any job recorded as a nonzero exit, **When** the merge is attempted, **Then** it refuses and names the failed jobs.
3. **Given** a red or unreported check whose name has no passing job in the result file, **When** the merge is attempted, **Then** it refuses, names the check, and names it as not covered by the local result.
4. **Given** a result file that cannot be read or does not carry the expected shape, **When** the merge is attempted, **Then** it refuses before any metadata is recorded and before any forge read or merge.

---

### User Story 3 - Local proof stays attended and never autonomous (Priority: P2)

Firstmate supervises a fleet while the captain is away.
No merge may rest on local proof without a person running it.

**Why this priority**: The existing waiver flags are attended-only for exactly this reason, and local proof is the same class of evidence.

**Independent Test**: Publish the away-posture record, run the merge tool with the flag and an otherwise passing proof, and confirm the refusal happens before any forge call.

**Acceptance Scenarios**:

1. **Given** the away-posture record exists, **When** a merge passes a local result file, **Then** the merge refuses and nothing is sent to the forge.
2. **Given** the away-posture record exists and is archived before the merge, **When** a merge passes a local result file, **Then** the merge proceeds as any attended merge does.
3. **Given** a forge whose merge already requires the head pipeline to have succeeded, **When** a merge passes a local result file, **Then** the merge refuses and says the evidence does not apply there.

---

### User Story 4 - The runner emits evidence a merge can consume (Priority: P2)

A crewmate finishes a local run and hands the result to firstmate.
The run itself must produce the machine-readable record, so no one assembles it by hand.

**Why this priority**: Without automated emission the evidence file is a transcription exercise, and a transcription can claim more than the run proved.

**Independent Test**: Run the runner's emission against a run directory and confirm the file names the run's full head commit and one entry per printed job line, including the aggregate lines.

**Acceptance Scenarios**:

1. **Given** a completed runner run, **When** the run ends, **Then** its run directory holds a result file naming the run's full head commit and every job it printed, with that job's exit code.
2. **Given** a run of a subset of jobs, **When** the run ends, **Then** the result file records only the jobs that ran, so a later merge cannot treat unselected jobs as proved.
3. **Given** a run where a job failed, **When** the run ends, **Then** the result file records that job's nonzero exit and the run's own exit status and printed summary are unchanged.

---

### Edge Cases

- A result file proves the live head but the pull request moves after the merge tool reads it: the existing head-bound merge fails the forge call, exactly as for a fully green pull request.
- A result file proves a head that is no longer the pull request's head because a rebase landed: the head comparison refuses on the exact commit, so a rebase voids the proof.
- A result file lists a passing job whose name matches no check on the pull request: it waives nothing, grants nothing, and the merge proceeds on whatever the forge reports.
- Only some of a workflow's jobs were run: the checks those jobs would cover stay unwaived and the merge refuses, naming them.
- The result file carries a job name repeated with different exit codes: the failing entry is what counts, so the merge refuses.
- The same result file is presented for a second pull request whose head is a different commit: the head comparison refuses.
- The result file is a directory, a symlink to nowhere, or unreadable: the merge refuses before any state is recorded.
- An away record is published between the first evidence read and the merge: the existing late away re-read refuses, as it already does for the other waivers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The local CI runner MUST write, into each run's directory, a machine-readable result file recording the run's full head commit and, for every job the run executed and every aggregate line it printed, the job's forge-facing name and numeric exit code.
- **FR-002**: The runner's exit status, printed per-job summary, and log layout MUST keep their current meaning; the result file MUST be additional evidence only.
- **FR-003**: The result file MUST capture the full head commit exactly as the run resolved it, so a truncated or abbreviated commit can never be compared as proof.
- **FR-004**: The merge tool MUST accept one attended flag naming a local result file, accepted at most once per invocation, and MUST refuse the inline-value spelling the tool's sibling waivers refuse.
- **FR-005**: The merge tool MUST treat a check as waivable by local evidence only when the result file's head commit equals the pull request's live head commit read at merge time.
- **FR-006**: The merge tool MUST refuse the merge when the head commits differ, reporting both commits, regardless of how many checks the file covers.
- **FR-007**: The merge tool MUST refuse the merge when any job in the result file carries a nonzero exit code, reporting the failed job names.
- **FR-008**: The merge tool MUST waive a check the forge reports as not green, and a required check that has not reported, only when the result file records a passing job with exactly that check name; every other such check MUST keep its existing refusal, and the refusal MUST also report which checks the result file does not cover.
- **FR-009**: The merge tool MUST refuse the flag while the away-posture record exists, and MUST refuse it for a forge whose merge already requires the head pipeline to have succeeded, saying why it does not apply there.
- **FR-010**: The flag MUST cause no write to the forge other than the merge command itself: no commit status, check run, comment, label, or pull-request edit.
- **FR-011**: The flag MUST NOT weaken any existing gate: the open, non-draft, mergeable, no-conflict, captain-hold, away-authority, head-bound merge, post-merge read-back, and outcome-recording requirements all keep their current behavior, and `--allow-red`/`--allow-missing` keep their current per-name semantics.
- **FR-012**: A result file that is not a readable regular file, is not valid structure, or names no jobs MUST refuse the merge before any task metadata is recorded and before any forge read.
- **FR-013**: Every refusal this feature adds MUST name its concrete cause and MUST leave the merge unperformed, reportable as a distinguishable exit status.
- **FR-014**: The merge tool's own header and usage line MUST remain the single owner of the flag contract, and any maintained prose that names the attended merge waivers MUST stay accurate.

### Key Entities

- **Local CI result file**: one run's proof.
  It carries the run target, the full head commit, a creation time, and an ordered list of job records, and each job record carries the forge-facing job name and its exit code.
- **Waivable check**: a check the forge reports as not green, or a required check the forge requires and no run has reported.
  Its only bridge to local evidence is an exact job-name match with a zero exit code at the pull request's live head.
- **Merge authority posture**: attended or away, resolved at merge time from the away-posture record; local evidence never applies to the away side of that split.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A pull request whose hosted checks never reported merges on a locally proven head in one attended call, and the landed merge is recorded once.
- **SC-002**: Every refusal path this feature adds (away record, failed job, absent job, head mismatch, unusable file) refuses with a message naming its cause, and none of them sends a merge command to the forge.
- **SC-003**: A result file proving an older commit authorizes nothing: after a new commit lands, the same file is refused on the head comparison.
- **SC-004**: Presented evidence produces zero forge writes beyond the merge command, verified from the recorded forge invocations of each case.
- **SC-005**: The repository's lint and the feature's colocated test file pass, and the existing merge test file keeps passing unchanged.

## Assumptions

- The runner lives outside this repository as private home state, so only its result-file emission is in scope here, and the emission is verified by a fixture-level test rather than by running a real project workflow.
- The forge-facing job names the file records are the ones the workflow reports, which is what the existing runner summary already prints.
- Hosted checks that do report keep working exactly as today; the flag only ever adds coverage for names the forge does not prove.
- A merge on local proof still requires the captain's explicit merge word for each pull request; this feature grants no standing merge authority.
- The auto-mode classifier that blocks a bypass of failed or missing hosted checks, and branch-protection settings, are unchanged and out of scope.
