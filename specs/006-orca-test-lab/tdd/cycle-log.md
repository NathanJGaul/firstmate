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

## Cycle 2 - own-runtime proof and signal guard (A4, U8, U9)

Deviation: A4, U8, and U9 share one cycle (one proof, one signal helper); the red is the first failing assertion.

- test: `tests/fm-backend-orca-lab-guard.test.sh` process cluster, with fake runtimes that are plain `sleep` processes carrying `ORCA_USER_DATA_PATH` and a fake launcher answering `status --json`
- red command: `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh`
- red output: `orca_lab_assert_own_runtime: command not found` then `not ok - A4: the lab's own runtime must pass the proof`
  The refusal-direction checks pass vacuously while the function is missing, so the green-path assertion is the decisive red.
- green: `orca_lab_pid_owned`, `orca_lab_assert_own_runtime`, `orca_lab_signal` in `tests/orca-lab-safety.sh`
- deliberate mutants, all killed: dropping the `/proc` readability refusal (U8 other-environment case), dropping the runtime-id comparison (U8 id mismatch), dropping the record-pid comparison (U8 other pid).
  Dropping the self-pid exclusion survived because a plain shell never owns the lab directory; a case was added where a shell whose environment names the lab directory attempts a self-signal, and the mutant is then killed.
- refactor: none needed
