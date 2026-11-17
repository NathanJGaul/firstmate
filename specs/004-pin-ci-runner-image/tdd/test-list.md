---
feature: 004-pin-ci-runner-image
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
suite_baseline: red
---

# TDD Test List: Pin the CI Runner Image

Baseline note: main's hosted suite is red by definition of this feature.
Each failing script was reproduced alone in a container instead of running the whole suite, which takes about 15 minutes per shard on hosted runners across sixteen shards.
Traces use `US<story>.<scenario>` for acceptance scenarios and `FR-nnn` for functional requirements in `spec.md`.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | runner | state | test |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | Every Linux job in `ci.yml` names a pinned `ubuntu-NN.NN` runner and the test names each job that does not | US1.1, US1.2, US1.3, FR-001, FR-002 | example | `bin/fm-test-run.sh tests/fm-ci-workflow.test.sh` | DONE | `tests/fm-ci-workflow.test.sh::test_linux_jobs_pin_a_runner_image` |
| A2 | The queued-operational-rows case builds a fake host Pi 1.5.2 can update and reaches its assertions | US2.1, US2.2, FR-005 | example | `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh` in a Pi 1.5.2 container | DONE | `tests/fm-calm-pi-extension.test.sh` queued-operational-rows case |

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | A floating `ubuntu-latest` label on a Linux job is reported by job name | FR-002, A1 | example | DONE | `tests/fm-ci-workflow.test.sh` (mutant: floating label restored on one job) |
| U2 | A non-Ubuntu runner label is ignored by the guard | US1.3 | example | DONE | `tests/fm-ci-workflow.test.sh` (macOS job stays unpinned and green) |

## Not covered by a test (stated reasons)

- FR-003 and FR-004 are prose in a workflow comment and a documentation line; `bin/fm-doc-audience-check.sh` and review cover them, and asserting their bytes is forbidden.
- SC-003 (hosted checks on the delivery PR) is observed on the hosted run itself.
