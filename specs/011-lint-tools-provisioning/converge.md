# Convergence: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Merge readiness: ready for the delivery pipeline.

- Built: `bin/fm-lint-tools-lib.sh` owning the managed per-user tool directory and the lookup order; both lint entry points resolving through it; both pinned installers defaulting their destination to it; `bin/fm-install-lint-tools.sh` provisioning both pinned tools idempotently with a read-only `--check`; the missing-tool messages naming that command; contributor and gate-default documentation.
- Evidence: the new suite and the affected suites green, 9 of 9 deliberate mutants killed, lint and the doc audit clean, and the real installers plus entry points proven from `env -i` with the daemon's own search path and a temporary home.
- Root cause: the daemon's fixed search path never contained the builds that workers and CI stage on their own `PATH`; 25 of 176 recorded runs stopped their lint step on "ShellCheck not found".
- Risk: low.
  The search path still wins, version enforcement is unchanged, and nothing touches the daemon.
- Remaining: the managed directory on the daemon's machine stays empty until `bin/fm-install-lint-tools.sh` is run there once, which is an operator step and was deliberately not run against the real home; a host with a different home for the daemon than for workers would need `FM_LINT_TOOLS_DIR` in the lint command's environment.
- `tests/fm-lint.test.sh` took about 25 minutes per full run under this host's load; no behavior of that suite changed apart from the guarded RSS assertion and the added library copies.
