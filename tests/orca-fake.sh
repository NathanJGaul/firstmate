#!/usr/bin/env bash
# tests/orca-fake.sh - a STATEFUL fake `orca` CLI and a fake process table, for
# the tests that exercise the Orca close-and-recreate reclaim
# (specs/010-orca-reclaim) through fm-control.sh and fm-spawn.sh --relaunch.
#
# The static fake in tests/fm-backend-orca.test.sh answers by call number, which
# cannot model a close that changes what the next `terminal show` says. This one
# keeps one file per terminal under <dir>/fake/terms and answers from it, so a
# test can close a terminal, create another, and watch the recorded handle go
# from live to missing the way the real runtime does (response shapes recorded
# in the isolated lab, docs/verification/runtime-backends.md "Orca reclaim").
#
# Layout under <dir> (created by orca_fake_new):
#   fakebin/orca     the fake CLI
#   fake/log         every call, fields joined by 0x1f
#   fake/terms/<h>   one line "<state> <worktree-id>", state live|closed|exited
#   fake/proc        a fake process table laid out like /proc (FM_ORCA_PROC_ROOT)
#   fake/flags/<f>   behavior switches (see orca_fake_flag)
#   fake/seq         the counter behind new terminal handles (term-new-N)
# A test points FM_ORCA_FAKE_DIR at <dir>/fake, FM_ORCA_PROC_ROOT at
# <dir>/fake/proc, and puts <dir>/fakebin first on PATH (orca_fake_run does all
# three).
#
# Process model: a terminal's shell is process <base>0 carrying the handle, and
# `orca_fake_agent <dir> <handle> up` adds a harness process named claude
# beneath it. A `terminal send` whose text is the staged launch command, or the
# first-message doorbell, starts that agent in the terminal it was typed into,
# the way a real launch does. A close removes every process of the handle
# unless the `close-lingers` flag says the terminal outlives its receipt.
#
# Flags (orca_fake_flag <dir> <name> [on|off]):
#   close-nokill     close answers ok with ptyKilled false (nothing was killed;
#                    the real runtime answers ptyKilled true even for a repeat
#                    close of a closed terminal, so this is a degraded runtime)
#   close-lingers    close answers ptyKilled true but the terminal and its
#                    processes stay (a close that was accepted and not honoured)
#   close-error      close answers an unreadable error
#   close-wrong      close answers a receipt that names another handle
#   create-fails     terminal create answers an error
#   create-unlisted  terminal create succeeds but the terminal is not listed
#   status-bad       status answers a runtime that is not ready
#   launch-no-agent  a launch send starts no agent (a launch that did not take)

orca_fake_new() {  # <dir>
  local dir=$1
  mkdir -p "$dir/fakebin" "$dir/fake/terms" "$dir/fake/proc" "$dir/fake/flags"
  : > "$dir/fake/log"
  printf '0\n' > "$dir/fake/seq"
  cat > "$dir/fakebin/orca" <<'SH'
#!/usr/bin/env bash
set -u
D=${FM_ORCA_FAKE_DIR:?FM_ORCA_FAKE_DIR must name the fake orca state directory}
{
  printf 'orca'
  for a in "$@"; do printf '\x1f%s' "$a"; done
  printf '\n'
} >> "$D/log"
flag() { [ -e "$D/flags/$1" ]; }
term_state() { [ -f "$D/terms/$1" ] && { read -r s _ < "$D/terms/$1"; printf '%s' "$s"; }; }
term_wt() { [ -f "$D/terms/$1" ] && { read -r _ w < "$D/terms/$1"; printf '%s' "$w"; }; }
arg_after() {  # <flag> <args...>
  local want=$1 a prev=
  shift
  for a in "$@"; do
    [ "$prev" = "$want" ] && { printf '%s' "$a"; return 0; }
    prev=$a
  done
  return 1
}
stale() {
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale"}}\n'
  exit 1
}
kill_procs() {  # <handle>: every fake process carrying the handle, and its children
  local p
  for p in "$D/proc"/*; do
    [ -d "$p" ] || continue
    if tr '\0' '\n' < "$p/environ" 2>/dev/null | grep -qx "ORCA_TERMINAL_HANDLE=$1"; then
      rm -rf "$p"
    fi
  done
  for p in "$D/proc"/*; do
    [ -d "$p" ] || continue
    [ -d "$D/proc/$(awk '{print $4}' "$p/stat" 2>/dev/null)" ] || [ "$(awk '{print $4}' "$p/stat" 2>/dev/null)" = 1 ] || rm -rf "$p"
  done
}
start_agent() {  # <handle>
  local h=$1 base shell_pid pid
  flag launch-no-agent && return 0
  [ "$(term_state "$h")" = live ] || return 0
  for p in "$D/proc"/*; do
    [ -d "$p" ] || continue
    [ "$(cat "$p/comm" 2>/dev/null)" = claude ] || continue
    tr '\0' '\n' < "$p/environ" 2>/dev/null | grep -qx "ORCA_TERMINAL_HANDLE=$h" && return 0
  done
  shell_pid=
  for p in "$D/proc"/*; do
    [ -d "$p" ] || continue
    tr '\0' '\n' < "$p/environ" 2>/dev/null | grep -qx "ORCA_TERMINAL_HANDLE=$h" && shell_pid=${p##*/} && break
  done
  [ -n "$shell_pid" ] || return 0
  pid=$((shell_pid + 1))
  while [ -d "$D/proc/$pid" ]; do pid=$((pid + 1)); done
  mkdir -p "$D/proc/$pid"
  printf 'PATH=/usr/bin\0ORCA_TERMINAL_HANDLE=%s\0' "$h" > "$D/proc/$pid/environ"
  printf 'claude\n' > "$D/proc/$pid/comm"
  printf 'claude\0--dangerously-skip-permissions\0' > "$D/proc/$pid/cmdline"
  printf '%s (claude) S %s 1 1 0 -1 0\n' "$pid" "$shell_pid" > "$D/proc/$pid/stat"
}
new_shell() {  # <handle>: a shell process carrying the handle
  local h=$1 pid=100
  while [ -d "$D/proc/$pid" ]; do pid=$((pid + 10)); done
  mkdir -p "$D/proc/$pid"
  printf 'PATH=/usr/bin\0ORCA_TERMINAL_HANDLE=%s\0' "$h" > "$D/proc/$pid/environ"
  printf 'zsh\n' > "$D/proc/$pid/comm"
  printf 'zsh\0' > "$D/proc/$pid/cmdline"
  printf '%s (zsh) S 1 1 1 0 -1 0\n' "$pid" > "$D/proc/$pid/stat"
}
case "${1:-}:${2:-}" in
  status:*)
    if flag status-bad; then
      printf '{"ok":true,"result":{"runtime":{"reachable":false,"state":"starting"}}}\n'
    else
      printf '{"ok":true,"result":{"runtime":{"reachable":true,"state":"ready","appVersion":"1.4.261","capabilities":["terminal.ordered-input.v1"]}}}\n'
    fi
    ;;
  terminal:show)
    h=$(arg_after --terminal "$@") || h=
    s=$(term_state "$h")
    case "$s" in
      live) printf '{"ok":true,"result":{"terminal":{"handle":"%s","connected":true,"writable":true,"executionHostId":"local"}}}\n' "$h" ;;
      closed) printf '{"ok":true,"result":{"terminal":{"handle":"%s","connected":false,"writable":false,"exitCause":{"kind":"operator_close"},"executionHostId":"local"}}}\n' "$h" ;;
      exited) printf '{"ok":true,"result":{"terminal":{"handle":"%s","connected":false,"writable":false,"exitCause":{"kind":"exited","exitCode":0},"executionHostId":"local"}}}\n' "$h" ;;
      *) stale ;;
    esac
    ;;
  terminal:read)
    h=$(arg_after --terminal "$@") || h=
    [ -n "$(term_state "$h")" ] || stale
    printf '{"ok":true,"result":{"terminal":{"handle":"%s","status":"running","tail":["$ "]}}}\n' "$h"
    ;;
  terminal:close)
    h=$(arg_after --terminal "$@") || h=
    if flag close-error; then
      printf 'not json\n'
      exit 1
    fi
    [ -n "$(term_state "$h")" ] || stale
    if flag close-wrong; then
      printf '{"ok":true,"result":{"close":{"handle":"term-somebody-else","tabId":"tab","ptyKilled":true}}}\n'
      exit 0
    fi
    if flag close-lingers; then
      printf '{"ok":true,"result":{"close":{"handle":"%s","tabId":"tab","ptyKilled":true}}}\n' "$h"
      exit 0
    fi
    if flag close-nokill; then
      printf '{"ok":true,"result":{"close":{"handle":"%s","tabId":"tab","ptyKilled":false}}}\n' "$h"
      exit 0
    fi
    if [ "$(term_state "$h")" = live ]; then
      printf 'closed %s\n' "$(term_wt "$h")" > "$D/terms/$h"
      kill_procs "$h"
      printf '{"ok":true,"result":{"close":{"handle":"%s","tabId":"tab","ptyKilled":true}}}\n' "$h"
    else
      # Observed on the real runtime (Orca 1.4.261, docs/verification/runtime-backends.md
      # "Orca reclaim"): a repeat close of an already closed terminal still answers ptyKilled true.
      printf 'closed %s\n' "$(term_wt "$h")" > "$D/terms/$h"
      printf '{"ok":true,"result":{"close":{"handle":"%s","tabId":"tab","ptyKilled":true}}}\n' "$h"
    fi
    ;;
  terminal:create)
    if flag create-fails; then
      printf '{"ok":false,"error":{"code":"runtime_error","message":"create failed"}}\n'
      exit 1
    fi
    wt=$(arg_after --worktree "$@") || wt=
    n=$(( $(cat "$D/seq") + 1 ))
    printf '%s\n' "$n" > "$D/seq"
    h="term-new-$n"
    printf 'live %s\n' "${wt#id:}" > "$D/terms/$h"
    flag create-unlisted && printf 'unlisted\n' > "$D/flags/.unlisted-$h"
    new_shell "$h"
    printf '{"ok":true,"result":{"terminal":{"handle":"%s","title":"%s"}}}\n' "$h" "$(arg_after --title "$@" || true)"
    ;;
  terminal:rename)
    printf '{"ok":true,"result":{}}\n'
    ;;
  terminal:list)
    wt=$(arg_after --worktree "$@") || wt=
    wt=${wt#id:}
    rows=
    for f in "$D/terms"/*; do
      [ -f "$f" ] || continue
      h=${f##*/}
      [ -e "$D/flags/.unlisted-$h" ] && continue
      read -r s w < "$f"
      [ "$w" = "$wt" ] || continue
      [ "$s" = live ] || continue
      rows="${rows:+$rows,}{\"handle\":\"$h\",\"worktreeId\":\"$w\",\"writable\":true}"
    done
    printf '{"ok":true,"result":{"terminals":[%s],"totalCount":%s,"truncated":false}}\n' "$rows" "$(printf '%s' "$rows" | grep -o '"handle"' | wc -l | tr -d ' ')"
    ;;
  terminal:send)
    h=$(arg_after --terminal "$@") || h=
    [ -n "$(term_state "$h")" ] || stale
    text=$(arg_after --text "$@" || true)
    case "$text" in
      ". '"*"'")
        staged=${text#". '"}; staged=${staged%"'"}
        if [ -f "$staged" ]; then text=$(cat "$staged"); fi
        ;;
    esac
    case "$text" in
      *'encode launch-brief'*|*'Firstmate operational input waiting: read'*|*' claude '*|claude*) start_agent "$h" ;;
    esac
    printf '{"ok":true,"result":{"accepted":true}}\n'
    ;;
  worktree:show)
    printf '{"ok":true,"result":{"worktree":{"id":"%s","path":"%s"}}}\n' "$(arg_after --worktree "$@" | sed 's/^id://')" "$(arg_after --worktree "$@" | sed 's/^id://; s/^.*:://')"
    ;;
  *) printf '{"ok":true,"result":{}}\n' ;;
esac
SH
  chmod +x "$dir/fakebin/orca"
}

# orca_fake_term <dir> <handle> <worktree-id> <live|closed|exited> [shell|agent|none]
# Registers a terminal and, for a live one, its process table: a shell alone
# (the default), a shell with a harness beneath it, or nothing at all.
orca_fake_term() {
  local dir=$1 handle=$2 wt=$3 state=$4 procs=${5:-shell} pid=100
  printf '%s %s\n' "$state" "$wt" > "$dir/fake/terms/$handle"
  [ "$procs" != none ] || return 0
  while [ -d "$dir/fake/proc/$pid" ]; do pid=$((pid + 10)); done
  mkdir -p "$dir/fake/proc/$pid"
  printf 'PATH=/usr/bin\0ORCA_TERMINAL_HANDLE=%s\0' "$handle" > "$dir/fake/proc/$pid/environ"
  printf 'zsh\n' > "$dir/fake/proc/$pid/comm"
  printf 'zsh\0' > "$dir/fake/proc/$pid/cmdline"
  printf '%s (zsh) S 1 1 1 0 -1 0\n' "$pid" > "$dir/fake/proc/$pid/stat"
  if [ "$procs" = agent ]; then
    mkdir -p "$dir/fake/proc/$((pid + 1))"
    printf 'PATH=/usr/bin\0ORCA_TERMINAL_HANDLE=%s\0' "$handle" > "$dir/fake/proc/$((pid + 1))/environ"
    printf 'claude\n' > "$dir/fake/proc/$((pid + 1))/comm"
    printf 'claude\0--dangerously-skip-permissions\0' > "$dir/fake/proc/$((pid + 1))/cmdline"
    printf '%s (claude) S %s 1 1 0 -1 0\n' "$((pid + 1))" "$pid" > "$dir/fake/proc/$((pid + 1))/stat"
  fi
}

# orca_fake_proc <dir> <pid> <ppid> <comm> <argv0> <handle-or-empty>: one extra
# process in the fake table, for a case the two canned shapes do not cover.
orca_fake_proc() {
  local dir=$1 pid=$2 ppid=$3 comm=$4 argv0=$5 handle=${6:-}
  mkdir -p "$dir/fake/proc/$pid"
  if [ -n "$handle" ]; then
    printf 'PATH=/usr/bin\0ORCA_TERMINAL_HANDLE=%s\0' "$handle" > "$dir/fake/proc/$pid/environ"
  else
    printf 'PATH=/usr/bin\0' > "$dir/fake/proc/$pid/environ"
  fi
  printf '%s\n' "$comm" > "$dir/fake/proc/$pid/comm"
  printf '%s\0' "$argv0" > "$dir/fake/proc/$pid/cmdline"
  printf '%s (%s) S %s 1 1 0 -1 0\n' "$pid" "$comm" "$ppid" > "$dir/fake/proc/$pid/stat"
}

orca_fake_flag() {  # <dir> <flag> [on|off]
  if [ "${3:-on}" = off ]; then rm -f "$1/fake/flags/$2"; else : > "$1/fake/flags/$2"; fi
}

# orca_fake_run <dir> <command...>: run a command against the fake. The fake
# CLI leads PATH, the fake process table replaces /proc, the settle wait for a
# transient `other` is one sample, and every variable that could route an `orca`
# call to a real runtime or to another terminal is removed.
orca_fake_run() {
  local dir=$1
  shift
  env -u ORCA_ENVIRONMENT -u ORCA_PAIRING_CODE -u ORCA_REMOTE_PAIRING \
    -u ORCA_TERMINAL_HANDLE -u ORCA_WORKTREE_ID -u ORCA_USER_DATA_PATH -u ORCA_CLI_BIN_DIR \
    PATH="$dir/fakebin:$PATH" FM_ORCA_FAKE_DIR="$dir/fake" FM_ORCA_PROC_ROOT="$dir/fake/proc" \
    FM_BACKEND_ORCA_PROCESS_SETTLE_POLLS=1 "$@"
}

# orca_fake_calls <dir> <noun> <verb>: how many logged calls start with them.
orca_fake_calls() {
  grep -c -F "orca"$'\x1f'"$2"$'\x1f'"$3" "$1/fake/log" || true
}

# orca_fake_handles <dir> <worktree-id>: the live terminal handles of a worktree.
orca_fake_handles() {
  local f s w
  for f in "$1/fake/terms"/*; do
    [ -f "$f" ] || continue
    read -r s w < "$f"
    [ "$w" = "$2" ] && [ "$s" = live ] && printf '%s\n' "${f##*/}"
  done
}
