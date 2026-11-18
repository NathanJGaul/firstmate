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
