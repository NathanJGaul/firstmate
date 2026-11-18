# Analysis: Orca Adapter Hygiene

Cross-artifact consistency check of spec, plan, tasks, test list, and the code on the branch.

## Coverage

- Every functional requirement FR-001 to FR-009 traces to at least one test in `tdd/test-list.md`, and every listed test exists under that name.
- Every acceptance scenario US1.1-US1.4, US2.1-US2.6, and US3.1-US3.2 has a test, except US1.4 (an unregistered repository is still added), which is covered by the pre-existing `test_worktree_and_terminal_helpers_parse_json` that asserts the `repo add` call.
- Every plan decision D1-D4 is visible in the code: PATH prepend, the added check in `fm_backend_orca_worktree_create`, `orca:orca` routing in `fm-backend.sh`, and a kind check only on the `repo show` path.

## Findings

- No contradiction between spec and implementation.
- The spec's edge case "a newly added repository whose registration result reports `folder`" is deliberately unhandled (plan D4) and stays listed as out of scope.
- The tasks file lists the two extra test-hermeticity edits (`HOME` and `ORCA_CLI_BIN_DIR` pinning, and the herdr base-path fix) as setup and implementation notes; the herdr fix was not in the original plan and is recorded in the cycle log baseline.
- Tasks T001-T020 are all satisfied; the checkbox state in `tasks.md` is updated at convergence.

## Risks

- A real Orca's `repo show` shape for `kind` is unproven live (see checklist known limits).
- `fm_backend_orca_tool_check` mutates the caller's `PATH` for the rest of that shell, by design (plan D1).
  Callers that invoke it inside a command substitution must call it again in their own shell, which the one affected call site now does.
