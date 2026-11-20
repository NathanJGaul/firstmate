# Analysis: Code Mode Scout Pilot

Checked the implementation against `spec.md`, `plan.md`, and `tasks.md`.

- Spec to plan: every requirement maps to a design step; FR-008 (engine) and FR-009 (no inheritance) are the two the report did not spell out and the plan adds them explicitly.
- Plan to code: the library, the spawn splice, the header, the engine unset, the golden-assertion updates, and the runner registration are all present.
- Spec to tests: see the coverage table in `tdd/verification.md`; no requirement lacks a test except the live E2E scenarios, which are opt-in by design.
- One deliberate divergence from the brief's literal wording: the brief says the supervision engine gets an `env -u` prefix, and the implementation unsets the variable in the engine's subshell instead, which has the same effect without changing the engine's argv or the bounded process's recorded identity.
- One addition beyond the brief, taken from the report's section 7: a scout stays out of Code Mode under `claude-permission-mode=auto`, with a one-line reason, because the classifier would review code rather than calls.
- Raw launch commands are left untouched, matching how the other launch knobs treat them; a captain who writes a raw claude command owns its environment.
