# OMP Calm extension contract

## Factory

`.omp/extensions/fm-calm.ts` exports one default factory accepted by OMP's native extension loader.

## Command

`/calm` toggles the factory-local active state and persists the resulting choice to the shared `config/calm` path.

- active: write `on\n`;
- inactive: write `off\n`;
- write failure: leave the current state unchanged and notify the operator, or emit the notification adapter diagnostic when that seam is unavailable;
- successful toggle: update the factory-local presentation choice without starting a model turn; invalidate mounted supported synthetic components and let newly rendered or host-remounted entries use the new choice.

## Lifecycle

- `session_start`: reread the shared preference, retaining the last known choice and emitting one bounded diagnostic if a non-missing read fails; reset animation state and restore the default working message only when Calm owns it.
- `agent_start`: if active, start the one managed working-message timer.
- terminal `agent_end` (an event without `willContinue: true`) and `session_shutdown`: restore OMP's default working message only when Calm owns it, then clear the timer while retaining its handle and owning run until clearing succeeds; failed stock writes remain retryable through the managed callback or a later lifecycle or toggle path, and a new agent start remains the active logical run through deferred cleanup, continuing events, and presentation-only toggles within the same session.

## Diagnostics

Each unavailable adapter reports its own name and missing OMP method. A temporarily unavailable working-message or timer seam is retried on a later presentation attempt. An unavailable adapter never prevents command registration, preference handling, or unaffected adapters from loading.
