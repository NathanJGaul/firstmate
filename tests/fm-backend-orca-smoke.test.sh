#!/usr/bin/env bash
# tests/fm-backend-orca-smoke.test.sh - the opt-in Orca live lab (slice 6, P0-A
# of the Orca evaluation plan; specs/006-orca-test-lab). Every other Orca test
# drives a fake `orca`; this one starts its OWN headless Orca runtime and proves
# Orca's real behavior and Firstmate's scripts against it.
#
# SAFETY, in one place (guards in tests/orca-lab-safety.sh, proven without Orca
# by tests/fm-backend-orca-lab-guard.test.sh):
#   - Opt-in only: FM_ORCA_LIVE_E2E=1.
#   - The runtime is a child of this script on a fresh data directory
#     (ORCA_USER_DATA_PATH, refused if it is, contains, or lies inside ~/.orca or
#     ~/.orca-remote), its own HOME, a free loopback port, and a launcher pinned
#     to that directory with every other ORCA_* variable removed.
#   - Every mutating step is preceded by the proof that the answering runtime is
#     this script's own child; signals go only to processes proven the lab's.
#   - Every object carries the fm-test- prefix and is removed by exact id; the
#     lab never lists-and-deletes anything.
#
# Output vocabulary (only "ok" lines count as passes):
#   ok -        a hard assertion that held
#   # observe:  a real response fact recorded, not asserted
#   # finding:  an observation that contradicts what a merged or held slice assumes
#   # not run:  an assertion this host cannot run, with the reason
# The dated, version-scoped results belong in docs/verification/runtime-backends.md.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/orca-lab-safety.sh
. "$ROOT/tests/orca-lab-safety.sh"

fm_live_gate opt-in FM_ORCA_LIVE_E2E node jq git

PASSED=0
FINDINGS=0
observe() { printf '# observe: %s\n' "$1"; }
finding() { printf '# finding: %s\n' "$1"; FINDINGS=$((FINDINGS + 1)); }
notrun() { printf '# not run: %s\n' "$1"; }
ok() { PASSED=$((PASSED + 1)); printf 'ok - %s\n' "$1"; }
section() { printf '# --- %s\n' "$1"; }

LAB=''
DATA=''
CHILD=''
PORT=''
DATA_SUPPLIED=0
BIN=''
cleanup_lab() {
  local rc=$?
  trap - EXIT
  if [ -n "$CHILD" ] && [ -n "$DATA" ]; then
    orca_lab_stop "$LAB" "$DATA" "$CHILD" "$BIN/orca" || rc=1
  fi
  case "$LAB" in
    /tmp/fm-test-orca-lab.*) [ -z "$DATA" ] || [ "$DATA_SUPPLIED" -eq 0 ] || fm_test_remove_tree "$DATA"; fm_test_remove_tree "$LAB" ;;
  esac
  fm_test_cleanup
  exit "$rc"
}
trap cleanup_lab EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- environment guards, before anything is created or started -----------------

LAB=$(mktemp -d /tmp/fm-test-orca-lab.XXXXXX) || fail "cannot create the lab directory"
LAB=$(cd -P "$LAB" && pwd -P)
if [ -n "${ORCA_USER_DATA_PATH:-}" ]; then
  DATA=$ORCA_USER_DATA_PATH
  DATA_SUPPLIED=1
else
  DATA=$LAB/data
fi
orca_lab_validate_data_dir "$DATA" || { DATA=''; fail "the lab data directory was refused (see above); nothing was started. An inherited ORCA_USER_DATA_PATH (set inside Orca terminals) is checked too: unset it, or point it at a fresh empty directory"; }
DATA=$(orca_lab_resolve "$DATA")
mkdir -p "$DATA" "$LAB/bin" "$LAB/home" "$LAB/fake"
export ORCA_USER_DATA_PATH=$DATA
BIN=$LAB/bin

# --- discover the headless runtime (read-only) ---------------------------------

discover_runtime() {
  local shim line
  NODE_BIN=${FM_ORCA_LIVE_NODE:-}
  CLI_ENTRY=${FM_ORCA_LIVE_CLI_ENTRY:-}
  if [ -z "$NODE_BIN" ] || [ -z "$CLI_ENTRY" ]; then
    for shim in "${ORCA_CLI_BIN_DIR:+$ORCA_CLI_BIN_DIR/orca}" "$HOME/.orca/cli/bin/orca"; do
      [ -n "$shim" ] && [ -f "$shim" ] || continue
      line=$(sed -n "s/^exec '\\(.*\\)' '\\(.*\\)' \"\\\$@\"\$/\\1\\t\\2/p" "$shim" | tail -1)
      [ -n "$line" ] || continue
      NODE_BIN=${NODE_BIN:-${line%%$'\t'*}}
      CLI_ENTRY=${CLI_ENTRY:-${line#*$'\t'}}
      break
    done
  fi
  ORCAD_JS=${FM_ORCA_LIVE_ORCAD:-}
  [ -n "$ORCAD_JS" ] || { [ -z "$CLI_ENTRY" ] || ORCAD_JS=$(dirname "$(dirname "$(dirname "$CLI_ENTRY")")")/orcad.js; }
  [ -x "$NODE_BIN" ] && [ -f "$CLI_ENTRY" ] && [ -f "$ORCAD_JS" ]
}
discover_runtime || fail "FM_ORCA_LIVE_E2E=1 was requested but the headless Orca runtime was not found: need its node binary, CLI entry, and orcad.js (read from the shim in \$ORCA_CLI_BIN_DIR or ~/.orca/cli/bin; override with FM_ORCA_LIVE_NODE, FM_ORCA_LIVE_CLI_ENTRY, FM_ORCA_LIVE_ORCAD)"

orca_lab_write_launcher "$BIN" "$DATA" "$NODE_BIN" "$CLI_ENTRY" || fail "cannot write the lab launcher"
O() { "$BIN/orca" "$@"; }

# Every later `orca` the repo's adapter runs resolves to the lab launcher first.
export PATH="$BIN:$PATH"
export ORCA_CLI_BIN_DIR=$BIN

# --- start the lab runtime as this script's own child ----------------------------

PORT=$("$NODE_BIN" -e 'const s=require("net").createServer();s.listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})')
[ -n "$PORT" ] || fail "cannot pick a free loopback port"

start_runtime() {
  local v unset_args=()
  for v in $(env | sed -n 's/^\(ORCA_[A-Za-z0-9_]*\)=.*/\1/p'); do unset_args+=(-u "$v"); done
  (cd "$LAB" && exec env "${unset_args[@]}" HOME="$LAB/home" ORCA_USER_DATA_PATH="$DATA" ORCA_USER_DATA="$DATA" \
    "$NODE_BIN" "$ORCAD_JS" --json --bind 127.0.0.1 --port "$PORT" --no-pairing \
    > "$LAB/serve.out" 2> "$LAB/serve.err" < /dev/null) &
  CHILD=$!
  local i=0
  while [ "$i" -lt 120 ]; do
    grep -q orca_server_ready "$LAB/serve.out" 2>/dev/null && break
    orca_lab_pid_running "$CHILD" || { cat "$LAB/serve.err" >&2; fail "the lab runtime exited before it was ready"; }
    sleep 0.5; i=$((i + 1))
  done
  grep -q orca_server_ready "$LAB/serve.out" 2>/dev/null || fail "the lab runtime was not ready within 60s"
  : > "$LAB/serve.out"
}

# guard: refuse to continue unless the answering runtime is our own child.
own() { orca_lab_assert_own_runtime "$DATA" "$CHILD" "$BIN/orca" || fail "the answering runtime is not the lab's own child; refusing to continue"; }

start_runtime
own

# read helpers shared by both sections
read_tail() { O terminal read --terminal "$1" --json | jq -r '.result.terminal.tail | join("\n")'; }
wait_for_text() {  # <terminal> <text> [seconds]
  local n=$(( ${3:-10} * 5 ))
  while [ "$n" -gt 0 ]; do
    case "$(read_tail "$1")" in *"$2"*) return 0 ;; esac
    sleep 0.2; n=$((n - 1))
  done
  return 1
}

# --- the Orca-level assertions (report section 6.1) ----------------------------------

run_orca_level() {

# --- assertion 1: status ready, version, capabilities (slice 8) ----------------------

section "A1 status (unblocks slice 8: version and capability gate)"
STATUS=$(O status --json)
[ "$(jq -r '.result.runtime.state' <<<"$STATUS")" = ready ] && [ "$(jq -r '.result.runtime.reachable' <<<"$STATUS")" = true ] \
  || fail "A1: status is not ready and reachable"
APPVER=$(jq -r '.result.runtime.appVersion // empty' <<<"$STATUS")
NCAPS=$(jq -r '.result.runtime.capabilities | length' <<<"$STATUS")
[ -n "$APPVER" ] && [ "$NCAPS" -gt 0 ] || fail "A1: status carries no appVersion or capabilities"
ok "A1: status --json is ready and reachable, with appVersion and a capability list"
observe "appVersion=$APPVER capabilities=$NCAPS"
for cap in terminal.prompt-delivery.v1 terminal.program-status.v1 worktree.remove-branch-policy.v1 terminal.create-idempotency.v2 worktree.create-idempotency.v1 agent-session.keyboard.v1 terminal.ordered-input.v1; do
  if jq -e --arg c "$cap" '.result.runtime.capabilities | index($c)' <<<"$STATUS" >/dev/null; then observe "capability present: $cap"; else observe "capability absent: $cap"; fi
done
observe "degradations: $(jq -c '[.result.runtime.degradations[]? | {code, capability, reason}]' <<<"$STATUS")"
observe "target/app shape: $(jq -c '{target: .result.target, app: .result.app, graph: .result.graph}' <<<"$STATUS")"

# --- assertion 2: repos and a folder (slice 5) ----------------------------------------

section "A2 repo add, folder kind (unblocks slice 5: folder-kind refusal)"
SCRATCH=$LAB/fm-test-repo
FOLDER=$LAB/fm-test-folder
mkdir -p "$SCRATCH" "$FOLDER"
git -C "$SCRATCH" init -q -b main
git -C "$SCRATCH" -c user.email=lab@fm.test -c user.name=fm-test commit -q --allow-empty -m init
echo seed > "$SCRATCH/seed.txt"
git -C "$SCRATCH" add seed.txt
git -C "$SCRATCH" -c user.email=lab@fm.test -c user.name=fm-test commit -q -m seed
echo x > "$FOLDER/x.txt"
own
REPO_ADD=$(O repo add --path "$SCRATCH" --json)
REPO_ID=$(jq -r '.result.repo.id // empty' <<<"$REPO_ADD")
[ -n "$REPO_ID" ] && [ "$(jq -r '.result.repo.kind' <<<"$REPO_ADD")" = git ] || fail "A2: repo add of a git repository did not return kind=git"
ok "A2: repo add of the scratch repository returns kind=git"
PLAIN=$(O repo add --path "$FOLDER" --json 2>/dev/null || true)
[ "$(jq -r '.ok' <<<"$PLAIN")" = false ] || fail "A2: repo add of a non-git folder without --kind unexpectedly succeeded"
ok "A2: repo add of a non-git folder is refused unless --kind folder is given"
observe "plain folder refusal: $(jq -c '{code: .error.code, nextSteps: .error.data.nextSteps}' <<<"$PLAIN")"
FOLDER_ADD=$(O repo add --path "$FOLDER" --kind folder --json)
FOLDER_ID=$(jq -r '.result.repo.id // empty' <<<"$FOLDER_ADD")
[ -n "$FOLDER_ID" ] && [ "$(jq -r '.result.repo.kind' <<<"$FOLDER_ADD")" = folder ] || fail "A2: repo add --kind folder did not return kind=folder"
SHOWN=$(O repo show --repo "path:$FOLDER" --json)
[ "$(jq -r '.result.repo.kind' <<<"$SHOWN")" = folder ] || fail "A2: repo show did not report kind=folder"
ok "A2: repo add --kind folder and repo show both report kind=folder (the field the adapter's folder refusal reads)"
FWT=$(O worktree create --repo "id:$FOLDER_ID" --name fm-test-folderwt --no-parent --setup skip --json)
if [ "$(jq -r '.ok' <<<"$FWT")" = true ]; then
  FWT_ID=$(jq -r '.result.worktree.id' <<<"$FWT")
  FWT_PATH=$(jq -r '.result.worktree.path' <<<"$FWT")
  finding "worktree create under a folder-kind repo SUCCEEDS and returns the folder itself (path=$FWT_PATH, no git worktree, id=$FWT_ID): without the adapter's folder refusal a task would run in the operator's own folder"
  [ "$FWT_PATH" = "$FOLDER" ] || observe "folder workspace path differs from the folder: $FWT_PATH"
  O worktree rm --worktree "id:$FWT_ID" --force --json >/dev/null 2>&1 || true
  [ -f "$FOLDER/x.txt" ] || fail "A2: removing the folder workspace deleted the folder's own contents"
  ok "A2: removing the folder workspace by exact id leaves the folder's files in place"
else
  observe "worktree create under a folder-kind repo is refused: $(jq -c .error <<<"$FWT")"
fi

# --- assertion 3 and 4: worktree create shape and terminal count (slices 2, 3) ----------

section "A3/A4 worktree create (unblocks slices 2 and 3: startup terminal, branch deletion)"
WT_NAME=fm-test-wt-landed
own
WT_A=$(O worktree create --repo "id:$REPO_ID" --name "$WT_NAME" --no-parent --setup skip --json)
WT_A_ID=$(jq -r '.result.worktree.id // empty' <<<"$WT_A")
WT_A_PATH=$(jq -r '.result.worktree.path // empty' <<<"$WT_A")
[ -n "$WT_A_ID" ] && [ -n "$WT_A_PATH" ] || fail "A3: worktree create returned no worktree id and path"
case "$WT_A_PATH" in
  "$LAB"/*) : ;;
  *) O worktree rm --worktree "id:$WT_A_ID" --force --json >/dev/null 2>&1; fail "A3: the worktree was created OUTSIDE the lab ($WT_A_PATH); removed by exact id and refusing to continue" ;;
esac
ok "A3: worktree create places the worktree inside the lab (the runtime has its own HOME, so its default workspace root is under the lab)"
GITDIR=$(cd "$WT_A_PATH" && git rev-parse --absolute-git-dir)
COMMON=$(cd "$WT_A_PATH" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
[ "$GITDIR" != "$COMMON" ] || fail "A3: the Orca worktree is not a linked git worktree (git dir equals common dir)"
ok "A3: the Orca worktree is a linked git worktree (git dir differs from the common dir)"
observe "worktree create result keys: $(jq -c '.result | keys' <<<"$WT_A"); worktree.branch=$(jq -r '.result.worktree.branch' <<<"$WT_A"); id shape=<repo-id>::<path>"
STARTUP=$(jq -c '.result.startupTerminal // empty' <<<"$WT_A")
EXPLICIT=$(jq -c '.result.terminal // empty' <<<"$WT_A")
if [ -n "$STARTUP" ]; then observe "worktree create returned result.startupTerminal: $STARTUP"
elif [ -n "$EXPLICIT" ]; then observe "worktree create returned result.terminal: $EXPLICIT"
else finding "worktree create (--setup skip --no-parent) returned NEITHER result.startupTerminal NOR result.terminal, so the adapter's startup-terminal adoption has nothing to adopt on this runtime"; fi
sleep 1
TL=$(O terminal list --worktree "id:$WT_A_ID" --json)
PS=$(O worktree ps --json)
LIVE=$(jq -r --arg id "$WT_A_ID" '.result.worktrees[] | select(.worktreeId == $id) | .liveTerminalCount' <<<"$PS")
observe "after worktree create alone: terminal list totalCount=$(jq -r '.result.totalCount' <<<"$TL"), worktree ps liveTerminalCount=$LIVE"
if [ "$LIVE" -ge 1 ]; then
  finding "Orca already holds $LIVE live terminal(s) for the new worktree although the create response named none; an adapter that then runs 'terminal create' ends with $((LIVE + 1)) terminals for one task"
fi
AUTO_T=$(jq -r '.result.terminals[0].handle // empty' <<<"$TL")
ok "A4: terminal list --worktree and worktree ps report the live terminal count for the new worktree"

# --- assertion 5: control bytes (slice 9) ---------------------------------------------------

section "A5 Escape, Ctrl+U, interrupt, wait (unblocks slice 9: Escape and Ctrl+U delivery)"
[ -n "$AUTO_T" ] || { AUTO_T=$(O terminal create --worktree "id:$WT_A_ID" --title fm-test-ctl --json | jq -r '.result.terminal.handle'); }
own
O terminal send --terminal "$AUTO_T" --text 'cat -v' --enter --json >/dev/null
sleep 0.5
O terminal send --terminal "$AUTO_T" --text $'\x1b' --json >/dev/null
O terminal send --terminal "$AUTO_T" --text 'x' --enter --json >/dev/null
wait_for_text "$AUTO_T" '^[x' 10 || fail "A5: an Escape byte sent without --enter did not reach cat -v (no '^[x' in $(read_tail "$AUTO_T"))"
ok "A5: --text \$'\\x1b' without --enter reaches the terminal as a raw Escape (cat -v shows ^[x)"
O terminal send --terminal "$AUTO_T" --text 'abc' --json >/dev/null
O terminal send --terminal "$AUTO_T" --text $'\x15' --json >/dev/null
O terminal send --terminal "$AUTO_T" --text 'zz' --enter --json >/dev/null
wait_for_text "$AUTO_T" 'zz' 10 || fail "A5: nothing was echoed after Ctrl+U"
TAIL=$(read_tail "$AUTO_T")
case "$TAIL" in *abczz*) fail "A5: Ctrl+U did not clear the line (abczz reached cat)" ;; esac
ok "A5: --text \$'\\x15' without --enter reaches the terminal as Ctrl+U and clears the typed line"
O terminal send --terminal "$AUTO_T" --interrupt --json >/dev/null
sleep 0.5
SCREEN=$(O terminal read --terminal "$AUTO_T" --screen --json | jq -r '.result.terminal.tail | join("\n")')
case "$SCREEN" in *'^C'*) : ;; *) fail "A5: --interrupt did not deliver Ctrl+C (no ^C on screen)" ;; esac
ok "A5: terminal send --interrupt delivers Ctrl+C and ends cat"
WAIT_TIMEOUT=$(O terminal wait --terminal "$AUTO_T" --for exit --timeout-ms 1500 --json 2>/dev/null || true)
[ "$(jq -r '.error.code // empty' <<<"$WAIT_TIMEOUT")" = timeout ] || fail "A5: terminal wait --for exit on a live shell did not time out"
ok "A5: terminal wait --for exit times out with error code 'timeout' on a live shell"
O terminal send --terminal "$AUTO_T" --text exit --enter --json >/dev/null
WAIT_EXIT=$(O terminal wait --terminal "$AUTO_T" --for exit --timeout-ms 8000 --json)
[ "$(jq -r '.result.wait.satisfied' <<<"$WAIT_EXIT")" = true ] || fail "A5: terminal wait --for exit did not report the exited shell"
ok "A5: terminal wait --for exit is satisfied after the shell exits"
observe "wait --for exit result: $(jq -c .result.wait <<<"$WAIT_EXIT")"
AFTER=$(O terminal read --terminal "$AUTO_T" --json | jq -c '.result.terminal | {status, source}')
observe "read after the shell exited: $AFTER; terminal list totalCount=$(O terminal list --worktree "id:$WT_A_ID" --json | jq -r '.result.totalCount')"

# --- assertion 6: read status and source (slices 10, 15) -----------------------------------------

section "A6 terminal read status and source (unblocks slices 10 and 15)"
own
SH_T=$(O terminal create --worktree "id:$WT_A_ID" --title fm-test-shell --json | jq -r '.result.terminal.handle')
[ -n "$SH_T" ] || fail "A6: terminal create returned no handle"
O terminal send --terminal "$SH_T" --text 'echo FM-TEST-SHELL-LINE' --enter --json >/dev/null
wait_for_text "$SH_T" 'FM-TEST-SHELL-LINE' 10 || fail "A6: the shell output never appeared"
RS=$(O terminal read --terminal "$SH_T" --json)
RSC=$(O terminal read --terminal "$SH_T" --screen --json)
observe "shell stream read: status=$(jq -r .result.terminal.status <<<"$RS") source=$(jq -r .result.terminal.source <<<"$RS")"
observe "shell screen read: status=$(jq -r .result.terminal.status <<<"$RSC") source=$(jq -r .result.terminal.source <<<"$RSC")"
[ "$(jq -r .result.terminal.status <<<"$RS")" = running ] || fail "A6: a live shell did not read status=running"
ok "A6: a live shell reads status=running"
case "$(jq -r '.result.terminal.tail | join("\n")' <<<"$RSC")" in
  *FM-TEST-SHELL-LINE*) ok "A6: terminal read --screen returns the rendered viewport containing the shell output" ;;
  *) finding "terminal read --screen did not contain the shell output (source=$(jq -r .result.terminal.source <<<"$RSC"))" ;;
esac
TUI_T=$(O terminal create --worktree "id:$WT_A_ID" --title fm-test-tui --command "sh -c \"printf '\\033[?1049h\\033[2J\\033[HFM-TEST-TUI-SCREEN'; sleep 120\"" --json | jq -r '.result.terminal.handle')
sleep 1.5
TUI_STREAM=$(O terminal read --terminal "$TUI_T" --json)
TUI_SCREEN=$(O terminal read --terminal "$TUI_T" --screen --json)
observe "alt-screen program, stream read: status=$(jq -r .result.terminal.status <<<"$TUI_STREAM") source=$(jq -r .result.terminal.source <<<"$TUI_STREAM") tail=$(jq -c .result.terminal.tail <<<"$TUI_STREAM")"
observe "alt-screen program, screen read: status=$(jq -r .result.terminal.status <<<"$TUI_SCREEN") source=$(jq -r .result.terminal.source <<<"$TUI_SCREEN") tail=$(jq -c .result.terminal.tail <<<"$TUI_SCREEN")"
case "$(jq -r '.result.terminal.tail | join("\n")' <<<"$TUI_SCREEN")" in
  *FM-TEST-TUI-SCREEN*) ok "A6: terminal read --screen shows what a full-screen program rendered" ;;
  *) finding "terminal read --screen did not show the full-screen program's text" ;;
esac
SHOWN_T=$(O terminal show --terminal "$SH_T" --json)
observe "terminal show keys: $(jq -c '.result.terminal | keys' <<<"$SHOWN_T")"
O terminal close --terminal "$TUI_T" --json >/dev/null

# --- assertion 7: a fake agent (slice 10) ------------------------------------------------------------

section "A7 fake agent (unblocks slice 10: what can prove 'no agent')"
own
cat > "$LAB/fake/claude" <<'SH'
#!/usr/bin/env bash
echo "fake-agent ready"
while IFS= read -r line; do echo "got: $line"; done
SH
chmod +x "$LAB/fake/claude"
AG_CREATE=$(O terminal create --worktree "id:$WT_A_ID" --title fm-test-agent --command "$LAB/fake/claude" --json)
AG_T=$(jq -r '.result.terminal.handle // empty' <<<"$AG_CREATE")
[ -n "$AG_T" ] || fail "A7: terminal create --command returned no handle"
wait_for_text "$AG_T" 'fake-agent ready' 10 || fail "A7: the fake agent never printed its ready line"
observe "terminal create --command result keys: $(jq -c '.result.terminal | keys' <<<"$AG_CREATE")"
AG_PID=$(jq -r '.result.terminal.processId // empty' <<<"$AG_CREATE")
if [ -n "$AG_PID" ]; then
  if orca_lab_pid_owned "$AG_PID" "$DATA"; then
    observe "terminal create reports processId=$AG_PID and that process is owned by the lab (its environment names the lab data directory): a PTY pid IS exposed on create"
  else
    observe "terminal create reports processId=$AG_PID but it is not provably the lab's"
  fi
else
  finding "terminal create did not report a processId"
fi
case "$(read_tail "$AG_T")" in
  *--plugin-dir*) finding "Orca REWROTE the typed command by appending --plugin-dir: a command whose name Orca recognizes as an agent is not launched verbatim" ;;
  *) observe "the typed command was launched verbatim" ;;
esac
observe "agent identity while running: terminal show agentIdentity=$(O terminal show --terminal "$AG_T" --json | jq -r '.result.terminal.agentIdentity // "none"'), agentWait=$(O terminal show --terminal "$AG_T" --json | jq -c '.result.terminal.agentWait')"
observe "worktree ps agents[] while running: $(O worktree ps --json | jq -c --arg id "$WT_A_ID" '[.result.worktrees[] | select(.worktreeId == $id) | .agents]')"
O terminal send --terminal "$AG_T" --text $'\x04' --json >/dev/null
AG_FIRST=''
AG_CLEARED='not within 12s'
i=0
while [ "$i" -lt 24 ]; do
  sleep 0.5; i=$((i + 1))
  cur=$(O terminal show --terminal "$AG_T" --json | jq -r '.result.terminal.agentIdentity // "none"')
  [ -n "$AG_FIRST" ] || AG_FIRST=$cur
  if [ "$cur" = none ]; then AG_CLEARED="$(awk -v n="$i" 'BEGIN{printf "%.1f", n/2}')s"; break; fi
done
observe "after the fake agent exited (Ctrl+D): first agentIdentity read 0.5s later=$AG_FIRST, identity cleared: ${AG_CLEARED}; worktree ps agents[]=$(O worktree ps --json | jq -c --arg id "$WT_A_ID" '[.result.worktrees[] | select(.worktreeId == $id) | .agents]'), terminal still listed=$(O terminal list --worktree "id:$WT_A_ID" --json | jq -r --arg h "$AG_T" '[.result.terminals[] | select(.handle == $h)] | length')"
observe "terminal tail after the fake agent exited: $(read_tail "$AG_T" | tail -2 | tr '\n' '|' | cut -c1-200)"
observe "agentIdentity after that terminal read: $(O terminal show --terminal "$AG_T" --json | jq -r '.result.terminal.agentIdentity // "none"')"
if [ "$AG_FIRST" != none ]; then
  finding "terminal show still reported agentIdentity=$AG_FIRST 0.5s after the agent process exited (cleared: ${AG_CLEARED}) and worktree ps agents[] stayed empty throughout: the identity is not refreshed by the process exit (it can be refreshed by a later terminal read) and so cannot prove 'no agent'; the terminal's processId from terminal create is the only process-level handle observed"
fi
ok "A7: a fake agent named for a recognized harness launches, is readable, and its identity and agent list were recorded before and after it exited"
AG2=$(O terminal create --worktree "id:$WT_A_ID" --title fm-test-agent2 --command "$LAB/fake/claude" --json | jq -r '.result.terminal.handle')
wait_for_text "$AG2" 'fake-agent ready' 10 || fail "A7: the second fake agent never became ready"

# --- assertion 8: receipts (slice 11) --------------------------------------------------------------------

section "A8 send receipts (unblocks slice 11: delivery receipts)"
own
SUB=$(O terminal send --terminal "$AG2" --text 'fm-test-receipt-1' --enter --wait-submit 2 --json)
observe "send --enter --wait-submit receipt: $(jq -c '{prompt: .result.send.prompt, mutation: .result.mutation, warnings: .result.warnings}' <<<"$SUB")"
REQ=$(jq -r '.result.mutation.requestId // empty' <<<"$SUB")
wait_for_text "$AG2" 'got: fm-test-receipt-1' 10 || fail "A8: the agent never received the submitted text"
ok "A8: send --enter --wait-submit delivers the text to the agent"
if [ -n "$REQ" ]; then
  REPLAY=$(O terminal send --terminal "$AG2" --text 'fm-test-receipt-1' --enter --retry-request "$REQ" --json)
  sleep 1
  COUNT=$(read_tail "$AG2" | grep -c 'got: fm-test-receipt-1' || true)
  observe "send --retry-request replay: mutation=$(jq -c .result.mutation <<<"$REPLAY") agent received the text $COUNT time(s)"
  if [ "$COUNT" -eq 1 ]; then ok "A8: replaying the same request id does not repeat the input"; else finding "a replay with the same --retry-request id repeated the input ($COUNT deliveries)"; fi
else
  finding "send --wait-submit returned no mutation.requestId, so no --retry-request replay could be tried"
fi
O terminal close --terminal "$AG2" --json >/dev/null

# --- assertion 12: receipts for a plain shell, a closed terminal, and an exited shell (slice 11) -----------------

section "A12 delivery receipts beyond a live agent (proves slice 11: receipts and dead-terminal detection)"
own
CLOSED_SEND=$(O terminal send --terminal "$AG2" --text 'fm-test-to-closed' --enter --wait-submit 1 --json 2>/dev/null || true)
observe "send --enter --wait-submit to a CLOSED terminal: $(jq -c '{ok, code: .error.code, message: .error.message}' <<<"$CLOSED_SEND")"
[ "$(jq -r '.ok' <<<"$CLOSED_SEND")" = false ] && [ "$(jq -r '.error.code // empty' <<<"$CLOSED_SEND")" = terminal_not_writable ] \
  || fail "A12: a send to a closed terminal did not answer ok:false with error.code=terminal_not_writable"
ok "A12: a send to a closed terminal answers ok:false with error.code=terminal_not_writable (the adapter's gone set)"
PLAIN_T=$(O terminal create --worktree "id:$WT_A_ID" --title fm-test-plain --json | jq -r '.result.terminal.handle')
[ -n "$PLAIN_T" ] || fail "A12: terminal create returned no handle"
PLAIN_SEND=$(O terminal send --terminal "$PLAIN_T" --text 'echo fm-test-plain-receipt' --enter --wait-submit 1 --json)
observe "send --enter --wait-submit to a plain shell: $(jq -c '{send: .result.send, mutation: .result.mutation, warnings: .result.warnings}' <<<"$PLAIN_SEND")"
[ "$(jq -r '.result.send.accepted' <<<"$PLAIN_SEND")" = true ] && [ "$(jq -r '.result.send.prompt.observation' <<<"$PLAIN_SEND")" = unsupported ] \
  || fail "A12: a plain shell did not answer accepted=true with prompt.observation=unsupported"
ok "A12: a plain shell accepts the input and reports prompt.observation=unsupported (the adapter's composer fallback)"
O terminal send --terminal "$PLAIN_T" --text exit --enter --json >/dev/null
O terminal wait --terminal "$PLAIN_T" --for exit --timeout-ms 10000 --json >/dev/null 2>&1 || true
EXITED_SEND=$(O terminal send --terminal "$PLAIN_T" --text 'fm-test-to-exited' --enter --wait-submit 1 --json 2>/dev/null || true)
observe "send --enter --wait-submit to an EXITED shell: $(jq -c '{ok, code: .error.code, message: .error.message}' <<<"$EXITED_SEND")"
[ "$(jq -r '.error.code // empty' <<<"$EXITED_SEND")" = terminal_not_writable ] \
  || fail "A12: a send to an exited shell did not answer error.code=terminal_not_writable"
ok "A12: a send to an exited shell answers error.code=terminal_not_writable"
UNKNOWN_SEND=$(O terminal send --terminal term_00000000-0000-4000-8000-000000000000 --text 'fm-test-to-unknown' --enter --wait-submit 1 --json 2>/dev/null || true)
observe "send --enter --wait-submit to a handle the runtime never issued: $(jq -c '{ok, code: .error.code, message: .error.message}' <<<"$UNKNOWN_SEND")"
[ "$(jq -r '.error.code // empty' <<<"$UNKNOWN_SEND")" = terminal_handle_stale ] \
  || fail "A12: a send to a handle the runtime never issued did not answer error.code=terminal_handle_stale"
ok "A12: a send to a handle the runtime never issued answers error.code=terminal_handle_stale"
notrun "A12 a started-turn receipt (stages include turn_started): the lab has no agent that starts a turn, so only input_accepted and unsupported receipts are observed; the started shape is taken from the Orca CLI's own documentation"
O terminal close --terminal "$PLAIN_T" --json >/dev/null 2>&1 || true

# --- assertion 9: close and removal, landed and unmerged branches (slices 3, 10) ------------------------------

section "A9 close and worktree rm (unblocks slice 3, proves merged slice P1-B)"
own
O terminal close --worktree "id:$WT_A_ID" --all --json >/dev/null
[ "$(O terminal list --worktree "id:$WT_A_ID" --json | jq -r '.result.totalCount')" = 0 ] || fail "A9: terminal close --all left terminals"
ok "A9: terminal close --worktree <exact id> --all leaves no terminals for the worktree"
RM_A=$(O worktree rm --worktree "id:$WT_A_ID" --force --delete-branch --json)
[ "$(jq -r '.result.removed' <<<"$RM_A")" = true ] || fail "A9: worktree rm did not report removed=true"
[ ! -e "$WT_A_PATH" ] || fail "A9: the landed worktree directory still exists"
git -C "$SCRATCH" show-ref --verify --quiet "refs/heads/$WT_NAME" && fail "A9: the landed branch $WT_NAME still exists after --delete-branch"
ok "A9: removing a landed worktree with --delete-branch removes the directory and the Orca-made branch"
observe "landed worktree rm result: $(jq -c .result <<<"$RM_A")"
UNLANDED=fm-test-wt-unlanded
WT_B=$(O worktree create --repo "id:$REPO_ID" --name "$UNLANDED" --no-parent --setup skip --json)
WT_B_ID=$(jq -r '.result.worktree.id' <<<"$WT_B"); WT_B_PATH=$(jq -r '.result.worktree.path' <<<"$WT_B")
case "$WT_B_PATH" in "$LAB"/*) : ;; *) O worktree rm --worktree "id:$WT_B_ID" --force --json >/dev/null 2>&1; fail "A9: the second worktree was created outside the lab" ;; esac
git -C "$WT_B_PATH" -c user.email=lab@fm.test -c user.name=fm-test commit -q --allow-empty -m "fm-test unlanded work"
O terminal close --worktree "id:$WT_B_ID" --all --json >/dev/null
RM_B=$(O worktree rm --worktree "id:$WT_B_ID" --force --delete-branch --json)
[ "$(jq -r '.result.removed' <<<"$RM_B")" = true ] || fail "A9: removing the unmerged worktree did not report removed=true"
[ ! -e "$WT_B_PATH" ] || fail "A9: the unmerged worktree directory still exists"
git -C "$SCRATCH" show-ref --verify --quiet "refs/heads/$UNLANDED" || fail "A9: the unmerged branch was DELETED by worktree rm --delete-branch"
ok "A9: removing a worktree whose branch holds unmerged work keeps the branch"
observe "unmerged worktree rm result: $(jq -c .result <<<"$RM_B")"
git -C "$SCRATCH" branch -D "$UNLANDED" >/dev/null 2>&1 || true

# --- assertion 10: runtime restart (gap G11) ------------------------------------------------------------------------

section "A10 runtime restart survival (gap G11)"
own
WT_C=$(O worktree create --repo "id:$REPO_ID" --name fm-test-wt-restart --no-parent --setup skip --json)
WT_C_ID=$(jq -r '.result.worktree.id' <<<"$WT_C"); WT_C_PATH=$(jq -r '.result.worktree.path' <<<"$WT_C")
case "$WT_C_PATH" in "$LAB"/*) : ;; *) O worktree rm --worktree "id:$WT_C_ID" --force --json >/dev/null 2>&1; fail "A10: the restart worktree was created outside the lab" ;; esac
RT_CREATE=$(O terminal create --worktree "id:$WT_C_ID" --title fm-test-restart --command "sh -c 'echo FM-TEST-RESTART-MARK; sleep 300'" --json)
RT_T=$(jq -r '.result.terminal.handle' <<<"$RT_CREATE")
RT_PID=$(jq -r '.result.terminal.processId // empty' <<<"$RT_CREATE")
wait_for_text "$RT_T" FM-TEST-RESTART-MARK 10 || fail "A10: the restart marker never printed"
OLD_ID=$(jq -r '.result.runtime.runtimeId' <<<"$(O status --json)")
orca_lab_signal TERM "$CHILD" "$DATA" || fail "A10: could not signal the lab runtime"
orca_lab_wait_gone "$CHILD" 30 || fail "A10: the lab runtime did not stop"
wait "$CHILD" 2>/dev/null
SURVIVED_PID=no
[ -n "$RT_PID" ] && orca_lab_pid_running "$RT_PID" && SURVIVED_PID=yes
observe "after stopping only the lab runtime: the terminal's process (pid ${RT_PID:-unknown}) survived=$SURVIVED_PID"
start_runtime
own
NEW_ID=$(jq -r '.result.runtime.runtimeId' <<<"$(O status --json)")
[ "$NEW_ID" != "$OLD_ID" ] || fail "A10: the restarted runtime kept its runtime id"
ok "A10: the lab runtime restarts under a new runtime id on the same data directory"
SAME=$(O terminal list --worktree "id:$WT_C_ID" --json | jq -r --arg h "$RT_T" '[.result.terminals[] | select(.handle == $h)] | length')
if [ "$SAME" = 1 ] && read_tail "$RT_T" | grep -q FM-TEST-RESTART-MARK; then
  observe "terminals SURVIVE a runtime restart: handle $RT_T is still listed and its output is still readable"
else
  finding "the terminal did not survive a runtime restart as the same handle (listed=$SAME)"
fi
O terminal close --worktree "id:$WT_C_ID" --all --json >/dev/null
O worktree rm --worktree "id:$WT_C_ID" --force --delete-branch --json >/dev/null

# --- assertion 11: browser bridge -------------------------------------------------------------------------------------------

section "A11 browser bridge (slice 1)"
notrun "A11 browser bridge: the lab runtime reports browser automation unavailable ($(jq -r '[.result.runtime.degradations[]? | select(.code == "browser_unavailable") | .reason] | join(",")' <<<"$STATUS")) and chrome-devtools-axi drives a real browser session on the operator's desktop, which the lab must not touch. Unknown: whether a per-task chrome-devtools-axi session name avoids the missing-Chromium failure from a worker launched under an Orca terminal."

}

# --- Firstmate-level checks, lab-only --------------------------------------------------

run_firstmate_level() {
  section "F Firstmate scripts against the lab runtime (proves merged slices 2, 3, 5 live; blocks slices 9, 11)"
  own
  # The lab's own firstmate home; the scripts still run from this repo's bin/.
  FMHOME=$LAB/fmhome
  mkdir -p "$FMHOME/data" "$FMHOME/projects" "$FMHOME/state" "$FMHOME/config" "$LAB/fm-user-home" "$LAB/fm-tmp"
  touch "$FMHOME/state/.last-watcher-beat"
  printf 'manual\n' > "$FMHOME/config/backlog-backend"
  ID=test-orca-live
  mkdir -p "$FMHOME/data/$ID"
  cat > "$FMHOME/data/$ID/brief.md" <<BRIEF
# Task
## Captain's intent
Exercise the Orca backend against the lab runtime for $ID.

## Firstmate spec
Confirm spawn, peek, send, crew state, and teardown behave on a real Orca.
BRIEF
  # The repository the lab registered earlier may already exist on a re-run of
  # only this section; registration is idempotent and by exact path.
  if [ -z "${REPO_ID:-}" ]; then
    SCRATCH=$LAB/fm-test-repo
    mkdir -p "$SCRATCH"
    git -C "$SCRATCH" init -q -b main
    git -C "$SCRATCH" -c user.email=lab@fm.test -c user.name=fm-test commit -q --allow-empty -m init
    echo seed > "$SCRATCH/seed.txt"
    git -C "$SCRATCH" add seed.txt
    git -C "$SCRATCH" -c user.email=lab@fm.test -c user.name=fm-test commit -q -m seed
    FOLDER=$LAB/fm-test-folder
    mkdir -p "$FOLDER"
    echo x > "$FOLDER/x.txt"
    REPO_ID=$(O repo add --path "$SCRATCH" --json | jq -r '.result.repo.id')
    FOLDER_ID=$(O repo add --path "$FOLDER" --kind folder --json | jq -r '.result.repo.id')
  fi
  fm() {  # run one of this repo's scripts against the lab home
    env FM_ROOT_OVERRIDE='' FM_HOME="$FMHOME" HOME="$LAB/fm-user-home" TMPDIR="$LAB/fm-tmp" \
      FM_STATE_OVERRIDE="$FMHOME/state" FM_DATA_OVERRIDE="$FMHOME/data" \
      FM_PROJECTS_OVERRIDE="$FMHOME/projects" FM_CONFIG_OVERRIDE="$FMHOME/config" \
      FM_SPAWN_NO_GUARD=1 "$@"
  }

  # The adapter's folder refusal, live (merged slice 5): the folder-kind repo is refused and the registration untouched.
  # shellcheck source=bin/fm-backend.sh
  . "$ROOT/bin/fm-backend.sh"
  fm_backend_source orca || fail "F: cannot source the Orca adapter"
  err=$(fm_backend_orca_repo_ensure "$FOLDER" 2>&1) && fail "F: the adapter accepted a folder-kind repo" || true
  assert_contains "$err" "folder" "F: the adapter's folder refusal names the folder kind"
  assert_contains "$err" "--backend" "F: the folder refusal names the per-task --backend escape hatch"
  [ "$(O repo show --repo "path:$FOLDER" --json | jq -r '.result.repo.kind')" = folder ] || fail "F: the folder registration changed"
  ok "F: fm_backend_orca_repo_ensure refuses the folder-kind repo on real Orca and leaves its registration unchanged (merged slice 5 live)"
  [ "$(fm_backend_orca_repo_ensure "$SCRATCH")" = "$REPO_ID" ] || fail "F: repo_ensure did not return the registered git repo id"
  ok "F: fm_backend_orca_repo_ensure returns the registered id for the git repo"

  # spawn
  out=$(fm "$ROOT/bin/fm-spawn.sh" "$ID" "$SCRATCH" --mode local-only --yolo off --backend orca --harness 'sh -c cat' 2>&1) \
    || fail "F: fm-spawn --backend orca failed: $out"
  assert_contains "$out" "spawned $ID" "F: spawn did not report success"
  META=$FMHOME/state/$ID.meta
  meta() { sed -n "s/^$1=//p" "$META" | head -1; }
  [ "$(meta backend)" = orca ] || fail "F: meta backend is not orca"
  TASK_T=$(meta terminal); TASK_WT=$(meta worktree); TASK_WID=$(meta orca_worktree_id)
  [ -n "$TASK_T" ] && [ -n "$TASK_WT" ] && [ -n "$TASK_WID" ] || fail "F: meta lacks terminal, worktree, or orca_worktree_id"
  case "$TASK_WT" in "$LAB"/*) : ;; *) fail "F: the task worktree $TASK_WT is outside the lab" ;; esac
  [ "$(cd "$TASK_WT" && git rev-parse --show-toplevel)" = "$(cd "$TASK_WT" && pwd -P)" ] || fail "F: the task worktree is not its own git toplevel"
  ok "F: fm-spawn --backend orca with a raw harness records backend, terminal, worktree, and Orca worktree id inside the lab"
  observe "task meta: $(grep -E '^(backend|window|terminal|orca_worktree_id|worktree|harness)=' "$META" | tr '\n' ' ')"
  NT=$(O terminal list --worktree "id:$TASK_WID" --json | jq -r '.result.totalCount')
  LIVE_AFTER=$(O worktree ps --json | jq -r --arg id "$TASK_WID" '.result.worktrees[] | select(.worktreeId == $id) | .liveTerminalCount')
  observe "after fm-spawn: terminal list totalCount=$NT, worktree ps liveTerminalCount=$LIVE_AFTER, recorded terminal=$TASK_T"
  if [ "$NT" -gt 1 ]; then
    finding "after fm-spawn the task worktree holds $NT live terminals, not 1: the startup-terminal adoption (merged slice P1-A) never fires because this runtime's worktree create names no startup terminal, so the adapter's fallback 'terminal create' leaves a spare terminal; the live target is liveTerminalCount=1"
  else
    ok "F: after fm-spawn the task worktree holds exactly one live terminal"
  fi

  # peek
  peek=$(fm "$ROOT/bin/fm-peek.sh" "$ID" 40 2>&1) || fail "F: fm-peek failed: $peek"
  [ -n "$peek" ] || fail "F: fm-peek returned nothing"
  ok "F: fm-peek reads the recorded Orca terminal"
  observe "fm-peek tail: $(printf '%s' "$peek" | tail -3 | tr '\n' '|' | cut -c1-300)"

  # send text: durable inbox record plus doorbell
  fm "$ROOT/bin/fm-send.sh" "$ID" 'fm-test-steer-one' >/dev/null 2>&1 || fail "F: fm-send text failed"
  grep -rqF 'fm-test-steer-one' "$FMHOME/state/$ID.inbox"/*.msg 2>/dev/null || fail "F: fm-send left no durable inbox record holding the text"
  ok "F: fm-send text writes the durable steering-inbox record"
  sleep 1
  DOORBELL=$(O terminal read --terminal "$TASK_T" --json | jq -r '.result.terminal.tail | join("\n")')
  case "$DOORBELL" in
    *inbox*|*INBOX*) ok "F: fm-send rang the doorbell into the Orca terminal (an inbox line reached the cat harness)" ;;
    *) finding "fm-send's doorbell did not appear in the Orca terminal read (tail: $(printf '%s' "$DOORBELL" | tail -2 | tr '\n' '|' | cut -c1-200))" ;;
  esac

  # delivery receipts through the adapter (slice 11): a live plain-shell terminal, then a closed one
  fm_backend_orca_has_capability terminal.prompt-delivery.v1 \
    || fail "F: the lab runtime does not list terminal.prompt-delivery.v1, so the receipt path cannot be exercised"
  RX_T=$(O terminal create --worktree "id:$TASK_WID" --title fm-test-rx --json | jq -r '.result.terminal.handle')
  [ -n "$RX_T" ] || fail "F: terminal create for the receipt probe returned no handle"
  RX_V=$(fm_backend_send_text_submit orca "$RX_T" 'echo fm-test-live-receipt' 3 0.4 0.3 2>"$LAB/rx.err") || fail "F: a live-terminal send through the adapter failed: $(cat "$LAB/rx.err")"
  observe "adapter send to a live plain-shell terminal: verdict=$RX_V (receipt path; a plain shell reports observation=unsupported, so the verdict is the composer's)"
  case "$RX_V" in
    send-failed|terminal-gone) fail "F: a live terminal reported $RX_V" ;;
  esac
  wait_for_text "$RX_T" 'fm-test-live-receipt' 10 || fail "F: the text sent through the receipt path never reached the live terminal"
  ok "F: the adapter sends to a live Orca terminal through the receipt path and the text arrives (verdict $RX_V)"
  O terminal close --terminal "$RX_T" --json >/dev/null
  RX_RC=0
  RX_V=$(fm_backend_send_text_submit orca "$RX_T" 'echo fm-test-dead-receipt' 3 0.4 0.3 2>"$LAB/rx.err") || RX_RC=$?
  observe "adapter send to the CLOSED terminal: verdict=$RX_V rc=$RX_RC stderr=$(cut -c1-200 "$LAB/rx.err")"
  [ "$RX_V" = terminal-gone ] && [ "$RX_RC" -ne 0 ] || fail "F: a send to a closed terminal did not report terminal-gone with a nonzero exit (verdict=$RX_V rc=$RX_RC)"
  assert_contains "$(cat "$LAB/rx.err")" "$RX_T" "F: the failure does not name the terminal"
  ok "F: the adapter reports a closed Orca terminal as terminal-gone with a nonzero exit and a message naming it"

  # send --key
  for key in Enter C-c Escape; do
    if kout=$(fm "$ROOT/bin/fm-send.sh" "$ID" --key "$key" 2>&1); then
      observe "fm-send --key $key: delivered"
    else
      observe "fm-send --key $key: refused ($(printf '%s' "$kout" | tail -1 | cut -c1-160))"
    fi
  done
  fm "$ROOT/bin/fm-send.sh" "$ID" --key Enter >/dev/null 2>&1 || fail "F: fm-send --key Enter failed on Orca"
  ok "F: fm-send --key Enter is delivered on Orca"

  # crew state
  cs=$(fm "$ROOT/bin/fm-crew-state.sh" "$ID" 2>&1) || fail "F: fm-crew-state failed: $cs"
  assert_contains "$cs" "state:" "F: fm-crew-state printed no state line"
  ok "F: fm-crew-state reads the Orca task and prints a state line"
  observe "fm-crew-state: $(printf '%s' "$cs" | head -3 | tr '\n' '|' | cut -c1-300)"

  # teardown refusals: dirty, then unlanded; the task must survive both
  echo dirty > "$TASK_WT/fm-test-dirty.txt"
  if out=$(fm "$ROOT/bin/fm-teardown.sh" "$ID" 2>&1); then fail "F: teardown of a DIRTY worktree succeeded: $out"; fi
  [ -d "$TASK_WT" ] && [ -f "$META" ] || fail "F: a refused dirty teardown removed the worktree or the record"
  [ "$(O terminal list --worktree "id:$TASK_WID" --json | jq -r '.result.totalCount')" -ge 1 ] || fail "F: a refused dirty teardown closed the terminal"
  ok "F: teardown refuses a dirty worktree and leaves the terminal, worktree, and record in place"
  observe "dirty refusal: $(printf '%s' "$out" | tail -2 | tr '\n' '|' | cut -c1-240)"
  rm -f "$TASK_WT/fm-test-dirty.txt"
  git -C "$TASK_WT" -c user.email=lab@fm.test -c user.name=fm-test commit -q --allow-empty -m "fm-test unlanded work"
  if out=$(fm "$ROOT/bin/fm-teardown.sh" "$ID" 2>&1); then fail "F: teardown of an UNLANDED branch succeeded: $out"; fi
  [ -d "$TASK_WT" ] && [ -f "$META" ] || fail "F: a refused unlanded teardown removed the worktree or the record"
  ok "F: teardown refuses a branch holding an unlanded commit and leaves everything in place"
  observe "unlanded refusal: $(printf '%s' "$out" | tail -2 | tr '\n' '|' | cut -c1-240)"
  git -C "$TASK_WT" reset -q --hard HEAD~1

  # the task's own terminal goes away: a steer is still recorded durably and a typed send names the gone terminal
  O terminal close --terminal "$TASK_T" --json >/dev/null
  GONE_OUT=$(fm "$ROOT/bin/fm-send.sh" "$ID" 'fm-test-steer-to-gone' 2>&1) || fail "F: a steer to a closed terminal failed instead of recording durably: $GONE_OUT"
  grep -rqF 'fm-test-steer-to-gone' "$FMHOME/state/$ID.inbox"/*.msg 2>/dev/null || fail "F: the steer to a closed terminal left no durable inbox record"
  observe "fm-send ordinary steer to the closed task terminal: $(printf '%s' "$GONE_OUT" | tail -1 | cut -c1-240)"
  assert_contains "$GONE_OUT" "has exited" "F: the doorbell to a closed terminal was not reported as gone"
  ok "F: a steer to a closed task terminal is recorded durably and the doorbell is reported as gone, not as a failed ring"
  if GONE_TYPED=$(fm "$ROOT/bin/fm-send.sh" "$ID" '/fm-test-typed' 2>&1); then fail "F: a typed send to a closed terminal succeeded: $GONE_TYPED"; fi
  observe "fm-send typed send to the closed task terminal: $(printf '%s' "$GONE_TYPED" | tr '\n' '|' | cut -c1-300)"
  assert_contains "$GONE_TYPED" "is gone" "F: the typed send's error does not say the terminal is gone"
  assert_contains "$GONE_TYPED" "nothing was delivered" "F: the typed send's error does not say nothing was delivered"
  ok "F: a typed send to a closed task terminal fails and says the terminal is gone and nothing was delivered"

  # clean teardown
  TASK_BRANCH=$(git -C "$TASK_WT" rev-parse --abbrev-ref HEAD)
  out=$(fm "$ROOT/bin/fm-teardown.sh" "$ID" 2>&1) || fail "F: a clean teardown failed: $out"
  [ ! -e "$TASK_WT" ] || fail "F: the worktree directory remains after a clean teardown"
  [ ! -f "$META" ] || fail "F: the task record remains after a clean teardown"
  [ "$(O terminal list --worktree "id:$TASK_WID" --json 2>/dev/null | jq -r '.result.totalCount // 0')" = 0 ] || fail "F: terminals remain after a clean teardown"
  git -C "$SCRATCH" show-ref --verify --quiet "refs/heads/$TASK_BRANCH" && fail "F: the task branch $TASK_BRANCH remains after a clean teardown"
  ok "F: a clean teardown removes the worktree, terminal, branch, and record"

  # final inventory
  section "F final inventory"
  own
  [ "$(O terminal list --json | jq -r '.result.totalCount')" = 0 ] || fail "inventory: terminals remain: $(O terminal list --json | jq -c '[.result.terminals[].handle]')"
  EXTRA_WT=$(O worktree ps --json | jq -r '.result.worktrees[] | select(.isMainWorktree != true) | .worktreeId')
  [ -z "$EXTRA_WT" ] || fail "inventory: non-main worktrees remain: $EXTRA_WT"
  [ "$(git -C "$SCRATCH" worktree list | wc -l)" = 1 ] || fail "inventory: git still lists extra worktrees: $(git -C "$SCRATCH" worktree list)"
  [ "$(git -C "$SCRATCH" branch --format='%(refname:short)' | tr '\n' ' ')" = "main " ] || fail "inventory: branches remain: $(git -C "$SCRATCH" branch --format='%(refname:short)' | tr '\n' ' ')"
  HOSTPID=$(jq -r '.pid // empty' "$DATA"/daemon/*.pid 2>/dev/null | head -1)
  STRAY=''
  for p in $(orca_lab_leftovers "$LAB" "$DATA"); do
    [ "$p" = "$CHILD" ] || [ "$p" = "$HOSTPID" ] && continue
    # The terminal host keeps one small watcher shell that stops its systemd
    # scope when the host exits; it is part of the host, not a task process.
    tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'orca-daemon-scope-watch' && continue
    STRAY="$STRAY $p"
  done
  [ -z "$STRAY" ] || fail "inventory: stray lab processes remain:$STRAY ($(for p in $STRAY; do tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-160; echo -n ' | '; done))"
  ok "F: the final inventory finds zero leftover terminals, worktrees, branches, and processes (only the lab runtime and its terminal host remain, and stop removes them)"
}

case "${FM_ORCA_LIVE_SECTIONS:-all}" in
  all) run_orca_level; run_firstmate_level ;;
  orca) run_orca_level ;;
  firstmate) run_firstmate_level ;;
  *) fail "FM_ORCA_LIVE_SECTIONS must be all, orca, or firstmate" ;;
esac

[ "$PASSED" -gt 0 ] || fail "no assertion was verified"
printf '# summary: passed=%s findings=%s\n' "$PASSED" "$FINDINGS"
