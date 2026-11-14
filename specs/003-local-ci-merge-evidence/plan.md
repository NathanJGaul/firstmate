# Implementation Plan: Local CI Merge Evidence

**Branch**: `fm/firstmate-local-ci-merge-evidence` | **Date**: 2026-10-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-local-ci-merge-evidence/spec.md`

## Summary

Add option C of the local-CI report: a head-bound, attended, local-evidence flag in `bin/fm-pr-merge.sh`, plus the result-file emission in the private runner `data/pricing-sheet-local-ci/local-ci.sh`.
The flag consumes a runner result file that records the run's full head commit and each job's exit code, refuses on any failed job, on any head mismatch against the live pull request, and on any check the file does not cover, and is refused while the away-posture record exists.
It writes nothing to the forge.
The change is one production script plus one private runner file, colocated tests in `tests/fm-pr-merge.test.sh`, and the maintained prose that names the attended merge waivers.

## Technical Context

**Language/Version**: Bash 5.3 locally and 5.2 on CI runners; `jq` for JSON reading.

**Primary Dependencies**: `gh`/`glab` (forge CLI), `jq`, `bin/fm-afk-contract.sh` (away record), `bin/fm-lease-lib.sh` (actor partition), `bin/fm-merge-authority-lib.sh` (authority record).

**Storage**: Files only.
The runner result file is the new artifact; no state schema changes in firstmate.

**Testing**: Executable Bash tests in `tests/fm-pr-merge.test.sh` through `bin/fm-test-run.sh`; lint through `bin/fm-lint.sh` (shellcheck plus the repo lint definition).

**Target Platform**: Operator machines running firstmate, any supported harness.

**Project Type**: CLI scripts.

**Performance Goals**: None; the flag adds one file read and a few name comparisons per merge.

**Constraints**: One sentence per line in tracked Markdown, plain dash, `bin/*.sh` shellcheck-clean, no agent co-author, no duplicate contract statements.

**Scale/Scope**: `bin/fm-pr-merge.sh`, the private runner, `tests/fm-pr-merge.test.sh`, and three maintained prose mentions.

## Constitution Check

The project constitution is still the unfilled template, so there are no ratified gates to evaluate.
The Spec-Kit workflow's TDD principle applies by instruction: every behavior change is driven by a test that failed first and recorded in `tdd/cycle-log.md`; tests are never weakened, skipped, or deleted; refactoring happens only on green; test strength is shown by deliberate mutants because no mutation tool is installed.
Result: pass, with the TDD rules adopted as the working gate.

## Project Structure

### Documentation (this feature)

```text
specs/003-local-ci-merge-evidence/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
├── checklist.md
├── analyze.md
├── converge.md
├── checklists/requirements.md
└── tdd/{test-list.md,cycle-log.md,verification.md}
```

### Source Code (repository root)

```text
bin/fm-pr-merge.sh            # the flag, its validation, and the waiver logic
tests/fm-pr-merge.test.sh     # acceptance and refusal coverage, colocated
docs/pi-supervision-branch.md # attended-waiver prose kept accurate
.agents/skills/afk/SKILL.md   # attended-waiver prose kept accurate
docs/scripts.md               # one-line script caption kept accurate
```

Private home state outside the worktree, authorized by the task brief for this one file:

```text
data/pricing-sheet-local-ci/local-ci.sh   # result-file emission
```

## Design decisions

### Where the waiver decision lives

`github_verify_mergeable` already reads the live pull request, computes the not-green check set, and computes required-but-unreported names.
Both loops are the exact place a check becomes a refusal, so both loops consult the local evidence the same way `--allow-red` already does, and nothing else in the merge path learns about the flag.
This keeps the flag from becoming a second gate: the head-bound merge, the away re-read under the record lock, the post-merge read-back, and the outcome record all stay untouched.

### Head binding is one comparison

The evidence is parsed once, before any state is recorded, and its head is compared to the live head inside the verification function, where the live head actually exists.
A mismatch is a refusal, never a silent "grants nothing", because an operator who passed the flag asked for a local-proof merge and a merge that quietly falls back to hosted checks is not the merge they asked for.

### Refusal classification

- An unusable file (unreadable, not valid structure, no jobs) is a usage error: exit 2, before metadata recording.
- A recorded failed job is an evidence refusal: exit 1, before any forge read.
- A head mismatch or an uncovered check joins the existing refusal list and exits 1 with the rest of them, so every failing condition is still reported together.

### Why GitLab refuses

A GitLab merge already requires the head pipeline to have succeeded, and the existing per-name waivers refuse there for the same reason.
Local evidence cannot stand in for a GitLab pipeline, so the flag refuses there and says so rather than pretending to waive.

### Runner emission

The runner already builds an ordered job list (`ORDER`/`NAMES`) and per-job result files under `$LOGS/../results`.
The emission reuses those, appends the aggregate entries it prints, and writes `local-ci-result.json` into the run directory, so the file records exactly what the summary recorded and nothing more.
Names are validated against tab, newline, and carriage return on the consuming side, because the file is line-oriented evidence and a name that could forge a line must not be accepted.

## Complexity Tracking

No constitution gates are ratified, so no deviation needs justification.
The only complexity added is one optional flag and one output file; both are opt-in and inert when unused.
