# Cycle Log: Orca Live Test Lab

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` and `bin/fm-test-run.sh --check-coverage`: run before the first cycle, results below.
- full profile suite: not run here, left to CI
- commit: `48a6d07b`

## Cycle 1 - path guards (A1, A2, A3, U1-U7)

Deviation: A1-A3 and U1-U7 share one cycle because they are one function and one test file; the red below is the first failing assertion of that file, not seven separate reds.

- test: `tests/fm-backend-orca-lab-guard.test.sh` (cases A1, A2, A3 with U1-U7 labels)
- red command: `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh`
- red output: `tests/orca-lab-safety.sh: No such file or directory` then `not ok - lane without the opt-in variable: expected exit 0, got 127`
- green: `tests/orca-lab-safety.sh` (`orca_lab_resolve`, `orca_lab_validate_data_dir`) and the gate-only `tests/fm-backend-orca-smoke.test.sh`; all four `ok` lines pass.
- deliberate mutants: dropping the non-empty rule is killed (`not ok - U3 the filesystem root contains ~/.orca`); dropping the equal and inside arms is killed (U1, U2).
  The first run exposed a real defect: `/` was refused only by the non-empty rule because the containment comparison built `//*`; fixed with `${real%/}` before the cycle was recorded green.
  Dropping the containment arm survives and is an equivalent mutant: a path that contains an existing protected path is always non-empty, so the non-empty rule refuses it too; the arm stays as defense in depth.
- refactor: none needed
