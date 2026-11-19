#!/usr/bin/env bash
# tests/orca-lab-safety.sh - the hard guards of the Orca live lab
# (tests/fm-backend-orca-smoke.test.sh), proven by
# tests/fm-backend-orca-lab-guard.test.sh without any Orca installed.
#
# The lab starts its own headless Orca runtime as a child, on its own data
# directory, and must never reach an operator's runtime or Orca data. It follows
# the cmux lab's posture (tests/cmux-test-safety.sh): refuse on any ambiguity,
# since a false refusal is recoverable and a false accept is not. Five rules
# carry the safety:
#
#   1. The data directory is fresh and is never, contains, or lies inside the
#      operator's Orca data or Orca installation directory (orca_lab_validate_data_dir).
#   2. Every command line the lab runs goes through a launcher pinned to that
#      directory with every other ORCA_* variable removed (orca_lab_write_launcher).
#   3. The launcher also pins HOME to a fresh lab home that is never, contains,
#      or lies inside the operator's HOME, Orca data, or agent config directories
#      (orca_lab_validate_home): the CLI computes the agent config paths that
#      `agent hooks on|off` and `skills install` write from the caller's HOME, so
#      an unpinned HOME names the operator's real agent config files. The live
#      lane proves the pin (orca_lab_paths_under_home).
#   4. The runtime starts with a PATH built from the lab's own bin and the system
#      directories, and one that can reach a real agent binary is refused
#      (orca_lab_runtime_path, orca_lab_assert_path_agent_free): the runtime
#      starts `codex ... app-server` by name about a second after it is ready.
#   5. Every signal goes to a process proven to belong to the lab
#      (orca_lab_signal), and every mutation is preceded by the proof that the
#      answering runtime is the lab's own child (orca_lab_assert_own_runtime).
#
# Object names the lab creates carry the fm-test- prefix; the lab removes
# objects by exact name or id and never enumerates-and-deletes.

# orca_lab_protected_paths: the operator paths the lab must never be, contain,
# or lie inside, one per line. Resolved at call time against the caller's HOME.
orca_lab_protected_paths() {
  [ -n "${HOME:-}" ] || return 1
  printf '%s\n' "$HOME/.orca" "$HOME/.orca-remote"
}

# orca_lab_agent_config_paths: the operator's agent config directories under the
# caller's HOME, one per line. `agent hooks` and `skills` write inside these, so
# the lab home may never be or lie inside one.
orca_lab_agent_config_paths() {
  local d
  [ -n "${HOME:-}" ] || return 1
  for d in .claude .codex .config/opencode .local/share/opencode .pi .grok .gemini .cursor .kimi .copilot .config/github-copilot .omp .agents; do
    printf '%s\n' "$HOME/$d"
  done
}

# orca_lab_resolve <path>: the physical absolute path, resolving symlinks in
# every existing component and in a dangling leaf, and keeping the unresolved
# remainder verbatim after normalizing "." and "..". Prints nothing and fails
# for an empty path.
orca_lab_resolve() {
  local path=${1:-} head tail part hops=0 link
  [ -n "$path" ] || return 1
  case "$path" in /*) ;; *) path="$PWD/$path" ;; esac
  # Normalize . and .. lexically first, then resolve links component by component.
  head=/
  tail=${path#/}
  while [ -n "$tail" ]; do
    part=${tail%%/*}
    if [ "$part" = "$tail" ]; then tail=''; else tail=${tail#*/}; fi
    case "$part" in
      '' | .) continue ;;
      ..) head=$(dirname -- "$head"); continue ;;
    esac
    local next
    if [ "$head" = / ]; then next=/$part; else next=$head/$part; fi
    while [ -L "$next" ]; do
      hops=$((hops + 1))
      [ "$hops" -le 40 ] || return 1
      link=$(readlink -- "$next") || return 1
      case "$link" in
        /*) tail="${link#/}${tail:+/$tail}"; next=/ ;;
        *) tail="$link${tail:+/$tail}"; next=$head ;;
      esac
      if [ "$next" = / ] || [ "$next" = "$head" ]; then break; fi
    done
    head=$next
  done
  printf '%s\n' "$head"
}

# orca_lab_validate_data_dir <path>: 0 when <path> may be the lab's data
# directory. Refuses (1, message on stderr, nothing created) an empty path, a
# path equal to, inside, or containing a protected operator path (resolved
# through symlinks), and an existing directory that holds any entry.
orca_lab_validate_data_dir() {
  local path=${1:-} real prot prot_real
  if [ -z "$path" ]; then
    echo "orca lab: refusing an empty data directory; ORCA_USER_DATA_PATH must name a fresh lab directory" >&2
    return 1
  fi
  real=$(orca_lab_resolve "$path") || { echo "orca lab: refusing '$path': it cannot be resolved" >&2; return 1; }
  while IFS= read -r prot; do
    [ -n "$prot" ] || continue
    prot_real=$(orca_lab_resolve "$prot") || prot_real=$prot
    case "$real/" in
      "$prot_real"/*) echo "orca lab: refusing '$path' ($real): it is, or lies inside, the operator's Orca path $prot_real" >&2; return 1 ;;
    esac
    case "$prot_real/" in
      "${real%/}"/*) echo "orca lab: refusing '$path' ($real): it is, or contains, the operator's Orca path $prot_real" >&2; return 1 ;;
    esac
  done < <(orca_lab_protected_paths)
  orca_lab_require_fresh "$path" "$real" "data directory"
}

# orca_lab_require_fresh <path> <resolved> <what>: 0 when <resolved> is absent or
# an empty directory; otherwise refuses (1, message on stderr).
orca_lab_require_fresh() {
  local path=${1:-} real=${2:-} what=${3:-directory}
  if [ -e "$real" ] && { [ ! -d "$real" ] || [ -n "$(find "$real" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; }; then
    echo "orca lab: refusing '$path': the lab only runs against a fresh, empty $what" >&2
    return 1
  fi
  return 0
}

# orca_lab_validate_home <path>: 0 when <path> may be the lab's HOME. Refuses
# (1, message on stderr, nothing created) an empty path, a path equal to or
# containing the operator's HOME (so also the filesystem root), a path equal to
# or inside a protected Orca path or an agent config directory (resolved through
# symlinks), and an existing directory that holds any entry.
orca_lab_validate_home() {
  local path=${1:-} real prot prot_real op_real
  if [ -z "$path" ]; then
    echo "orca lab: refusing an empty lab home; the launcher must pin HOME to a fresh lab directory" >&2
    return 1
  fi
  [ -n "${HOME:-}" ] || { echo "orca lab: refusing: the caller's HOME is unset, so the operator's home cannot be told apart from the lab's" >&2; return 1; }
  real=$(orca_lab_resolve "$path") || { echo "orca lab: refusing lab home '$path': it cannot be resolved" >&2; return 1; }
  op_real=$(orca_lab_resolve "$HOME") || op_real=$HOME
  case "$op_real/" in
    "${real%/}"/*) echo "orca lab: refusing lab home '$path' ($real): it is, or contains, the operator's HOME $op_real" >&2; return 1 ;;
  esac
  while IFS= read -r prot; do
    [ -n "$prot" ] || continue
    prot_real=$(orca_lab_resolve "$prot") || prot_real=$prot
    case "$real/" in
      "$prot_real"/*) echo "orca lab: refusing lab home '$path' ($real): it is, or lies inside, the operator's protected path $prot_real" >&2; return 1 ;;
    esac
    case "$prot_real/" in
      "${real%/}"/*) echo "orca lab: refusing lab home '$path' ($real): it contains the operator's protected path $prot_real" >&2; return 1 ;;
    esac
  done < <(orca_lab_protected_paths; orca_lab_agent_config_paths)
  orca_lab_require_fresh "$path" "$real" "lab home"
}

# orca_lab_pid_owned <pid> <data-dir>: 0 only when <pid> is a live process other
# than the calling shell whose environment sets ORCA_USER_DATA_PATH to exactly
# <data-dir>, or whose command line names a path inside <data-dir> (the terminal
# host takes its socket and pid record from there). Needs /proc, and refuses
# when it is unreadable, since ownership then cannot be shown.
orca_lab_pid_owned() {
  local pid=${1:-} data=${2:-}
  case "$pid" in '' | *[!0-9]*) return 1 ;; esac
  [ -n "$data" ] || return 1
  [ "$pid" != "$$" ] && [ "$pid" != "${BASHPID:-$$}" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [ -r "/proc/$pid/environ" ] || return 1
  if { tr '\0' '\n' < "/proc/$pid/environ"; } 2>/dev/null | grep -Fxq -- "ORCA_USER_DATA_PATH=$data"; then
    return 0
  fi
  if [ -r "/proc/$pid/cmdline" ] && { tr '\0' '\n' < "/proc/$pid/cmdline"; } 2>/dev/null | grep -Fq -- "$data/"; then
    return 0
  fi
  return 1
}

# orca_lab_assert_own_runtime <data-dir> <child-pid> <launcher>: 0 only when the
# runtime answering for <data-dir> is the child the lab started: the runtime
# record in <data-dir> names <child-pid>, that process is live and owned by the
# lab (orca_lab_pid_owned), and `status --json` through the lab launcher reports
# the runtime id the record holds. Every other outcome is a refusal.
orca_lab_assert_own_runtime() {
  local data=${1:-} child=${2:-} launcher=${3:-} record rec_pid rec_id live_id
  record="$data/orca-runtime.json"
  [ -n "$data" ] && [ -f "$record" ] || { echo "orca lab: refusing: no runtime record in '$data'" >&2; return 1; }
  rec_pid=$(jq -r '.pid // empty' "$record" 2>/dev/null)
  rec_id=$(jq -r '.runtimeId // empty' "$record" 2>/dev/null)
  if [ -z "$child" ] || [ "$rec_pid" != "$child" ]; then
    echo "orca lab: refusing: the runtime record names pid '${rec_pid:-none}', not the child the lab started ('${child:-none}')" >&2
    return 1
  fi
  orca_lab_pid_owned "$child" "$data" || { echo "orca lab: refusing: pid $child is not live or not owned by the lab data directory" >&2; return 1; }
  [ -n "$rec_id" ] || { echo "orca lab: refusing: the runtime record holds no runtime id" >&2; return 1; }
  live_id=$("$launcher" status --json 2>/dev/null | jq -r '.result.runtime.runtimeId // empty' 2>/dev/null)
  if [ "$live_id" != "$rec_id" ]; then
    echo "orca lab: refusing: the answering runtime id '${live_id:-none}' differs from the recorded '$rec_id'" >&2
    return 1
  fi
  return 0
}

# orca_lab_signal <signal> <pid> <data-dir>: send <signal> to <pid> only when it
# is proven to belong to the lab; otherwise send nothing and fail.
orca_lab_signal() {
  local sig=${1:-} pid=${2:-} data=${3:-}
  case "$sig" in TERM | KILL | INT | HUP | 0) ;; *) echo "orca lab: refusing signal '$sig'" >&2; return 1 ;; esac
  orca_lab_pid_owned "$pid" "$data" || { echo "orca lab: refusing to signal pid '${pid:-none}': not proven to belong to the lab" >&2; return 1; }
  kill "-$sig" "$pid"
}

# orca_lab_write_launcher <bin-dir> <data-dir> <node> <cli-entry> <home>: write
# the lab's `orca` command into <bin-dir>. Orca's own shim exports the operator's
# data directory unconditionally, so the lab never uses it: this launcher runs
# the same node and CLI entry on the lab data directory, after removing every
# ORCA_* variable the caller carries (an inherited ORCA_ENVIRONMENT or
# ORCA_PAIRING_CODE would send the command to another runtime) and NODE_OPTIONS.
# It also pins HOME to <home> and removes the agent config pointers a caller may
# carry, because `agent hooks status` names (and `hooks on|off`, `skills install`
# write) agent config files computed from the caller's HOME. <home> is required
# and refused by orca_lab_validate_home before anything is written.
orca_lab_write_launcher() {
  local bin=${1:-} data=${2:-} node=${3:-} entry=${4:-} home=${5:-}
  [ -n "$bin" ] && [ -n "$data" ] && [ -n "$node" ] && [ -n "$entry" ] || return 1
  orca_lab_validate_home "$home" || return 1
  mkdir -p "$bin" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    # shellcheck disable=SC2016  # the single quotes are deliberate: the launcher expands it
    printf 'for v in $(env | sed -n "s/^\\(ORCA_[A-Za-z0-9_]*\\)=.*/\\1/p"); do unset "$v"; done\n'
    printf 'unset NODE_OPTIONS NODE_REPL_EXTERNAL_MODULE ELECTRON_RUN_AS_NODE\n'
    printf 'unset CODEX_HOME CLAUDE_CONFIG_DIR OPENCODE_CONFIG_DIR PI_CODING_AGENT_DIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME\n'
    printf 'export HOME=%q\n' "$home"
    printf 'export ORCA_USER_DATA_PATH=%q\n' "$data"
    printf 'exec %q %q "$@"\n' "$node" "$entry"
  } > "$bin/orca" || return 1
  chmod +x "$bin/orca"
}

# orca_lab_agent_binaries: the executable names of real agent harnesses the lab
# runtime must not be able to run. The runtime starts `codex app-server` by name
# at boot and starts whatever a terminal command names. A name missing here is a
# false accept, so the list is generous.
orca_lab_agent_binaries() {
  printf '%s\n' claude codex opencode pi grok kimi cursor cursor-agent gemini copilot omp muse rovo rovodev agy devin droid
}

# orca_lab_runtime_path <lab-bin>: the PATH the lab runtime starts with: the lab's
# own bin directory (the launcher, and any fake agent) plus the system
# directories. It is built, never inherited, so no operator tool directory rides
# along. Fails for an empty or relative lab bin.
orca_lab_runtime_path() {
  local bin=${1:-}
  case "$bin" in /*) ;; *) return 1 ;; esac
  case "$bin" in *:*) return 1 ;; esac
  printf '%s:/usr/bin:/bin\n' "$bin"
}

# orca_lab_assert_path_agent_free <path>: 0 only when every entry of <path> is an
# absolute directory that holds no executable named for a real agent harness.
# An empty or relative entry resolves against the working directory, so it is
# refused too. Refusals name the entry and the agent.
orca_lab_assert_path_agent_free() {
  local path=${1:-} rest entry agent
  if [ -z "$path" ]; then
    echo "orca lab: refusing an empty runtime PATH" >&2
    return 1
  fi
  rest="$path:"
  while [ -n "$rest" ]; do
    entry=${rest%%:*}
    rest=${rest#*:}
    case "$entry" in
      /*) ;;
      *) echo "orca lab: refusing runtime PATH '$path': entry '${entry:-<empty>}' is not an absolute directory, so it resolves against the working directory" >&2; return 1 ;;
    esac
    while IFS= read -r agent; do
      if [ -f "$entry/$agent" ] && [ -x "$entry/$agent" ]; then
        echo "orca lab: refusing runtime PATH: '$entry' holds the real agent '$agent', and the runtime would run it by name" >&2
        return 1
      fi
    done < <(orca_lab_agent_binaries)
  done
  return 0
}

# orca_lab_paths_under_home <home> <hooks-status-json>: 0 only when the report
# names at least one configPath and every configPath lies inside <home>. The
# live lane feeds it `agent hooks status --json` through the launcher, which is
# the observable proof that the HOME pin reached the CLI. A report naming no path
# proves nothing and is refused.
orca_lab_paths_under_home() {
  local home=${1:-} json=${2:-} paths p home_real n=0
  [ -n "$home" ] || { echo "orca lab: refusing: no lab home to check config paths against" >&2; return 1; }
  paths=$(printf '%s' "$json" | jq -r '[.. | objects | .configPath? | strings] | .[]' 2>/dev/null) || { echo "orca lab: refusing: the hooks status report is not parsable JSON" >&2; return 1; }
  home_real=$(orca_lab_resolve "$home") || home_real=$home
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    case "$p" in *"/../"* | */..) echo "orca lab: refusing config path '$p': it climbs with '..'" >&2; return 1 ;; esac
    case "$p" in
      "${home%/}"/* | "${home_real%/}"/*) ;;
      *) echo "orca lab: refusing config path '$p': it lies outside the lab home '$home'" >&2; return 1 ;;
    esac
  done <<<"$paths"
  [ "$n" -gt 0 ] || { echo "orca lab: refusing: the hooks status report names no config path, so the HOME pin is unproven" >&2; return 1; }
  return 0
}

# orca_lab_pid_running <pid>: live and not a zombie.
orca_lab_pid_running() {
  local pid=${1:-} state
  kill -0 "$pid" 2>/dev/null || return 1
  state=$(sed -n 's/^State:[[:space:]]*\(.\).*/\1/p' "/proc/$pid/status" 2>/dev/null)
  [ "$state" != Z ] && [ "$state" != X ]
}

# orca_lab_leftovers <lab-dir> <data-dir>: pids (one per line) of live
# processes other than the caller whose environment sets ORCA_USER_DATA_PATH to
# <data-dir> or whose command line names <lab-dir>. A process whose /proc
# entries are unreadable is skipped, since it is not the same user's.
orca_lab_leftovers() {
  local lab=${1:-} data=${2:-} d pid
  [ -n "$lab" ] && [ -n "$data" ] || return 1
  for d in /proc/[0-9]*; do
    pid=${d#/proc/}
    [ "$pid" != "$$" ] && [ "$pid" != "${BASHPID:-$$}" ] || continue
    orca_lab_pid_running "$pid" || continue
    if { tr '\0' '\n' < "$d/environ"; } 2>/dev/null | grep -Fxq -- "ORCA_USER_DATA_PATH=$data"; then
      printf '%s\n' "$pid"
    elif { tr '\0' '\n' < "$d/cmdline"; } 2>/dev/null | grep -Fq -- "$lab"; then
      printf '%s\n' "$pid"
    fi
  done
}

# orca_lab_wait_gone <pid> [seconds]: wait for <pid> to stop running.
orca_lab_wait_gone() {
  local pid=$1 n=$(( ${2:-20} * 5 ))
  while [ "$n" -gt 0 ]; do
    orca_lab_pid_running "$pid" || return 0
    sleep 0.2
    n=$((n - 1))
  done
  return 1
}

# orca_lab_stop <lab-dir> <data-dir> <child-pid> <launcher>: stop everything the
# lab started, signalling only what is proven to be the lab's. In order: the
# runtime child (after the own-runtime proof), the terminal host named by the
# pid records under <data-dir>/daemon, then any remaining process the leftover
# scan finds. A leftover that cannot be proven the lab's is reported and left
# running, and the function fails. Returns 0 only when nothing is left.
orca_lab_stop() {
  local lab=${1:-} data=${2:-} child=${3:-} launcher=${4:-} rec pid left rc=0
  if orca_lab_assert_own_runtime "$data" "$child" "$launcher" 2>/dev/null; then
    orca_lab_signal TERM "$child" "$data" || true
    orca_lab_wait_gone "$child" 20 || orca_lab_signal KILL "$child" "$data" || true
  fi
  for rec in "$data"/daemon/*.pid; do
    [ -f "$rec" ] || continue
    pid=$(jq -r '.pid // empty' "$rec" 2>/dev/null)
    orca_lab_pid_owned "$pid" "$data" || continue
    orca_lab_signal TERM "$pid" "$data" || true
    orca_lab_wait_gone "$pid" 10 || orca_lab_signal KILL "$pid" "$data" || true
  done
  for pid in $(orca_lab_leftovers "$lab" "$data"); do
    if orca_lab_pid_owned "$pid" "$data"; then
      orca_lab_signal TERM "$pid" "$data" || true
      orca_lab_wait_gone "$pid" 5 || orca_lab_signal KILL "$pid" "$data" || true
    fi
  done
  sleep 0.2
  left=$(orca_lab_leftovers "$lab" "$data")
  if [ -n "$left" ]; then
    echo "orca lab: processes still naming the lab after stop (left running, not provably the lab's): ${left//$'\n'/ }" >&2
    rc=1
  fi
  return $rc
}
