# Convergence: Orca Local Process Classifier

Merge readiness: ready for the delivery pipeline.

- Built: a local process scan and classification in `bin/backends/orca.sh`, the extended Orca verdict, header updates, docs, and the live record.
- Evidence: the new unit tests plus the affected suites green after the change, 16 of 16 deliberate mutants killed, lint and the doc audit clean, and the live lab with a real binary named `claude`.
- Risk: low to moderate.
  An Orca worker whose harness no classifier recognizes now reads `ambiguous` instead of `unverified`, so `fm-control interrupt` refuses it as it already does on tmux and Herdr.
  The watcher now sees `dead` for a present terminal with only shells and reports it instead of treating the pane as unverified, which is the intended recovery signal; nothing acts on it automatically.
- Remaining: `exit`, `relaunch`, and reclaim on Orca (a later slice), macOS and any host without `/proc`, and a runtime on a paired remote host, all of which read `unverified`.
