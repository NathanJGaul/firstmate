# Convergence: Orca Endpoint Presence

Merge readiness: ready for the delivery pipeline.

- Built: a single-read endpoint state in `bin/backends/orca.sh`, the Orca arms of `fm_backend_target_exists` and `fm_backend_agent_state`, one-read crew-state handling, docs, and the live record.
- Evidence: four suites green after the change, 12 of 12 deliberate mutants killed, lint and the doc audit clean, and the live lab (`passed=44 findings=5`, no new findings).
- Risk: low. A terminal that is connected but not writable now reads unreadable instead of present, which only affects the digest's `endpoint:` line and crew state wording.
  The watcher now sees `missing` for a dead Orca terminal and stops typing into it, which is the intended recovery behavior.
- Remaining: the process classifier (`dead` and `alive` for a live terminal) and any reclaim are later slices; a terminal on a paired remote runtime is unproven.
