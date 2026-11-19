# Convergence: Orca Branch At Create

Merge readiness: ready for the delivery pipeline.

- Built: `--branch` and `--base-branch` at Orca worktree create, a read-back refusal, an idempotent ship first action with the Orca case stated, a teardown that leaves branch deletion to Orca's safe flag, the base fetch, Orca's refusal reason, and docs and the live record.
- Evidence: twelve suites green after the change, 12 of 12 deliberate mutants killed, lint and the doc audit clean, and the live lab (`passed=61 findings=3`, no new findings).
- Risk: low to medium.
  A ship squash-merged on the forge, whose branch Orca cannot prove merged, now stays in the local repository after cleanup instead of being force-deleted; the remote branch and the PR are unaffected.
  A promoted scout on Orca leaves its Orca-made scout branch to Orca's safe delete and the ship branch to the same rule.
- Remaining: Orca's numeric-suffix rename of a taken name is pinned against a fake only; scout and secondmate worktrees still get an Orca-made branch (out of scope).
