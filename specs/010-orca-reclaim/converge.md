# Convergence: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

Merge readiness: ready for the delivery pipeline.

- Built: a close that reads the runtime's receipt, an Orca absence proof, and a close-and-recreate reclaim in `bin/backends/orca.sh`; Orca admitted to the stop-proving table and `--close-terminal` in the control plane; the Orca identity, reclaim, and abort handling in `bin/fm-spawn.sh --relaunch`; a stateful fake Orca for the tests; docs, the recovery skill line, and the dated lab record.
- Evidence: the new unit tests and the affected suites green after the change, 21 of 21 deliberate mutants killed, lint and the doc audit clean, and the live lab (`passed=67 findings=3`, nothing left behind) proving a killed harness, a closed terminal, and a wedged agent each recovered with one terminal, zero stray processes, and the worktree intact, with teardown still refusing unlanded work.
- Risk: moderate.
  Orca tasks that could not be recovered before now can, so a wrong `dead` or `missing` reading is the failure that matters; both are proven from the runtime's own answer plus the local process table, a non-local runtime is never proven, and the close receipt is never trusted without the confirmation wait.
  `fm-control exit` on an Orca agent that reads `alive` refuses rather than typing the harness exit command, which differs from tmux and Herdr and is deliberate.
- Remaining: a real-harness turn (needs a throwaway login), macOS and any host without a process table (a closed terminal rests on the runtime's answer alone there), a runtime on a paired remote host (refused), activating a staged Orca build, and moving long ships back to Orca, which waits on the real-harness smoke.
