#!/usr/bin/env bash
# Opt-in, lab-only live regression for the Code Mode pilot knob
# (config/claude-code-mode) in a real interactive Claude Code TUI under tmux.
#
# Every existing live Claude guard drives `claude -p`, which cannot run Code Mode,
# so only an interactive launch can prove it. For each case the real
# bin/fm-spawn.sh builds the launch line (fake tmux and treehouse capture it, as
# in tests/fm-spawn-claude-code-mode.test.sh); that exact line then runs in a real
# tmux pane against a COPY of a throwaway Claude config directory, with
# CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1 deliberately left in the pane's ambient
# environment wherever the launch must not enable Code Mode. It proves:
#   1. scouts knob + accepted config directory: a scout shows the Code Mode banner
#      and its transcript records a REPL tool call.
#   2. the same knob, a ship worker: no banner, despite the stray ambient variable.
#   3. the same knob, a config directory that has NOT accepted the confirmation:
#      the spawn says it skipped Code Mode, the worker never shows the
#      confirmation dialog, and there is no banner.
# One Haiku turn per case reads a bounded brief; no other prompt is submitted.
#
# LAB ONLY. It never touches the real ~/.claude or the invoking
# CLAUDE_CONFIG_DIR: it needs a throwaway config directory signed in by a person
# with tests/fm-claude-codemode-lab-login.sh, refuses anything else, and works on
# per-case copies so the prepared directory stays pristine.
# shellcheck disable=SC2016 # the model, not this test shell, reads the prompt text
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

fm_live_gate opt-in FM_CLAUDE_CODEMODE_LIVE_E2E claude tmux jq

VAR=CLAUDE_CODE_EXPERIMENTAL_CODE_MODE
BANNER='Code Mode (experimental) is on'
LAB_DEFAULT="$HOME/.cache/fm-codemode-lab/config"
LAB_CONFIG=${FM_CODEMODE_LAB_CONFIG_DIR:-$LAB_DEFAULT}
LOGIN="$ROOT/tests/fm-claude-codemode-lab-login.sh"
CLAUDE_VERSION=$(claude --version 2>/dev/null || true)
[ -n "$CLAUDE_VERSION" ] || fail "claude is installed but reports no version"

real_of() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }

# --- lab guard: only a throwaway, person-prepared config directory ------------
case "$LAB_CONFIG" in
/*) ;;
*) fail "FM_CODEMODE_LAB_CONFIG_DIR must be an absolute path, got '$LAB_CONFIG'" ;;
esac
for forbidden in "$HOME" "$HOME/.claude" "${CLAUDE_CONFIG_DIR:-}"; do
  [ -n "$forbidden" ] || continue
  [ "$(real_of "$LAB_CONFIG")" != "$(real_of "$forbidden")" ] ||
    fail "'$LAB_CONFIG' is a real Claude store or home directory; this guard runs only against a throwaway directory"
done
if [ ! -f "$LAB_CONFIG/.fm-codemode-lab" ]; then
  fail "no throwaway Claude login at $LAB_CONFIG; run this once in a real terminal, then rerun: $LOGIN"
fi
env -i HOME="$HOME" PATH="$PATH" CLAUDE_CONFIG_DIR="$LAB_CONFIG" claude auth status >/dev/null 2>&1 </dev/null ||
  fail "the throwaway Claude directory $LAB_CONFIG is not signed in; run: $LOGIN"
jq -e '.codeModeCaveatsAcceptedV1 == true' "$LAB_CONFIG/.claude.json" >/dev/null 2>&1 ||
  fail "the throwaway Claude directory $LAB_CONFIG has not accepted the Code Mode confirmation; run: $LOGIN"
# Code Mode needs Claude Code 2.1.323 or later; an older client ignores the variable.
version_number=$(printf '%s\n' "$CLAUDE_VERSION" | sed -n 's/^\([0-9][0-9.]*\).*/\1/p')
[ "$(printf '%s\n%s\n' 2.1.323 "$version_number" | sort -V | head -1)" = 2.1.323 ] ||
  fail "Claude Code $CLAUDE_VERSION is older than 2.1.323, so Code Mode cannot start"

LAB=$(fm_test_tmproot fm-codemode-live)
SOCKET="fm-codemode-live-$$"
SESSION=codemode

cleanup() {
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
  rm -rf "$LAB" 2>/dev/null || true
  fm_test_cleanup
}
trap cleanup EXIT

screen() { tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null || true; }

# Wait (iteration-counted, so it stretches under load) until the screen shows
# <text>, failing early if Claude exits or parks on the Code Mode confirmation.
wait_screen() {  # <text> <what> [iterations]
  local text=$1 what=$2 limit=${3:-480} i=0 shot
  while [ "$i" -lt "$limit" ]; do
    shot=$(screen)
    case "$shot" in
    *'start without it'*) fail "the worker parked on the Code Mode confirmation while waiting for $what" ;;
    *'CLAUDE_EXIT='*) printf '%s\n' "$shot" >&2; fail "Claude Code $CLAUDE_VERSION exited while waiting for $what" ;;
    *"$text"*) return 0 ;;
    esac
    sleep 0.25
    i=$((i + 1))
  done
  printf '%s\n' "$shot" >&2
  fail "Claude Code $CLAUDE_VERSION never showed '$text' ($what)"
}

# run_case <name> <kind: ship|scout> <knob> <accepted: yes|no> <brief>
# Builds the launch through the real fm-spawn, then runs it in a real pane.
# Sets SPAWN_OUT and CFG (the case's private copy of the lab config).
run_case() {
  local name=$1 kind=$2 knob=$3 accepted=$4 brief=$5 home proj wt fakebin id launch extra
  CASE="$LAB/$name"
  id="cm-live-$name"
  home="$CASE/home"
  proj="$CASE/project"
  wt="$CASE/wt"
  CFG="$CASE/claude-config"
  mkdir -p "$CASE"
  cp -a "$LAB_CONFIG" "$CFG"
  rm -f "$CFG/.fm-codemode-lab"
  if [ "$accepted" = no ]; then
    jq 'del(.codeModeCaveatsAcceptedV1, .codeModeAutoModeCaveatAcceptedV1)' "$CFG/.claude.json" >"$CFG/.claude.json.new" &&
      mv "$CFG/.claude.json.new" "$CFG/.claude.json"
  fi
  fakebin=$(fm_test_make_spawn_fakebin "$CASE/fake")
  fm_test_spawn_home "$home" claude
  printf '%s\n' "$knob" >"$home/config/claude-code-mode"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  printf 'alpha\nbeta\ngamma\n' >"$wt/notes.txt"
  fm_test_spawn_brief "$home" "$id" "$brief"
  extra=(--mode no-mistakes --yolo off)
  [ "$kind" = ship ] || extra=(--scout)
  : >"$CASE/launch.log"
  SPAWN_OUT=$(FM_FAKE_LAUNCH_LOG="$CASE/launch.log" FM_TEST_CLAUDE_CONFIG_DIR="$CFG" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" "$id" "$proj" "${extra[@]}" --model haiku)
  [ -s "$CASE/launch.log" ] || fail "fm-spawn produced no launch line: $SPAWN_OUT"
  launch=$(cat "$CASE/launch.log")

  tmux -L "$SOCKET" kill-session -t "$SESSION" 2>/dev/null || true
  # The pane keeps a stray Code Mode variable in its ambient environment, so a
  # worker that does not carry the assignment shows whether the launch line's own
  # unset really decides. Session markers and the invoking account are dropped so
  # Claude does not refuse to nest or reach the real store.
  tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 170 -y 50 -c "$wt" \
    "env -u CLAUDECODE -u CLAUDE_CONFIG_DIR -u ANTHROPIC_API_KEY -u CLAUDE_CODE_OAUTH_TOKEN $VAR=1 DISABLE_AUTOUPDATER=1 HOME='$HOME' bash -c $(printf '%q' "$launch"); printf '\nCLAUDE_EXIT=%s\n' \"\$?\"; sleep 60"
}

transcript_has_repl() {  # <config-copy>
  grep -rlq '"name":"REPL"' "$1/projects" 2>/dev/null
}

wait_answer() {  # <text> <what>: the model's bounded answer, which also ends the turn
  wait_screen "$1" "$2"
}

# --- case 1: a scout with the knob on and the dialog accepted -----------------
run_case scout-on scout scouts yes \
  'Run the shell command `wc -l notes.txt` once, then reply with the single line CODEMODE-SCOUT-DONE and nothing else.'
case "$SPAWN_OUT" in
*'Code Mode skipped'*) fail "an accepted config directory must not skip Code Mode: $SPAWN_OUT" ;;
esac
wait_screen "$BANNER" "the Code Mode banner on the scout"
wait_answer CODEMODE-SCOUT-DONE "the scout's answer"
transcript_has_repl "$CFG" || fail "the Code Mode scout's transcript records no REPL tool call"
pass "claude $CLAUDE_VERSION: a scout under config/claude-code-mode=scouts starts in Code Mode and calls REPL"
tmux -L "$SOCKET" kill-session -t "$SESSION" 2>/dev/null || true

# --- case 2: a ship worker under the same knob --------------------------------
run_case ship-off ship scouts yes 'Reply with the single line CODEMODE-SHIP-DONE and nothing else.'
wait_answer CODEMODE-SHIP-DONE "the ship worker's answer"
case "$(screen)" in
*"$BANNER"*) fail "a ship worker showed the Code Mode banner although only scouts may use it" ;;
esac
transcript_has_repl "$CFG" && fail "a ship worker's transcript records a REPL tool call"
pass "claude $CLAUDE_VERSION: a ship worker stays out of Code Mode even with the variable in the ambient environment"
tmux -L "$SOCKET" kill-session -t "$SESSION" 2>/dev/null || true

# --- case 3: a config directory that has not accepted the confirmation --------
run_case scout-unaccepted scout scouts no 'Reply with the single line CODEMODE-SKIP-DONE and nothing else.'
case "$SPAWN_OUT" in
*'Code Mode skipped'*) ;;
*) fail "an unaccepted config directory must report that Code Mode was skipped: $SPAWN_OUT" ;;
esac
wait_answer CODEMODE-SKIP-DONE "the skipped scout's answer"
case "$(screen)" in
*"$BANNER"*) fail "a scout whose directory has not accepted the confirmation still started in Code Mode" ;;
esac
pass "claude $CLAUDE_VERSION: a scout in an unaccepted config directory starts without Code Mode and never parks on the dialog"

echo "# claude $CLAUDE_VERSION Code Mode pilot live guard passed"
