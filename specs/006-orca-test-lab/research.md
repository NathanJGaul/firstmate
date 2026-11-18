# Research: Orca Live Test Lab

All shapes below were observed on 2026-11-18 against the Orca 1.4.261 headless runtime started on a scratch data directory.

- **Decision**: start `orcad.js` directly with the bundled node. **Rationale**: `orca serve` through the remote-install command-line entry refuses with `runtime_serve_failed` because it is not an installed app. **Alternatives**: `ORCA_APP_EXECUTABLE` (no app installed on this host).
- **Decision**: a lab-owned launcher. **Rationale**: the shim Orca writes exports the operator's data directory unconditionally. **Alternatives**: calling the shim with an environment override (silently ignored).
- **Decision**: give the runtime its own home and set the repository worktree base path. **Rationale**: without it a worktree was created under the operator's default workspace root. **Alternatives**: base path alone (leaves tool configuration writes to the real home).
- **Decision**: `terminal list` is the source of the task terminal when `worktree create` returns none. **Rationale**: observed `worktree create --setup skip --no-parent` returns neither a startup terminal nor a terminal, yet one live terminal already exists. **Follow-up**: adapter change, out of scope.
- **Decision**: stop the runtime with SIGTERM, then the terminal host. **Rationale**: the host survives a runtime stop while it holds a terminal, which is also the restart-survival result.
- **Decision**: assertion 11 not run. **Rationale**: the runtime reports browser automation unavailable and a real browser session belongs to the operator's desktop.
