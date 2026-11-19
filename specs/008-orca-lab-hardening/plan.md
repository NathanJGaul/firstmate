# Plan: Orca Live Lab Hardening

## Shape

All guard logic lives in `tests/orca-lab-safety.sh`, the single owner of the lab's hard guards, and is proven by `tests/fm-backend-orca-lab-guard.test.sh` without Orca.
`tests/fm-backend-orca-smoke.test.sh` passes the lab home to the launcher, starts the runtime with the guarded `PATH`, and asserts the hook config paths live.
`docs/verification/runtime-backends.md` carries the dated record (tier 5 of the placement tree: active reusable verification).

## Decisions

- Home validation reuses the data-directory resolution and freshness rules, with a home-specific protected list: the operator's `HOME` itself (equal or containing), the Orca directories, and the known agent config directories under it.
  A home that merely lies elsewhere inside the operator's `HOME`, such as a temp directory, stays allowed.
- The runtime `PATH` is built, not filtered: fake-bin, `/usr/bin`, `/bin`.
  The check still runs on the built value so a host whose `/usr/bin` ships an agent binary refuses rather than runs it.
- The agent name list is a plain list in the safety library; a miss is a false accept, so it is generous.
- The launcher unsets agent config pointers as defense in depth.
  Only the `HOME` pin is the verified requirement from the scout.
- Inherited-handle trace is done from `/proc` ancestry of this worker and the task meta, and recorded as a dated observation.

## Files

`tests/orca-lab-safety.sh`, `tests/fm-backend-orca-lab-guard.test.sh`, `tests/fm-backend-orca-smoke.test.sh`, `docs/verification/runtime-backends.md`, `specs/008-orca-lab-hardening/`.

## Compatibility review

Delivery mode, harness and runtime backend axes: test-only change to an opt-in lane plus a verification record; no `bin/` script, harness adapter, or runtime backend behavior changes.
