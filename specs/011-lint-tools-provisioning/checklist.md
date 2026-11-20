# Quality Checklist: Pinned Lint Tools Visible to the No-Mistakes Pipeline

- [X] Every behavior test was seen failing for the right reason before its implementation, with the stated exceptions (`tdd/cycle-log.md`, `tdd/verification.md`).
- [X] The lint entry points resolve ShellCheck and actionlint from the managed directory when it holds the pin, then from the search path (A1, A2).
- [X] Version enforcement is unchanged and refuses an off-pin tool wherever it was found (A3).
- [X] One library owns the managed directory; both entry points and both installers use it (U1-U6).
- [X] Provisioning is idempotent, checksum-verified through the existing installers, and offers a read-only `--check` (A4-A7, U7, U8).
- [X] Nothing starts, stops, updates, or reconfigures the no-mistakes daemon (U9, the real-tool proof).
- [X] The missing-tool message names the provisioning command and the managed directory (A8).
- [X] Existing missing-tool tests no longer depend on the machine's provisioning state (U10, U11).
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0 and actionlint 1.7.12 for the changed files; `bin/fm-doc-audience-check.sh` passes.
- [X] `CONTRIBUTING.md`, `docs/configuration.md`, the script headers, and the installers' usage text are updated.
- [X] The real installers and entry points were exercised from `env -i` with the daemon's own search path and a temporary home, and nothing was installed into the operator's real home.
