# Data Model: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Date**: 2026-10-26

`bin/fm-pr-merge.sh`'s own header is the authoritative owner of the flag contract and of what the merge accepts.
This file records the shape the design settled on so the runner and the merge tool agree.

## Local CI result file

One JSON object per runner run, written as `local-ci-result.json` in the run's directory.

| Field | Type | Meaning |
| --- | --- | --- |
| `version` | integer `1` | Schema version. Any other value is refused. |
| `head_sha` | string, exactly 40 lowercase hex characters | The full commit the run checked out and proved. |
| `target` | string | The run's target as the caller spelled it (pull request number, branch, or commit). Audit-only. |
| `created_at` | string, ISO 8601 with `Z` | When the run finished. Audit-only. |
| `jobs` | non-empty array of job records | One entry per job the run executed, plus one per aggregate line it printed, in summary order. |

### Job record

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | non-empty string without tab, newline, or carriage return | The forge-facing job name, matching the summary line and therefore the hosted check name. |
| `exit_code` | integer | The job's exit status; `0` means passed. |
| `seconds` | integer, optional | Wall time for the job. Audit-only. |

## Consumer-side validation

The merge tool refuses before any task metadata is recorded when:

- the path is not a readable regular file;
- the document is not a JSON object with `version` 1;
- `head_sha` is not 40 lowercase hex characters;
- `jobs` is missing, not an array, or empty;
- any job record is not an object, its `name` is not a non-empty string of permitted characters, or its `exit_code` is not an integer.

The merge tool then refuses the merge (before any forge read) when any `exit_code` is nonzero, and refuses during verification when `head_sha` differs from the live head, or when a check the forge still requires has no zero-exit job record with exactly that name.

## Derived state in the merge run

| Name | Meaning |
| --- | --- |
| evidence armed | the flag was passed and the file validated |
| evidence head | the file's `head_sha` |
| passing job names | newline-delimited set of `name` values whose `exit_code` is `0` |
| local proof active | armed and evidence head equals the live head read at merge time |
| waived-by-local count | how many checks the evidence actually covered, reported in the verification line |

Nothing here is persisted.
The flag's effect dies with the merge run, and no record of it is written to a project or to the forge.

## Unchanged records

- `state/<task-id>.meta` keeps `pr=`, `pr_head=`, and spawn-generation fields with their current meaning.
- `state/<task-id>.merge-authority` keeps recording `attended` or `away`, resolved from the away-posture record, never from this flag.
