# OMP Calm extension contract

## Factory

`.omp/extensions/fm-calm.ts` exports one default factory accepted by OMP's native extension loader.

## Command

`/calm` toggles the factory-local active state and persists the resulting choice to the shared `config/calm` path.

- active: write `on\n`;
- inactive: write `off\n`;
- write failure: leave the current state unchanged and notify the operator;
- successful toggle: redraw supported presentation surfaces without starting a model turn.

## Lifecycle

- `session_start`: reread the shared preference, reset animation state, install or refresh supported adapters, and clear any prior timer.
- `agent_start`: if active, start the one managed working-message timer.
- `agent_end` and `session_shutdown`: clear the timer and restore OMP's default working message.

## Tool delegation

A built-in tool wrapper copies OMP's `ToolInfo` schema and description, keeps the original name, and calls `ctx.invokeTool` with unchanged params, abort signal, and update callback. Its render methods return the native component while inactive and a zero-height component while active.

## Diagnostics

Each unavailable adapter reports its own name and missing OMP method. An unavailable adapter never prevents command registration, preference handling, working presentation, or other adapters from loading.
