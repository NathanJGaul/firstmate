#!/usr/bin/env bash
# tests/fm-backend-orca-lab-guard.test.sh - portable proof that the Orca live lab
# (tests/fm-backend-orca-smoke.test.sh, guards in tests/orca-lab-safety.sh) can
# never reach an operator's own Orca runtime or Orca data.
#
# No Orca is installed or started here. The protected "operator" Orca data is a
# fake HOME holding .orca and .orca-remote, and the "runtimes" are ordinary
# sleeping processes carrying the environment a real runtime would.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/orca-lab-safety.sh
. "$ROOT/tests/orca-lab-safety.sh"

TMP_ROOT=$(fm_test_tmproot fm-orca-lab-guard)

# The operator's world: every guard decision below is made against this HOME.
REAL_HOME=$HOME
HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.orca" "$HOME/.orca-remote" "$HOME/projects"
export HOME

# --- A1: the lane is opt-in ---------------------------------------------------

out=$(env -u FM_ORCA_LIVE_E2E -u FM_LIVE "$ROOT/tests/fm-backend-orca-smoke.test.sh" 2>&1); rc=$?
expect_code 0 "$rc" "lane without the opt-in variable"
assert_contains "$out" "skip: live: opt-in; set FM_ORCA_LIVE_E2E=1 to run" "lane prints the one-line skip"
out=$(FM_ORCA_LIVE_E2E=0 "$ROOT/tests/fm-backend-orca-smoke.test.sh" 2>&1); rc=$?
expect_code 0 "$rc" "lane with the opt-in variable set to 0"
assert_contains "$out" "skip: live: disabled by FM_ORCA_LIVE_E2E=0" "lane reports the explicit opt-out"
pass "A1: the lane skips with one line unless FM_ORCA_LIVE_E2E=1"

# --- A2 / U1-U5, U7: protected data directories are refused ------------------

refused() {  # <label> <path>
  local err
  err=$(orca_lab_validate_data_dir "$2" 2>&1) && fail "$1: expected a refusal for '$2'"
  assert_contains "$err" "refus" "$1: the refusal says so"
}
accepted() {  # <label> <path>
  orca_lab_validate_data_dir "$2" >/dev/null 2>&1 || fail "$1: expected '$2' to be accepted"
}

refused "U1 equal to ~/.orca" "$HOME/.orca"
refused "U1 equal to ~/.orca-remote" "$HOME/.orca-remote"
refused "U2 inside ~/.orca" "$HOME/.orca/lab-data"
refused "U2 deep inside ~/.orca-remote" "$HOME/.orca-remote/a/b"
refused "U3 the home directory contains ~/.orca" "$HOME"
refused "U3 the filesystem root contains ~/.orca" "/"
refused "U3 a trailing-slash spelling of ~/.orca" "$HOME/.orca/"
refused "U3 a dot-dot spelling of ~/.orca" "$HOME/projects/../.orca"
accepted "U4 a sibling sharing only a name prefix" "$HOME/.orca-lab"
ln -s "$HOME/.orca" "$TMP_ROOT/link-to-orca"
refused "U5 a symlink to ~/.orca" "$TMP_ROOT/link-to-orca"
ln -s "$HOME/.orca/inner" "$TMP_ROOT/dangling-into-orca"
refused "U5 a dangling symlink into ~/.orca" "$TMP_ROOT/dangling-into-orca"
refused "U7 an empty path" ""
[ ! -e "$HOME/.orca/lab-data" ] || fail "A2: a refused directory must not be created"
pass "A2: a data directory equal to, inside, containing, or linked to Orca data is refused and nothing is created"

# --- A3 / U6: the directory must be fresh -------------------------------------

mkdir -p "$TMP_ROOT/fresh-empty"
accepted "U6 an empty directory" "$TMP_ROOT/fresh-empty"
accepted "U6 an absent path" "$TMP_ROOT/absent/data"
mkdir -p "$TMP_ROOT/used"; : > "$TMP_ROOT/used/stale.json"
refused "A3 a directory holding one file" "$TMP_ROOT/used"
mkdir -p "$TMP_ROOT/hidden"; : > "$TMP_ROOT/hidden/.hidden"
refused "A3 a directory holding only a dotfile" "$TMP_ROOT/hidden"
pass "A3: a caller-supplied non-empty directory is refused, an absent or empty one is accepted"

echo "ok - guard (path cluster)"
