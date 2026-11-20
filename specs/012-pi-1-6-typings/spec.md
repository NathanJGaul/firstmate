# Feature Specification: Pi extensions typecheck on every supported Pi release

## Problem

CI installs the Pi package unpinned.
Pi 1.6.0 types `UserMessageComponent.render` as returning `readonly string[]`, while Pi 1.5.2 returns `string[]`.
The Calm operational-user layout adapter returned the base result directly from an override typed `string[]`, so `tests/fm-pi-primary-types.test.sh` fails with TS4104 on 1.6.0 and every pull request is red.

## User Story 1 - The Pi typecheck passes on 1.5.2 and 1.6.0 (P1)

**Acceptance**

- A1: With Pi 1.5.2 installed, `tests/fm-pi-primary-types.test.sh` passes.
- A2: With Pi 1.6.0 installed, the same script passes.
- A3: The fix introduces no cast that hides a mutation of the base class result.

## Out of scope

- Pinning the Pi package in CI.
  The repository pins only lint tools whose output must be deterministic.
  The Pi typecheck exists to detect upstream drift, and a pin would hide it until someone bumps the pin by hand.
