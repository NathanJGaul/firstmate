# Quickstart: validating Orca fleet plumbing

Prerequisites: a checkout of this branch, `bash`, `node`, `git`, `jq`, and `tmux`; no Orca install is needed because the tests use a fake `orca` on the path.

1. Bootstrap: `bin/fm-test-run.sh tests/fm-bootstrap.test.sh`.
2. Launch environment on Orca: `bin/fm-test-run.sh tests/fm-spawn-orca-worktree.test.sh`.
3. Wake naming: `bin/fm-test-run.sh tests/fm-watch-triage.test.sh` and `bin/fm-test-run.sh tests/fm-daemon.test.sh`.
4. Lint and docs: `bin/fm-lint.sh` and `bin/fm-doc-audience-check.sh`.

What this proves: firstmate's side only.
Live proof against a real Orca runtime needs the Linux Orca lab from a later slice.
