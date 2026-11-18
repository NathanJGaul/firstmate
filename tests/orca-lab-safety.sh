#!/usr/bin/env bash
# tests/orca-lab-safety.sh - the hard guards of the Orca live lab
# (tests/fm-backend-orca-smoke.test.sh), proven by
# tests/fm-backend-orca-lab-guard.test.sh without any Orca installed.
#
# The lab starts its own headless Orca runtime as a child, on its own data
# directory, and must never reach an operator's runtime or Orca data. It follows
# the cmux lab's posture (tests/cmux-test-safety.sh): refuse on any ambiguity,
# since a false refusal is recoverable and a false accept is not. Three rules
# carry the safety:
#
#   1. The data directory is fresh and is never, contains, or lies inside the
#      operator's Orca data or Orca installation directory (orca_lab_validate_data_dir).
#   2. Every command line the lab runs goes through a launcher pinned to that
#      directory with every other ORCA_* variable removed (orca_lab_write_launcher).
#   3. Every signal goes to a process proven to belong to the lab
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
  if [ -e "$real" ] && { [ ! -d "$real" ] || [ -n "$(find "$real" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; }; then
    echo "orca lab: refusing '$path': the lab only runs against a fresh, empty data directory" >&2
    return 1
  fi
  return 0
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
  if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -Fxq -- "ORCA_USER_DATA_PATH=$data"; then
    return 0
  fi
  if [ -r "/proc/$pid/cmdline" ] && tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -Fq -- "$data/"; then
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

# orca_lab_write_launcher <bin-dir> <data-dir> <node> <cli-entry>: write the
# lab's `orca` command into <bin-dir>. Orca's own shim exports the operator's
# data directory unconditionally, so the lab never uses it: this launcher runs
# the same node and CLI entry on the lab data directory, after removing every
# ORCA_* variable the caller carries (an inherited ORCA_ENVIRONMENT or
# ORCA_PAIRING_CODE would send the command to another runtime) and NODE_OPTIONS.
orca_lab_write_launcher() {
  local bin=${1:-} data=${2:-} node=${3:-} entry=${4:-}
  [ -n "$bin" ] && [ -n "$data" ] && [ -n "$node" ] && [ -n "$entry" ] || return 1
  mkdir -p "$bin" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    printf 'for v in $(env | sed -n "s/^\\(ORCA_[A-Za-z0-9_]*\\)=.*/\\1/p"); do unset "$v"; done\n'
    printf 'unset NODE_OPTIONS NODE_REPL_EXTERNAL_MODULE ELECTRON_RUN_AS_NODE\n'
    printf 'export ORCA_USER_DATA_PATH=%q\n' "$data"
    printf 'exec %q %q "$@"\n' "$node" "$entry"
  } > "$bin/orca" || return 1
  chmod +x "$bin/orca"
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
    if tr '\0' '\n' < "$d/environ" 2>/dev/null | grep -Fxq -- "ORCA_USER_DATA_PATH=$data"; then
      printf '%s\n' "$pid"
    elif tr '\0' '\n' < "$d/cmdline" 2>/dev/null | grep -Fq -- "$lab"; then
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
    echo "orca lab: processes still naming the lab after stop (left running, not provably the lab's): $(echo $left)" >&2
    rc=1
  fi
  return $rc
}
