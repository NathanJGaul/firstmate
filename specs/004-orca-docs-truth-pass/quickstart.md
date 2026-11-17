# Quickstart: Orca Documentation Truth Pass

Run from the repository root in the task worktree.

1. Claim audit: run `specs/004-orca-docs-truth-pass/tdd/claim-audit.sh all`, described in `contracts/claim-audit.md`; expect C1, C2, and C3 to pass after the edits and to fail on the base commit.
2. Structure: `bin/fm-doc-audience-check.sh` and `bin/fm-test-run.sh tests/fm-documentation-audiences.test.sh`.
3. Behavior unchanged: `bin/fm-test-run.sh tests/fm-claude-trust.test.sh tests/fm-backend-orca.test.sh tests/fm-control.test.sh tests/fm-backend.test.sh`.
4. Lint: `bin/fm-lint.sh`.
5. Comment-only: `git diff origin/main -- bin/fm-claude-trust.sh` shows only comment lines.
6. Appendix re-read: walk the rows of `data-model.md` and confirm each new statement against its evidence column.
