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

# --- A2/A3 through the real entry point: the lane refuses wrong variables ---------

# FM_ORCA_LIVE_E2E=1 with an unsafe or used ORCA_USER_DATA_PATH must refuse before
# anything is discovered, created, or started, even with no Orca installed.
lane_refusal() {  # <label> <ORCA_USER_DATA_PATH>
  local out rc
  out=$(FM_ORCA_LIVE_E2E=1 ORCA_USER_DATA_PATH="$2" "$ROOT/tests/fm-backend-orca-smoke.test.sh" 2>&1); rc=$?
  [ "$rc" -ne 0 ] || fail "$1: the lane must exit non-zero"
  assert_contains "$out" "refus" "$1: the lane says it refused"
  assert_not_contains "$out" "orca_server_ready" "$1: no runtime may have been started"
}
mkdir -p "$TMP_ROOT/used-entry"; : > "$TMP_ROOT/used-entry/stale.json"
lane_refusal "A2 lane with ORCA_USER_DATA_PATH=~/.orca" "$HOME/.orca"
lane_refusal "A2 lane with ORCA_USER_DATA_PATH inside ~/.orca" "$HOME/.orca/x"
lane_refusal "A2 lane with ORCA_USER_DATA_PATH=~" "$HOME"
lane_refusal "A3 lane with a non-empty ORCA_USER_DATA_PATH" "$TMP_ROOT/used-entry"
[ -z "$(find "$HOME/.orca" "$HOME/.orca-remote" -mindepth 1 -print -quit)" ] || fail "A2: a refused lane wrote into the operator's Orca directories"
pass "A2/A3: the lane entry point refuses an unsafe or used ORCA_USER_DATA_PATH before starting anything"

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
mkdir -p "$TMP_ROOT/p"
ln -s ../home/.orca "$TMP_ROOT/p/relative-link"
refused "U12 a relative symlink to ~/.orca" "$TMP_ROOT/p/relative-link"
ln -s p/relative-link "$TMP_ROOT/chain-link"
refused "U12 a chained symlink to ~/.orca" "$TMP_ROOT/chain-link"
ln -s "$HOME" "$TMP_ROOT/home-link"
refused "U12 a path inside ~/.orca reached through a symlink to the home directory" "$TMP_ROOT/home-link/.orca/data"
refused "U12 a dot-dot after a symlink that lands in ~/.orca" "$TMP_ROOT/p/relative-link/../.orca/data"
accepted "U12 a symlinked sibling that does not reach Orca data" "$TMP_ROOT/home-link/projects/lab-data"
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


# --- processes: fake runtimes --------------------------------------------------

if [ ! -r "/proc/$$/environ" ]; then
  echo "skip: process-proof cases need /proc (Linux); the live lane is Linux-only"
  exit 0
fi

SLEEPERS=()
reap_sleepers() {
  local p
  for p in "${SLEEPERS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
  return 0
}
trap 'reap_sleepers; fm_test_cleanup' EXIT

# start_sleeper <data-dir-in-env>: a process carrying a runtime's environment.
start_sleeper() {
  ORCA_USER_DATA_PATH=$1 sleep 120 >/dev/null 2>&1 &
  SLEEPER_PID=$!
  SLEEPERS+=("$SLEEPER_PID")
}

alive() { kill -0 "$1" 2>/dev/null; }

# make_lab <name> <runtime-id>: a lab dir with a launcher that reports <runtime-id>.
make_lab() {
  LAB="$TMP_ROOT/$1"
  LAB_DATA="$LAB/data"
  mkdir -p "$LAB/bin" "$LAB_DATA"
  printf '%s' "$2" > "$LAB/status-id"
  cat > "$LAB/bin/orca" <<SH
#!/usr/bin/env bash
if [ "\$1" = status ]; then
  printf '{"ok":true,"result":{"runtime":{"runtimeId":"%s"}}}' "\$(cat "$LAB/status-id")"
fi
SH
  chmod +x "$LAB/bin/orca"
}
write_record() {  # <pid> <runtime-id>
  printf '{"runtimeId":"%s","pid":%s}' "$2" "$1" > "$LAB_DATA/orca-runtime.json"
}

# --- A4 / U8: the own-runtime proof --------------------------------------------

make_lab own1 rt-own
start_sleeper "$LAB_DATA"; OWN=$SLEEPER_PID
orca_lab_assert_own_runtime "$LAB_DATA" "$OWN" "$LAB/bin/orca" >/dev/null 2>&1 \
  && fail "A4: a missing runtime record must be refused" || true
write_record "$OWN" rt-own
orca_lab_assert_own_runtime "$LAB_DATA" "$OWN" "$LAB/bin/orca" || fail "A4: the lab's own runtime must pass the proof"

write_record "$((OWN + 1))" rt-own
orca_lab_assert_own_runtime "$LAB_DATA" "$OWN" "$LAB/bin/orca" >/dev/null 2>&1 \
  && fail "U8: a record naming a different pid than the started child must be refused" || true

kill "$OWN"; wait "$OWN" 2>/dev/null
write_record "$OWN" rt-own
orca_lab_assert_own_runtime "$LAB_DATA" "$OWN" "$LAB/bin/orca" >/dev/null 2>&1 \
  && fail "U8: a dead pid must be refused" || true

make_lab own2 rt-own
start_sleeper "$TMP_ROOT/some-other-data"; OTHER=$SLEEPER_PID
write_record "$OTHER" rt-own
orca_lab_assert_own_runtime "$LAB_DATA" "$OTHER" "$LAB/bin/orca" >/dev/null 2>&1 \
  && fail "U8: a process whose environment names another data directory must be refused" || true

make_lab own3 rt-own
start_sleeper "$HOME/.orca"; OPERATOR=$SLEEPER_PID
write_record "$OPERATOR" rt-own
orca_lab_assert_own_runtime "$LAB_DATA" "$OPERATOR" "$LAB/bin/orca" >/dev/null 2>&1 \
  && fail "A4: an operator-shaped runtime (environment names ~/.orca) must be refused" || true

make_lab own4 rt-reported
start_sleeper "$LAB_DATA"; OWN4=$SLEEPER_PID
write_record "$OWN4" rt-recorded
orca_lab_assert_own_runtime "$LAB_DATA" "$OWN4" "$LAB/bin/orca" >/dev/null 2>&1 \
  && fail "U8: a status runtime id that differs from the record must be refused" || true
pass "A4/U8: the own-runtime proof refuses a missing record, other pid, dead pid, other environment owner, operator runtime, and id mismatch"

# --- U9: signals only reach proven lab processes -------------------------------

make_lab sig1 rt-sig
start_sleeper "$LAB_DATA"; LABPROC=$SLEEPER_PID
start_sleeper "$TMP_ROOT/not-this-lab"; BYSTANDER=$SLEEPER_PID
start_sleeper "$HOME/.orca"; OPERATOR2=$SLEEPER_PID
for p in "$BYSTANDER" "$OPERATOR2"; do
  orca_lab_signal TERM "$p" "$LAB_DATA" >/dev/null 2>&1 && fail "U9: a signal to non-lab pid $p must be refused"
  alive "$p" || fail "U9: non-lab pid $p must still be running after the refused signal"
done
orca_lab_signal TERM "$$" "$LAB_DATA" >/dev/null 2>&1 && fail "U9: a signal to the test shell itself must be refused"
orca_lab_signal TERM "" "$LAB_DATA" >/dev/null 2>&1 && fail "U9: an empty pid must be refused"
orca_lab_signal TERM "$LABPROC" "$LAB_DATA" || fail "U9: a signal to a proven lab process must be sent"
wait "$LABPROC" 2>/dev/null
alive "$LABPROC" && fail "U9: the proven lab process must have terminated"
# A caller whose own environment names the lab directory (as a lab-spawned shell
# would) must still never signal itself.
self_out=$(ORCA_USER_DATA_PATH=$LAB_DATA bash -c '. "$1"; orca_lab_signal TERM "$$" "$2" && echo SIGNALLED-SELF; echo survived' _ "$ROOT/tests/orca-lab-safety.sh" "$LAB_DATA" 2>&1)
assert_contains "$self_out" "survived" "U9: a lab-environment shell must survive a self-signal attempt"
assert_not_contains "$self_out" "SIGNALLED-SELF" "U9: the self-signal must be refused"
pass "U9: signals reach only processes proven to belong to the lab"


# --- A5 / U10: the launcher pins the data directory ------------------------------

make_lab launch1 rt-l
FAKE_NODE="$LAB/fake-node"
cat > "$FAKE_NODE" <<'SH'
#!/usr/bin/env bash
env | grep '^ORCA_' | sort
printf 'NODE_OPTIONS=%s\n' "${NODE_OPTIONS-unset}"
printf 'ARGS:'; printf ' [%s]' "$@"; printf '\n'
SH
chmod +x "$FAKE_NODE"
orca_lab_write_launcher "$LAB/bin" "$LAB_DATA" "$FAKE_NODE" "$LAB/cli entry/index.js" || fail "A5: writing the launcher must succeed"
[ -x "$LAB/bin/orca" ] || fail "A5: the launcher must be executable"
launched=$(ORCA_USER_DATA_PATH="$HOME/.orca" ORCA_ENVIRONMENT=operator-env ORCA_PAIRING_CODE=pair ORCA_TERMINAL_HANDLE=term_live \
  ORCA_AGENT_HOOK_PORT=1 NODE_OPTIONS=--inspect "$LAB/bin/orca" worktree create --name 'fm-test x' 2>&1)
orca_lines=$(printf '%s\n' "$launched" | grep '^ORCA_')
assert_equals "ORCA_USER_DATA_PATH=$LAB_DATA" "$orca_lines" "U10: the only ORCA_ variable the CLI receives is the lab data directory"
assert_contains "$launched" "NODE_OPTIONS=unset" "U10: NODE_OPTIONS is not passed on"
assert_contains "$launched" "ARGS: [$LAB/cli entry/index.js] [worktree] [create] [--name] [fm-test x]" "A5: the CLI entry and the arguments pass through intact"
pass "A5/U10: the launcher runs the CLI on the lab data directory with no other Orca variable"

# --- A6 / U11: stop terminates the lab's processes and only those -------------------

make_lab stop1 rt-stop
mkdir -p "$LAB_DATA/daemon"
start_sleeper "$LAB_DATA"; RT=$SLEEPER_PID
write_record "$RT" rt-stop
bash -c 'exec -a "daemon --socket $1" sleep 120' _ "$LAB_DATA/daemon/daemon-v1.sock" >/dev/null 2>&1 & DAEMON=$!; SLEEPERS+=("$DAEMON")
printf '{"pid":%s}' "$DAEMON" > "$LAB_DATA/daemon/daemon-v1.pid"
ORCA_USER_DATA_PATH=$LAB_DATA sleep 120 >/dev/null 2>&1 & PTYPROC=$!; SLEEPERS+=("$PTYPROC")
start_sleeper "$TMP_ROOT/bystander-data"; BYSTANDER2=$SLEEPER_PID

found=$(orca_lab_leftovers "$LAB" "$LAB_DATA")
for p in "$RT" "$DAEMON" "$PTYPROC"; do
  case " ${found//$'\n'/ } " in *" $p "*) : ;; *) fail "U11: the leftover scan must list lab process $p (got: $found)" ;; esac
done
case " ${found//$'\n'/ } " in *" $BYSTANDER2 "*) fail "U11: the leftover scan must not list a bystander" ;; esac

orca_lab_stop "$LAB" "$LAB_DATA" "$RT" "$LAB/bin/orca" >/dev/null 2>&1 || fail "A6: stop must succeed when every lab process is provably the lab's"
for p in "$RT" "$DAEMON" "$PTYPROC"; do
  wait "$p" 2>/dev/null
  alive "$p" && fail "A6: lab process $p must have stopped"
done
alive "$BYSTANDER2" || fail "A6: a bystander process must keep running"
[ -z "$(orca_lab_leftovers "$LAB" "$LAB_DATA")" ] || fail "A6: the leftover scan must find nothing after stop"

# A process that names the lab directory but is not provably the lab's own is
# reported and left alone, and stop fails loudly rather than signalling it.
make_lab stop2 rt-stop2
start_sleeper "$LAB_DATA"; RT2=$SLEEPER_PID
write_record "$RT2" rt-stop2
bash -c 'exec -a "named $1" sleep 120' _ "$LAB/scratch/elsewhere" >/dev/null 2>&1 & NAMED=$!; SLEEPERS+=("$NAMED")
if orca_lab_stop "$LAB" "$LAB_DATA" "$RT2" "$LAB/bin/orca" >/dev/null 2>&1; then
  fail "A6: stop must fail when a lab-named process cannot be proven to be the lab's"
fi
alive "$NAMED" || fail "A6: an unproven lab-named process must not be signalled"
pass "A6/U11: stop ends the lab's runtime, terminal host, and terminal processes, leaves bystanders, and refuses to signal what it cannot prove"

echo "ok - guard (launcher and stop cluster)"
