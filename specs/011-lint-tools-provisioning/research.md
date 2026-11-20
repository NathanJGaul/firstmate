# Research: Pinned Lint Tools Visible to the No-Mistakes Pipeline

## Where the pipeline runs lint

Decision: the daemon runs `commands.lint` itself, as the operator's user, with the daemon's process environment.

Evidence: the daemon process (`no-mistakes daemon run`) environment holds the operator's `HOME` and a fixed `PATH` of `~/.local/bin`, `~/go/bin`, `~/.cargo/bin`, `~/bin`, Homebrew and system directories, with no version-manager shims.
Of 176 recorded run directories under the daemon's log directory, 25 `lint.log` files contain `fm-lint.sh: ShellCheck not found; install ShellCheck 0.11.0 ...`, and the same lines repeat across the agent fix rounds that follow.
CI installs both tools per job with the checksum-verified installers into `$RUNNER_TEMP/bin` and puts that on the path.

## Options

1. Install the pinned binaries into a daemon search-path directory such as `~/.local/bin`.
   Rejected as the owner of the location: it is outside the repo's control, shadows a user's own ShellCheck, and the lint entry points would still fail on any other home layout.
2. Change the daemon's environment or configuration.
   Rejected: the daemon is shared by every lane and may not be restarted or changed.
3. Per-run download from inside lint.
   Rejected: network and side effects inside a gate step, and a failure mode in an offline sandbox.
4. Managed per-user directory that the lint entry points fall back to, provisioned by the existing pinned installers.
   Chosen: no daemon change, one owner, checksum-pinned, repeatable, and invisible to CI.

## Directory choice

`${XDG_CACHE_HOME:-$HOME/.cache}/firstmate/lint-tools` is per-user, reachable through the daemon's own `HOME`, and disposable.
