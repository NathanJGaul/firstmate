#!/usr/bin/env bash
# tests/fm-backend-orca-smoke.test.sh - the opt-in Orca live lab (placeholder
# opened by the guard cycle; the assertions land in later cycles).
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fm_live_gate opt-in FM_ORCA_LIVE_E2E node jq git
