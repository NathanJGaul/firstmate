# Quickstart: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Date**: 2026-10-26

## What a person does

1. Run the local CI runner against the pull request whose hosted checks cannot report.
   The runner writes `local-ci-result.json` into its run directory and prints the path at the end of the summary.
2. Read the summary.
   Only a run whose every line says `PASS` for a full job set can carry a merge.
3. Get the captain's explicit merge word for that pull request.
4. Merge with the evidence file:

```sh
bin/fm-pr-merge.sh <task-id> <pr-url> --local-ci-result <run-dir>/local-ci-result.json
```

The merge tool refuses when the file's head is not the pull request's current head, when any job failed, when a check the forge still needs has no passing job of that name, when the away-posture record exists, or when the file cannot be read.
On success it records `pr=` and the landed merge exactly as any other merge does, and it writes nothing to GitHub besides the merge.

## What the tests drive

```sh
bin/fm-test-run.sh tests/fm-pr-merge.test.sh
```

The new cases cover the acceptance path and each refusal path: away record, failed job, uncovered check, head mismatch, and unusable file.
Each case runs the real merge script against fixture forge binaries and asserts both the exit status and that no merge command reached the forge on a refusal.

## What this feature does not do

- It grants no standing merge authority: each merge still needs the captain's word.
- It writes no commit status, check run, comment, or label to any forge.
- It does not change the per-name `--allow-red`/`--allow-missing` waivers, the auto-mode classifier, or branch protection.
- It does not change GitLab behavior; the flag refuses there.
