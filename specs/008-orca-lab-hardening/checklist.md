# Checklist: Orca Live Lab Hardening

- [x] The launcher cannot be written without a safe fresh lab home, and exports it (guard test, `L1`).
- [x] Agent-config pointers are removed before the CLI runs (guard test, `L1`).
- [x] The runtime PATH is built, not inherited, and an agent on it is refused (guard test, `L1`).
- [x] The live lane proves the HOME pin through `agent hooks status --json` (live run, `H1`).
- [x] The boot probe and the inherited-handle trace are recorded with date, version, and re-check commands (`docs/verification/runtime-backends.md`).
- [x] `bin/fm-lint.sh` is clean for the three changed shell files, and `bin/fm-doc-audience-check.sh` passes.
- [x] No `bin/` script, adapter, backend, or staged Orca build is touched.
- [x] Docs use one sentence per line, plain dashes, and no direct address.
