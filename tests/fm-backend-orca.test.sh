#!/usr/bin/env bash
# tests/fm-backend-orca.test.sh - fake-Orca-CLI unit tests for the Orca
# terminal adapter primitives in bin/backends/orca.sh.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-backend-orca-tests)
FM_TEST_REPO="$TMP_ROOT/repo-path"
git init -q "$FM_TEST_REPO"
export FM_TEST_REPO
# A claude spawn writes workspace trust into the launching user's own store,
# and the script resolves it as ${CLAUDE_CONFIG_DIR:-${HOME:-}}, so the value
# is pinned EMPTY beside the throwaway HOME: an inherited one would beat that
# HOME and reach the developer's real store, while empty falls through to it
# and adds no launch prefix, since fm-spawn only prefixes a non-empty value.
SPAWN_HOME="$TMP_ROOT/user-home"
mkdir -p "$SPAWN_HOME"

write_spawn_brief() {  # <data-dir> <id>
  local data=$1 id=$2
  cat > "$data/$id/brief.md" <<'EOF'
# Task
## Captain's intent
Exercise Orca dispatch.

## Firstmate spec
Verify the Orca lifecycle behavior under test.
EOF
}

make_orca_fakebin() {  # <dir> -> echoes fakebin dir
  local fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/orca" <<'SH'
#!/usr/bin/env bash
set -u
LOG="${FM_ORCA_LOG:?}"
RESP="${FM_ORCA_RESPONSES:?}"
COUNT_FILE="$RESP/.count"
next=$(( $(cat "$COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
{
  printf 'orca'
  for a in "$@"; do printf '\x1f%s' "$a"; done
  printf '\n'
} >> "$LOG"
if [ "${1:-}" = status ] && [ -n "${FM_ORCA_STATUS_FILE:-}" ]; then
  cat "$FM_ORCA_STATUS_FILE"
  exit "${FM_ORCA_STATUS_EXIT:-0}"
fi
if [ "${1:-}" = status ] && [ "${FM_ORCA_STATUS_RESPONSE:-ready}" != sequence ]; then
  # FM_ORCA_STATUS_RAW answers verbatim (with FM_ORCA_STATUS_EXIT); FM_ORCA_STATUS_CAPS
  # lists runtime capabilities; neither set is the plain ready status.
  if [ "${FM_ORCA_STATUS_RAW+set}" = set ]; then
    printf '%s' "$FM_ORCA_STATUS_RAW"
    exit "${FM_ORCA_STATUS_EXIT:-0}"
  fi
  if [ -n "${FM_ORCA_STATUS_CAPS:-}" ]; then
    printf '{"ok":true,"result":{"runtime":{"reachable":true,"state":"ready","capabilities":%s}}}\n' "$FM_ORCA_STATUS_CAPS"
    exit 0
  fi
  printf '{"ok":true,"result":{"runtime":{"reachable":true,"state":"ready"}}}\n'
  exit 0
fi
# A verb answered by name (by-<noun>-<verb>.out and .exit) does not use the call
# count, so a whole-script run is not tied to the order of its calls.
verb="${1:-}-${2:-}"
if [ -f "$RESP/by-$verb.out" ] || [ -f "$RESP/by-$verb.exit" ]; then
  [ ! -f "$RESP/by-$verb.out" ] || cat "$RESP/by-$verb.out"
  [ ! -f "$RESP/by-$verb.exit" ] || exit "$(cat "$RESP/by-$verb.exit")"
  exit 0
fi
# `terminal list` is answered from its own keyed files and never advances the
# numbered sequence, so a case's numbered responses keep their meaning whether
# or not the adapter lists a worktree's terminals. With no keyed file the
# worktree holds no terminal.
if [ "${1:-}" = terminal ] && [ "${2:-}" = list ]; then
  if [ -f "$RESP/terminal-list.exit" ]; then
    exit "$(cat "$RESP/terminal-list.exit")"
  fi
  if [ -f "$RESP/terminal-list.out" ]; then
    cat "$RESP/terminal-list.out"
  else
    printf '{"ok":true,"result":{"terminals":[],"totalCount":0,"truncated":false}}\n'
  fi
  exit 0
fi
n=$next
echo "$n" > "$COUNT_FILE"
if [ -f "$RESP/$n.exit" ]; then
  # An answer and a failing exit status together, as the real CLI gives on ok:false.
  [ ! -f "$RESP/$n.out" ] || cat "$RESP/$n.out"
  exit "$(cat "$RESP/$n.exit")"
fi
[ -f "$RESP/$n.out" ] && cat "$RESP/$n.out"
exit 0
SH
  chmod +x "$fb/orca"
  printf '%s\n' "$fb"
}

orca_case() {  # <name> -> sets CASE_DIR LOG RESP FB
  CASE_DIR="$TMP_ROOT/$1"
  mkdir -p "$CASE_DIR/responses"
  LOG="$CASE_DIR/log"
  RESP="$CASE_DIR/responses"
  : > "$LOG"
  FB=$(make_orca_fakebin "$CASE_DIR")
}

neutral_fm_root() {  # <dir> -> echoes a minimal root with a quiet guard
  local root="$1/root"
  mkdir -p "$root/bin"
  cat > "$root/bin/fm-guard.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$root/bin/fm-guard.sh"
  printf '%s\n' "$root"
}

add_tmux_fake() {
  local fb=$1
  cat > "$fb/tmux" <<'SH'
#!/usr/bin/env bash
set -u
LOG="${FM_ORCA_LOG:?}"
{
  printf 'tmux'
  for a in "$@"; do printf '\x1f%s' "$a"; done
  printf '\n'
} >> "$LOG"
exit 0
SH
  chmod +x "$fb/tmux"
}

# orca_worktree_response: an Orca `worktree create` JSON result. <shape> picks
# which first-terminal shape the runtime reports: none, terminal (the verified
# result.terminal), startup (Orca 1.4.261's result.startupTerminal), both,
# startup-nospawned (no spawned flag), startup-unspawned (spawned false),
# startup-emptyhandle, or startup-nohandle. A blank <path> omits the path.
orca_worktree_response() {  # <worktree-id> <path-or-empty> <shape>
  local id=$1 path=$2 shape=$3 wt term=
  if [ -n "$path" ]; then
    wt=$(printf '{"id":"%s","path":"%s"}' "$id" "$path")
  else
    wt=$(printf '{"id":"%s"}' "$id")
  fi
  case "$shape" in
    none) ;;
    terminal) term=',"terminal":{"handle":"term-legacy"}' ;;
    startup) term=',"startupTerminal":{"spawned":true,"handle":"term-startup","tabId":"tab-1","paneKey":"pane-1","ptyId":"pty-1","surface":"background"}' ;;
    both) term=',"terminal":{"handle":"term-legacy"},"startupTerminal":{"spawned":true,"handle":"term-startup"}' ;;
    startup-nospawned) term=',"startupTerminal":{"handle":"term-startup"}' ;;
    startup-unspawned) term=',"startupTerminal":{"spawned":false,"handle":"term-startup"}' ;;
    startup-emptyhandle) term=',"startupTerminal":{"spawned":true,"handle":""}' ;;
    startup-nohandle) term=',"startupTerminal":{"spawned":true}' ;;
    *) fail "unknown worktree response shape '$shape'" ;;
  esac
  printf '{"ok":true,"result":{"worktree":%s%s}}\n' "$wt" "$term"
}

# orca_log_count: how many logged Orca calls start with <noun> <verb>.
orca_log_count() {  # <noun> <verb> [log]
  grep -c -F "orca"$'\x1f'"$1"$'\x1f'"$2" "${3:-$LOG}" || true
}

# run_orca_spawn: spawn <id> through fm-spawn --backend orca against a fake
# Orca whose worktree creation reports <shape>. Sets SPAWN_OUT, SPAWN_RC,
# SPAWN_STATE, SPAWN_WT and the case's LOG and RESP. Extra
# arguments are numbered responses, "<n>=<json>" or "<n>=exit:<code>", written
# before the run. SPAWN_OMIT_PATH=1 leaves the path out of the worktree result.
run_orca_spawn() {  # <case> <id> <shape> [<n>=<json>...]
  local case_name=$1 id=$2 shape=$3 proj data config arg staged result_path spawn_path cli_env
  shift 3
  proj="$TMP_ROOT/$case_name-project"
  SPAWN_WT="$TMP_ROOT/$case_name-wt"
  data="$TMP_ROOT/$case_name-data"
  SPAWN_STATE="$TMP_ROOT/$case_name-state"
  config="$TMP_ROOT/$case_name-config"
  fm_git_worktree "$proj" "$SPAWN_WT" "fm/$id"
  mkdir -p "$data/$id" "$SPAWN_STATE" "$config"
  write_spawn_brief "$data" "$id"
  touch "$SPAWN_STATE/.last-watcher-beat"
  orca_case "$case_name"
  printf '1\n' > "$RESP/1.exit"
  if [ -n "${SPAWN_REPO_SHOW:-}" ]; then
    # The repository is already registered: `repo show` answers with this JSON.
    rm -f "$RESP/1.exit"
    printf '%s\n' "$SPAWN_REPO_SHOW" > "$RESP/1.out"
  fi
  printf '{"ok":true,"result":{"repo":{"id":"repo-%s"}}}\n' "$case_name" > "$RESP/2.out"
  result_path=$SPAWN_WT
  [ "${SPAWN_OMIT_PATH:-0}" != 1 ] || result_path=
  orca_worktree_response "wt-$case_name::/orca/wt-$case_name" "$result_path" "$shape" > "$RESP/3.out"
  for arg in "$@"; do
    case "${arg#*=}" in
      exit:*) printf '%s\n' "${arg#*=exit:}" > "$RESP/${arg%%=*}.exit" ;;
      *) printf '%s\n' "${arg#*=}" > "$RESP/${arg%%=*}.out" ;;
    esac
  done
  # ORCA_CLI_BIN_DIR is always pinned so an inherited one never reaches a case.
  # SPAWN_ORCA_ONLY_VIA_ENV=1 takes the fake off PATH and offers it only through
  # ORCA_CLI_BIN_DIR, the way a shell outside an Orca terminal sees the CLI.
  spawn_path="$FB:$PATH"
  cli_env=
  if [ "${SPAWN_ORCA_ONLY_VIA_ENV:-0}" = 1 ]; then
    orca_free_path
    spawn_path=$ORCA_FREE_PATH_CACHE
    cli_env=$FB
  fi
  SPAWN_OUT=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$spawn_path" ORCA_CLI_BIN_DIR="$cli_env" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$SPAWN_STATE" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  SPAWN_RC=$?
  staged=$(tr '\037' '\n' < "$LOG" | sed -n "s/^\. '\([^']*\)'$/\1/p" | tail -1)
  [ -z "$staged" ] || rm -rf "$(dirname "$staged")"
  rm -rf "/tmp/fm-$id"
}

test_json_get_reads_repo_kind() {
  local out status
  out=$( printf '{"ok":true,"result":{"repo":{"id":"r1","kind":"folder"}}}\n' | \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_json_get repo-kind' "$ROOT" )
  [ "$out" = folder ] || fail "repo-kind should read result.repo.kind, got '$out'"
  out=$( printf '{"ok":true,"result":{"id":"r1","kind":"git"}}\n' | \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_json_get repo-kind' "$ROOT" )
  [ "$out" = git ] || fail "repo-kind should fall back to result.kind, got '$out'"
  status=0
  out=$( printf '{"ok":true,"result":{"repo":{"id":"r1"}}}\n' | \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_json_get repo-kind' "$ROOT" ) || status=$?
  [ "$status" -ne 0 ] && [ -z "$out" ] || fail "repo-kind should be empty when no kind is reported, got '$out' (status $status)"
  pass "fm_backend_orca_json_get: repo-kind reads the repository kind and is empty when absent"
}

test_repo_ensure_refuses_a_folder_repo() {
  local out status
  orca_case repo-ensure-folder
  printf '{"ok":true,"result":{"repo":{"id":"repo-folder","kind":"folder"}}}\n' > "$RESP/1.out"
  status=0
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_repo_ensure /repo/folder-project' "$ROOT" 2>&1 ) || status=$?
  [ "$status" -ne 0 ] || fail "repo_ensure should refuse a folder-kind repository, got '$out'"
  assert_contains "$out" "/repo/folder-project" "the folder refusal should name the project"
  assert_contains "$out" "folder" "the folder refusal should say Orca holds the project as a folder"
  assert_contains "$out" "--backend" "the folder refusal should name the per-task --backend escape hatch"
  assert_not_contains "$out" "repo-folder" "a refused folder repository must not print a repository id"
  [ "$(orca_log_count repo show)" -eq 1 ] || fail "the refusal should read the registration once, log: $(cat "$LOG")"
  [ "$(grep -c . "$LOG")" -eq 1 ] || fail "the refusal should issue no Orca call besides repo show, log: $(cat "$LOG")"
  pass "fm_backend_orca_repo_ensure: refuses a folder repository naming --backend and changes nothing"
}

test_repo_ensure_accepts_git_and_kindless_repos() {
  local out kind
  for kind in git none; do
    orca_case "repo-ensure-$kind"
    if [ "$kind" = git ]; then
      printf '{"ok":true,"result":{"repo":{"id":"repo-%s","kind":"git"}}}\n' "$kind" > "$RESP/1.out"
    else
      printf '{"ok":true,"result":{"repo":{"id":"repo-%s"}}}\n' "$kind" > "$RESP/1.out"
    fi
    out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
      bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_repo_ensure /repo/ok-project' "$ROOT" )
    [ "$out" = "repo-$kind" ] || fail "repo_ensure should return the id for kind '$kind', got '$out'"
    [ "$(orca_log_count repo add)" -eq 0 ] || fail "a registered '$kind' repository must not be added again"
  done
  pass "fm_backend_orca_repo_ensure: a git or kindless registered repository is used as before"
}

test_repo_ensure_unregistered_path_probes_git_before_add() {
  local out status plain="$TMP_ROOT/unreg-plain" repo="$TMP_ROOT/unreg-git"
  mkdir -p "$plain"
  git init -q "$repo"
  orca_case repo-ensure-unreg-plain
  printf '1\n' > "$RESP/1.exit"
  status=0
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_repo_ensure "$1"' "$ROOT" "$plain" 2>&1 ) || status=$?
  [ "$status" -ne 0 ] || fail "an unregistered non-git path should be refused, got '$out'"
  assert_contains "$out" "--backend" "the refusal should name the per-task --backend escape hatch"
  [ "$(orca_log_count repo add)" -eq 0 ] || fail "a non-git path must never reach repo add, log: $(cat "$LOG")"
  orca_case repo-ensure-unreg-git
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-new","kind":"git"}}}\n' > "$RESP/2.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_repo_ensure "$1"' "$ROOT" "$repo" )
  [ "$out" = repo-new ] || fail "an unregistered git path should be added, got '$out'"
  [ "$(orca_log_count repo add)" -eq 1 ] || fail "a git path should be added once, log: $(cat "$LOG")"
  pass "fm_backend_orca_repo_ensure: an unregistered non-git path is refused before repo add, a git path is added"
}

test_spawn_refuses_a_folder_kind_repo_before_any_mutation() {
  local id=orcafolderz9 log verb
  SPAWN_REPO_SHOW='{"ok":true,"result":{"repo":{"id":"repo-folder-spawn","kind":"folder"}}}' \
    run_orca_spawn folder-spawn "$id" startup
  [ "$SPAWN_RC" -ne 0 ] || fail "spawn should refuse a folder-registered project on Orca, got: $SPAWN_OUT"
  assert_contains "$SPAWN_OUT" "folder" "the spawn refusal should say the project is a folder repository"
  assert_contains "$SPAWN_OUT" "--backend" "the spawn refusal should name the per-task --backend escape hatch"
  log=$(cat "$LOG")
  for verb in "repo add" "repo rm" "repo set" "worktree create" "terminal"; do
    assert_not_contains "$log" "orca"$'\x1f'"${verb%% *}"$'\x1f'"${verb#* }" "the folder refusal must not log '$verb'"
  done
  assert_not_contains "$log" $'orca\x1f''terminal' "the folder refusal must not touch a terminal"
  assert_absent "$SPAWN_STATE/$id.meta" "the folder refusal must not record task metadata"
  pass "fm-spawn.sh --backend orca: refuses a folder-kind repository before any worktree, terminal, or registration change"
}

# orca_free_path: the caller's PATH with no orca on it. Building it walks every
# PATH directory, so it is built once per run and reused (call it directly, never
# in a command substitution, or the cache is lost with the subshell).
ORCA_FREE_PATH_CACHE=
orca_free_path() {
  [ -n "$ORCA_FREE_PATH_CACHE" ] || ORCA_FREE_PATH_CACHE=$(fm_test_base_path_sans "$PATH" orca)
}

# make_marker_orca: a stand-in `orca` that only records which copy ran, so a
# resolution test can tell the candidate locations apart.
make_marker_orca() {  # <dir> <marker>
  mkdir -p "$1"
  # shellcheck disable=SC2016  # Single quotes are deliberate: the ${...} belongs to the generated script.
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" >> "${FM_ORCA_LOG:?}"\nprintf "{\\"ok\\":true,\\"result\\":{}}\\n"\n' "$2" > "$1/orca"
  chmod +x "$1/orca"
}

# resolve_orca_cli: run the adapter's tool check with the CLI offered only in
# the named candidate locations, then call `orca` the way an adapter primitive
# would. Sets RESOLVE_RC, RESOLVE_OUT, RESOLVE_LOG and RESOLVE_MARKER (which
# copy ran, empty when none did). HOME is a throwaway so the operator's real
# ~/.orca/cli/bin can never be found, and the base path carries no orca.
#   on_path  0|1
#   env_mode unset|empty|missing|nonexec|dir|ok
#   home_has 0|1
resolve_orca_cli() {  # <case> <on_path> <env_mode> <home_has>
  local case_name=$1 on_path=$2 env_mode=$3 home_has=$4 d pathdir envdir home sans
  local -a env_arg
  d="$TMP_ROOT/$case_name"
  rm -rf "$d"
  pathdir="$d/path"; envdir="$d/env"; home="$d/home"
  mkdir -p "$pathdir" "$envdir" "$home/.orca/cli/bin"
  RESOLVE_LOG="$d/log"
  : > "$RESOLVE_LOG"
  [ "$on_path" != 1 ] || make_marker_orca "$pathdir" path
  env_arg=(ORCA_CLI_BIN_DIR="$envdir")
  case "$env_mode" in
    unset) env_arg=(-u ORCA_CLI_BIN_DIR) ;;
    empty) env_arg=(ORCA_CLI_BIN_DIR=) ;;
    missing) env_arg=(ORCA_CLI_BIN_DIR="$d/nowhere") ;;
    nonexec) printf '#!/bin/sh\n' > "$envdir/orca"; chmod 644 "$envdir/orca" ;;
    dir) mkdir "$envdir/orca" ;;
    ok) make_marker_orca "$envdir" env ;;
    *) fail "unknown env mode '$env_mode'" ;;
  esac
  [ "$home_has" != 1 ] || make_marker_orca "$home/.orca/cli/bin" home
  orca_free_path
  sans=$ORCA_FREE_PATH_CACHE
  ! PATH="$sans" command -v orca >/dev/null 2>&1 || fail "the orca-free search path still resolved orca"
  PATH="$sans" command -v bash >/dev/null 2>&1 || fail "the orca-free search path lost bash, so this case would pass vacuously"
  RESOLVE_RC=0
  # shellcheck disable=SC2016  # Single quotes are deliberate: $0 belongs to the inner bash.
  RESOLVE_OUT=$( env "${env_arg[@]}" HOME="$home" PATH="$pathdir:$sans" FM_ORCA_LOG="$RESOLVE_LOG" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_tool_check && orca worktree show' "$ROOT" 2>&1 ) || RESOLVE_RC=$?
  RESOLVE_MARKER=$(tail -n 1 "$RESOLVE_LOG")
}

test_tool_check_resolution_order() {
  resolve_orca_cli cli-all 1 ok 1
  [ "$RESOLVE_RC" -eq 0 ] && [ "$RESOLVE_MARKER" = path ] \
    || fail "PATH should win over ORCA_CLI_BIN_DIR and ~/.orca/cli/bin, ran '$RESOLVE_MARKER' (rc $RESOLVE_RC): $RESOLVE_OUT"
  resolve_orca_cli cli-env-only 0 ok 0
  [ "$RESOLVE_RC" -eq 0 ] && [ "$RESOLVE_MARKER" = env ] \
    || fail "a CLI only under ORCA_CLI_BIN_DIR should be found and run, ran '$RESOLVE_MARKER' (rc $RESOLVE_RC): $RESOLVE_OUT"
  resolve_orca_cli cli-home-only 0 unset 1
  [ "$RESOLVE_RC" -eq 0 ] && [ "$RESOLVE_MARKER" = home ] \
    || fail "a CLI only under ~/.orca/cli/bin should be found and run, ran '$RESOLVE_MARKER' (rc $RESOLVE_RC): $RESOLVE_OUT"
  resolve_orca_cli cli-env-and-home 0 ok 1
  [ "$RESOLVE_RC" -eq 0 ] && [ "$RESOLVE_MARKER" = env ] \
    || fail "ORCA_CLI_BIN_DIR should beat ~/.orca/cli/bin, ran '$RESOLVE_MARKER' (rc $RESOLVE_RC): $RESOLVE_OUT"
  pass "fm_backend_orca_tool_check: resolves the CLI from PATH, then ORCA_CLI_BIN_DIR, then ~/.orca/cli/bin"
}

test_tool_check_skips_unusable_candidates() {
  local mode
  for mode in empty missing nonexec dir; do
    resolve_orca_cli "cli-skip-$mode" 0 "$mode" 1
    [ "$RESOLVE_RC" -eq 0 ] && [ "$RESOLVE_MARKER" = home ] \
      || fail "an ORCA_CLI_BIN_DIR that is $mode should fall through to ~/.orca/cli/bin, ran '$RESOLVE_MARKER' (rc $RESOLVE_RC): $RESOLVE_OUT"
  done
  pass "fm_backend_orca_tool_check: skips an empty, missing, non-executable, or directory candidate"
}

test_tool_check_refusal_is_actionable() {
  resolve_orca_cli cli-none 0 unset 0
  [ "$RESOLVE_RC" -ne 0 ] || fail "tool check should refuse when no location holds the CLI, got: $RESOLVE_OUT"
  assert_contains "$RESOLVE_OUT" "backend=orca selected but the 'orca' CLI is not installed" "the refusal should keep naming the missing CLI"
  assert_contains "$RESOLVE_OUT" "PATH" "the refusal should name PATH"
  assert_contains "$RESOLVE_OUT" "ORCA_CLI_BIN_DIR" "the refusal should name ORCA_CLI_BIN_DIR"
  assert_contains "$RESOLVE_OUT" ".orca/cli/bin" "the refusal should name the ~/.orca/cli/bin shim directory"
  [ ! -s "$RESOLVE_LOG" ] || fail "the refusal should make no Orca call, log: $(cat "$RESOLVE_LOG")"
  pass "fm_backend_orca_tool_check: an absent CLI is refused naming every searched location and the fix"
}

test_worktree_create_uses_a_cli_found_off_path() {
  local out home
  orca_case create-off-path
  home="$CASE_DIR/home"
  mkdir -p "$home"
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-off-path"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-off::/orca/wt-off","path":"/tmp/orca-wt-off"}}}\n' > "$RESP/3.out"
  orca_free_path
  out=$( HOME="$home" ORCA_CLI_BIN_DIR="$FB" PATH="$ORCA_FREE_PATH_CACHE" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_worktree_create "$FM_TEST_REPO" fm-task' "$ROOT" 2>&1 ) \
    || fail "worktree create should work with the CLI only under ORCA_CLI_BIN_DIR, got: $out"
  [ "$out" = $'wt-off::/orca/wt-off\t/tmp/orca-wt-off' ] || fail "worktree create printed '$out'"
  [ "$(orca_log_count worktree create)" -eq 1 ] || fail "worktree create should have reached the CLI found off PATH, log: $(cat "$LOG")"
  pass "fm_backend_orca_worktree_create: every Orca call uses a CLI found off PATH"
}

test_spawn_finds_the_orca_cli_under_orca_cli_bin_dir() {
  local id=orcacliz10
  SPAWN_ORCA_ONLY_VIA_ENV=1 run_orca_spawn cli-env-spawn "$id" startup
  [ "$SPAWN_RC" -eq 0 ] || fail "spawn should complete with the CLI only under ORCA_CLI_BIN_DIR, got: $SPAWN_OUT"
  assert_contains "$SPAWN_OUT" "spawned $id " "spawn did not report the task as spawned"
  [ "$(orca_log_count worktree create)" -eq 1 ] || fail "spawn should have created the worktree through the CLI found off PATH"
  assert_grep "backend=orca" "$SPAWN_STATE/$id.meta" "meta missing backend=orca"
  pass "fm-spawn.sh --backend orca: runs with the CLI only under ORCA_CLI_BIN_DIR"
}

test_capture_reads_terminal_tail_json() {
  local out
  orca_case capture-tail
  printf '{"result":{"terminal":{"tail":["line one","line two"]}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_capture term-123 40' "$ROOT" )
  [ "$out" = $'line one\nline two' ] || fail "capture should print result.terminal.tail joined by newlines, got '$out'"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''read'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--limit'$'\x1f''40'$'\x1f''--json' \
    "capture did not call orca terminal read with terminal/limit/json"
  pass "fm_backend_orca_capture: parses result.terminal.tail and calls terminal read"
}

test_capture_falls_back_to_text_fields() {
  local out
  orca_case capture-text
  printf '{"result":{"text":"plain text output"}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_capture term-abc 5' "$ROOT" )
  [ "$out" = "plain text output" ] || fail "capture should fall back to result.text, got '$out'"
  pass "fm_backend_orca_capture: falls back to result text fields"
}

test_capture_fails_on_orca_error_json() {
  local out status
  orca_case capture-error-json
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_capture term-stale 5' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "capture should fail on Orca ok:false read JSON"
  assert_contains "$out" "terminal handle stale" "capture should surface the Orca read error message"
  pass "fm_backend_orca_capture: fails closed on Orca read error JSON"
}

test_runtime_check_accepts_ready_orca_status() {
  local out
  orca_case runtime-ready
  printf '{"ok":true,"result":{"runtime":{"reachable":true,"state":"ready"}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_RESPONSE=sequence \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_runtime_check' "$ROOT" )
  [ -z "$out" ] || fail "runtime_check should be quiet on ready status, got '$out'"
  assert_contains "$(cat "$LOG")" $'orca\x1f''status'$'\x1f''--json' \
    "runtime_check did not call orca status --json"
  pass "fm_backend_orca_runtime_check: accepts reachable ready runtime"
}

test_runtime_check_refuses_unready_orca_status() {
  local out status
  orca_case runtime-unready
  printf '{"ok":true,"result":{"runtime":{"reachable":false,"state":"starting"}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_RESPONSE=sequence \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_runtime_check' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "runtime_check should fail when Orca runtime is not ready"
  assert_contains "$out" "requires a ready Orca runtime" "runtime_check should explain the readiness requirement"
  pass "fm_backend_orca_runtime_check: fails closed when runtime is not ready"
}

test_send_text_submit_verifies_empty_composer_after_enter() {
  local out
  orca_case send-submit
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/1.out"
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["╭───╮","│ > │","╰───╯"]}}}\n' > "$RESP/3.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 "hello captain" 3 0.01 0.01' "$ROOT" )
  [ "$out" = empty ] || fail "send_text_submit should report empty on successful Orca send, got '$out'"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--text'$'\x1f''hello captain'$'\x1f''--json' \
    "send_text_submit did not type the text literally before Enter"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--text'$'\x1f\x1f''--enter'$'\x1f''--json' \
    "send_text_submit did not send Enter after typing"
  # The composer read is ONE bounded tail read: the old backward paging
  # (--cursor follow-ups on a limited page) is deleted, because paging into
  # scrollback is what let a stale startup banner compete with the live
  # composer (audit fm-composer-consolidation-audit-s1, section 3.3).
  assert_not_contains "$(cat "$LOG")" $'\x1f''--cursor'$'\x1f' \
    "the composer read must never page backward into scrollback"
  pass "fm_backend_orca_send_text_submit: verifies empty composer after Enter with one bounded read"
}

test_send_text_submit_borderless_claude_confirms() {
  # The #2029 analogue this adapter never received: a borderless claude
  # composer (bare `❯` row between horizontal rules) must confirm a submit.
  # Before consolidation orca knew only the bordered shape, so every steer to
  # a borderless harness exited unconfirmed and --resolve-key never closed.
  local out
  orca_case send-submit-borderless
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/1.out"
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["────────────────","❯","────────────────"]}}}\n' > "$RESP/3.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 "hello captain" 3 0.01 0.01' "$ROOT" )
  [ "$out" = empty ] || fail "a borderless claude composer should confirm the submit, got '$out'"
  pass "fm_backend_orca_send_text_submit: a borderless claude composer confirms delivery (the missing #2029 shape)"
}

test_composer_state_stale_banner_never_wins() {
  # The audit's confidently-wrong case (section 3.3): codex's startup banner
  # (`│ permissions: YOLO mode │` inside a rounded box) classified as the
  # composer, reading `pending` for a row that is not a composer at all. With
  # the full shape catalogue the live bare row below the banner wins; with a
  # plain capture its trailing hint text is unreadable, so the verdict is
  # `unknown` (defer) - never the banner's false `pending`.
  local out
  orca_case composer-stale-banner
  printf '{"ok":true,"result":{"terminal":{"tail":["╭────────────────────────╮","│ permissions: YOLO mode │","╰────────────────────────╯","› Use /skills to list available skills"]}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_composer_state term-123' "$ROOT" )
  [ "$out" != pending ] || fail "a stale startup banner must never classify as pending composer text"
  [ "$out" = unknown ] || fail "the plain-capture codex hint should defer as unknown, got '$out'"
  pass "fm_backend_orca_composer_state: a stale startup banner cannot outrank the live composer row"
}

test_send_text_submit_retries_when_composer_stays_pending() {
  local out log_text enter_count
  orca_case send-submit-pending
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/1.out"
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["╭─────────────────╮","│ > hello captain │","╰─────────────────╯"]}}}\n' > "$RESP/3.out"
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/4.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["╭─────────────────╮","│ >               │","╰─────────────────╯"]}}}\n' > "$RESP/5.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 "hello captain" 3 0.01 0.01' "$ROOT" )
  [ "$out" = empty ] || fail "send_text_submit should retry Enter until the composer clears, got '$out'"
  log_text=$(cat "$LOG")
  enter_count=$(printf '%s\n' "$log_text" | grep -c $'orca\x1fterminal\x1fsend\x1f--terminal\x1fterm-123\x1f--text\x1f\x1f--enter\x1f--json')
  [ "$enter_count" -eq 2 ] || fail "send_text_submit should send Enter twice when the first read is pending, got $enter_count"
  pass "fm_backend_orca_send_text_submit: retries Enter while composer remains pending"
}

test_composer_state_popup_placeholder_fill_is_pending() {
  local out
  orca_case composer-popup-placeholder
  printf '{"ok":true,"result":{"terminal":{"tail":["  ╭──────────────────────────────────────╮","  │ ❯ /compact compaction instructions   │","  ╰──────────────── Composer ────────────╯","","  Enter:send"]}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_composer_state term-123' "$ROOT" )
  [ "$out" = pending ] || fail "a popup-close-with-placeholder-fill must still read as pending (not yet submitted), got '$out'"
  pass "fm_backend_orca_composer_state: a slash-command popup's argument-hint placeholder still reads pending"
}

# Dead-shell injection safety (task fm-composer-shellglyph-safety): a pane whose
# agent has exited to a bare login shell has no bordered composer row, so the
# classifier finds nothing and reports `unknown` - NOT a safe (empty) injection
# target. Covers the same guarantee herdr/cmux/tmux tests pin for their backends.
test_composer_state_bare_shell_prompt_is_unknown() {
  local out
  orca_case composer-bare-shell
  printf '{"ok":true,"result":{"terminal":{"tail":["some earlier output","kunchen@mac firstmate $ "]}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_composer_state term-123' "$ROOT" )
  [ "$out" = unknown ] || fail "a bare dead-shell prompt (no bordered composer row) must read unknown, got '$out'"
  pass "fm_backend_orca_composer_state: a bare dead-shell prompt reads unknown (unsafe-for-injection), never empty"
}

test_send_text_submit_popup_autocomplete_requires_second_enter() {
  local out log_text enter_count
  orca_case send-submit-popup-autocomplete
  # 1: literal send "/compact"
  # 2: Enter #1 closes the popup and fills the placeholder
  # 3: read - composer still holds real pending text
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/1.out"
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["  ╭──────────────────────────────────────╮","  │ ❯ /compact compaction instructions   │","  ╰──────────────── Composer ────────────╯","","  Enter:send"]}}}\n' > "$RESP/3.out"
  # 4: Enter #2 actually submits
  # 5: read - composer is empty
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}\n' > "$RESP/4.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["  ╭────────────────────────╮","  │ ❯                      │","  ╰──────── Composer ──────╯","","  Shift+Tab:mode"]}}}\n' > "$RESP/5.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 "/compact" 3 0.01 1.2' "$ROOT" )
  [ "$out" = empty ] || fail "send_text_submit should eventually report empty once the SECOND Enter actually clears the composer, got '$out'"
  log_text=$(cat "$LOG")
  enter_count=$(printf '%s\n' "$log_text" | grep -c $'orca\x1fterminal\x1fsend\x1f--terminal\x1fterm-123\x1f--text\x1f\x1f--enter\x1f--json')
  [ "$enter_count" -eq 2 ] || fail "send_text_submit must send a SECOND Enter after the popup-placeholder fill still reads pending, got $enter_count Enter(s)"
  pass "fm_backend_orca_send_text_submit: a slash-command popup's placeholder fill on Enter #1 does not short-circuit as submitted; Enter #2 is retried and lands it"
}

test_send_literal_constructs_non_enter_send() {
  orca_case send-literal
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_literal term-123 "typed only"' "$ROOT"
  expect_code 0 $? "send_literal should succeed"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--text'$'\x1f''typed only'$'\x1f''--json' \
    "send_literal did not send text without --enter"
  assert_not_contains "$(cat "$LOG")" $'\x1f''--enter' "send_literal should not submit Enter"
  pass "fm_backend_orca_send_literal: sends text without submitting"
}

test_send_text_submit_reports_send_failed() {
  local out
  orca_case send-fail
  printf '1\n' > "$RESP/1.exit"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 "hello" 1 0.01 0.01' "$ROOT" )
  [ "$out" = send-failed ] || fail "failed Orca send should report send-failed, got '$out'"
  pass "fm_backend_orca_send_text_submit: reports send-failed when Orca send fails"
}

test_send_helpers_reject_orca_error_json() {
  local out status
  orca_case send-error-json
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_line term-stale "hello"' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "send_text_line should fail on Orca ok:false JSON"
  assert_contains "$out" "terminal handle stale" "send_text_line should surface the Orca send error"
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/2.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_literal term-stale "typed"' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "send_literal should fail on Orca ok:false JSON"
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/3.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_key term-stale Enter' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "send_key should fail on Orca ok:false JSON"
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/4.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-stale "hello" 1 0.01 0.01' "$ROOT" 2>/dev/null )
  [ "$out" = send-failed ] || fail "send_text_submit should report send-failed on Orca ok:false JSON, got '$out'"
  pass "Orca send helpers: fail closed on ok:false JSON"
}

test_send_key_enter_and_interrupt() {
  orca_case send-key
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_key term-123 Enter; fm_backend_orca_send_key term-123 C-c' "$ROOT"
  expect_code 0 $? "send_key Enter and C-c should succeed"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--text'$'\x1f\x1f''--enter'$'\x1f''--json' \
    "send_key Enter did not send empty text with --enter"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--interrupt'$'\x1f''--json' \
    "send_key C-c did not send --interrupt"
  pass "fm_backend_orca_send_key: Enter maps to empty enter, C-c maps to interrupt"
}

test_send_key_refuses_unknown_key() {
  local out status
  orca_case send-key-unknown
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_key term-123 F12' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "send_key should refuse unsupported Orca keys"
  assert_contains "$out" "unsupported Orca key 'F12'" "send_key did not name the unsupported key"
  pass "fm_backend_orca_send_key: refuses unsupported keys loudly"
}

# orca_status_case <name> <appVersion-or-empty> <capabilities-csv>: a case whose
# `orca status --json` reports a ready runtime with that version and capability
# list. An empty version omits the field, as an older runtime would.
orca_status_case() {
  orca_case "$1"
  local ver=${2:-} caps=${3:-} list='' c fields
  for c in ${caps//,/ }; do list="${list:+$list,}\"$c\""; done
  fields='"reachable":true,"state":"ready"'
  [ -z "$ver" ] || fields="$fields,\"appVersion\":\"$ver\""
  [ -z "$caps" ] || fields="$fields,\"capabilities\":[$list]"
  printf '{"ok":true,"result":{"runtime":{%s}}}\n' "$fields" > "$CASE_DIR/status.json"
}

# orca_with_status <script>: run an adapter snippet against the case's status.
orca_with_status() {
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_FILE="$CASE_DIR/status.json" \
    bash -c ". \"\$0/bin/backends/orca.sh\"; $1" "$ROOT" 2>&1
}

ESC_KEY_CAP=terminal.ordered-input.v1

test_send_key_escape_sends_a_raw_escape_byte() {
  local out
  orca_status_case send-key-escape 1.4.261 "$ESC_KEY_CAP"
  out=$(orca_with_status 'fm_backend_orca_send_key term-123 Escape'); expect_code 0 $? "send_key Escape should succeed: $out"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--text'$'\x1f\x1b\x1f''--json' \
    "send_key Escape did not send the raw ESC byte as --text"
  case "$(cat "$LOG")" in
    *--enter*|*--interrupt*) fail "Escape must be sent without --enter and without --interrupt: $(cat "$LOG")" ;;
  esac
  pass "fm_backend_orca_send_key: Escape is one raw ESC byte through terminal send, with no enter and no interrupt"
}

test_send_key_ctrl_u_sends_a_raw_nak_byte() {
  local out
  orca_status_case send-key-ctrl-u 1.4.261 "$ESC_KEY_CAP"
  out=$(orca_with_status 'fm_backend_orca_send_key term-123 C-u'); expect_code 0 $? "send_key C-u should succeed: $out"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--text'$'\x1f\x15\x1f''--json' \
    "send_key C-u did not send the raw Ctrl+U byte as --text"
  case "$(cat "$LOG")" in
    *--enter*|*--interrupt*) fail "Ctrl+U must be sent without --enter and without --interrupt: $(cat "$LOG")" ;;
  esac
  pass "fm_backend_orca_send_key: C-u is one raw Ctrl+U byte through terminal send, with no enter and no interrupt"
}

test_send_key_escape_and_ctrl_u_accept_their_spellings() {
  local spelling
  for spelling in Escape escape Esc esc C-u ctrl+u Ctrl-u Ctrl-U; do
    orca_status_case "send-key-spelling-$spelling" 1.4.261 "$ESC_KEY_CAP"
    orca_with_status "fm_backend_orca_send_key term-1 '$spelling'" >/dev/null \
      || fail "send_key should accept the spelling '$spelling'"
    grep -q $'send\x1f' "$LOG" || fail "'$spelling' sent nothing"
  done
  pass "fm_backend_orca_send_key: Escape and Ctrl+U are accepted in the spellings Ctrl+C already is"
}

test_send_key_refuses_escape_and_ctrl_u_without_the_capability() {
  local out status key
  for key in Escape C-u; do
    orca_status_case "send-key-nocap-$key" 1.4.261 "terminal.prompt-delivery.v1"
    out=$(orca_with_status "fm_backend_orca_send_key term-123 $key"); status=$?
    [ "$status" -ne 0 ] || fail "send_key $key should refuse a runtime without $ESC_KEY_CAP"
    assert_contains "$out" "$ESC_KEY_CAP" "the $key refusal should name the missing capability"
    assert_contains "$out" "1.4.261" "the $key refusal should name the runtime version"
    case "$(cat "$LOG")" in
      *terminal*) fail "a refused $key must not reach orca terminal send: $(cat "$LOG")" ;;
    esac
  done
  pass "fm_backend_orca_send_key: without the capability Escape and Ctrl+U are refused before any send, naming the capability and version"
}

test_send_key_refuses_escape_when_the_status_is_unreadable() {
  local out status
  orca_status_case send-key-nostatus 1.4.261 "$ESC_KEY_CAP"
  printf 'not json\n' > "$CASE_DIR/status.json"
  out=$(orca_with_status 'fm_backend_orca_send_key term-123 Escape'); status=$?
  [ "$status" -ne 0 ] || fail "send_key Escape should refuse when the runtime status cannot be read"
  case "$(cat "$LOG")" in
    *terminal*) fail "an unreadable status must not let Escape through: $(cat "$LOG")" ;;
  esac
  pass "fm_backend_orca_send_key: an unreadable runtime status refuses Escape rather than sending it blind"
}

test_send_key_enter_and_ctrl_c_ignore_the_capability_gate() {
  orca_status_case send-key-ungated "" ""
  orca_with_status 'fm_backend_orca_send_key term-123 Enter; fm_backend_orca_send_key term-123 C-c' >/dev/null \
    || fail "Enter and C-c must keep working on a runtime that reports no capabilities"
  case "$(cat "$LOG")" in
    *status*) fail "Enter and C-c must not read the runtime status: $(cat "$LOG")" ;;
  esac
  pass "fm_backend_orca_send_key: Enter and Ctrl+C behave exactly as before and never read the runtime status"
}

test_runtime_check_records_the_version_and_capabilities() {
  local out
  orca_status_case runtime-facts 1.4.261 "$ESC_KEY_CAP,terminal.prompt-delivery.v1"
  # shellcheck disable=SC2016  # the snippet is run by the adapter's own shell
  out=$(orca_with_status 'fm_backend_orca_runtime_check && printf "%s|%s" "$FM_ORCA_APP_VERSION" "$FM_ORCA_CAPABILITIES"'); expect_code 0 $? "runtime_check should accept: $out"
  [ "$out" = "1.4.261|$ESC_KEY_CAP terminal.prompt-delivery.v1" ] \
    || fail "runtime_check should record the version and the space-separated capabilities, got '$out'"
  pass "fm_backend_orca_runtime_check: records appVersion and the capability list for later gates"
}

test_runtime_check_refuses_a_version_below_the_floor() {
  local out status ver
  for ver in 1.4.260 1.4.116 1.3.999 0.9.0 0.99999.99999; do
    orca_status_case "runtime-old-$ver" "$ver" "$ESC_KEY_CAP"
    out=$(orca_with_status 'fm_backend_orca_runtime_check'); status=$?
    [ "$status" -ne 0 ] || fail "runtime_check should refuse Orca $ver, below the tested floor"
    assert_contains "$out" "$ver" "the refusal should name the runtime version"
    assert_contains "$out" "1.4.261" "the refusal should name the floor"
  done
  pass "fm_backend_orca_runtime_check: a runtime below the tested floor is refused, naming both versions"
}

test_runtime_check_accepts_the_floor_and_anything_above_it() {
  local ver
  for ver in 1.4.261 1.4.262 1.5.0 1.10.0 2.0.0 1.4.261-rc.1 1.4.300+build.7; do
    orca_status_case "runtime-new-$ver" "$ver" ""
    orca_with_status 'fm_backend_orca_runtime_check' >/dev/null \
      || fail "runtime_check should accept Orca $ver, at or above the floor"
  done
  pass "fm_backend_orca_runtime_check: the floor and every later version compare numerically, not as text"
}

test_runtime_check_does_not_refuse_a_missing_or_unreadable_version() {
  local ver out
  for ver in "" "not-a-version" "1.4"; do
    orca_status_case "runtime-nover-$ver" "$ver" ""
    # shellcheck disable=SC2016  # the snippet is run by the adapter's own shell
    out=$(orca_with_status 'fm_backend_orca_runtime_check && printf "[%s][%s]" "$FM_ORCA_APP_VERSION" "$FM_ORCA_CAPABILITIES"') \
      || fail "runtime_check should not refuse a runtime whose version is '$ver': $out"
    [ "$out" = "[$ver][]" ] || fail "runtime_check should record version '$ver' and no capabilities, got '$out'"
  done
  pass "fm_backend_orca_runtime_check: a runtime that reports no readable version behaves exactly as before, with no gated feature enabled"
}

test_kill_is_best_effort_close() {
  orca_case kill
  printf '1\n' > "$RESP/1.exit"
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_kill term-123' "$ROOT"
  expect_code 0 $? "kill should stay best-effort when Orca close fails"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-123'$'\x1f''--json' \
    "kill did not call orca terminal close"
  pass "fm_backend_orca_kill: calls terminal close and stays best-effort"
}

# The paired direction - an `orca` stub present, a close command that exits
# nonzero, still 0 - is test_kill_is_best_effort_close above. This case is the
# distinction that arm exists to make, so the two are read together.
test_kill_refuses_when_the_orca_cli_is_absent() {
  local out status orca_free
  orca_case kill-no-cli
  orca_free=$(fm_test_base_path_sans "$PATH" orca)
  ! PATH="$orca_free" command -v orca >/dev/null 2>&1 \
    || fail "the orca-free search path still resolved orca"
  PATH="$orca_free" command -v bash >/dev/null 2>&1 \
    || fail "the orca-free search path lost bash, so this case would pass vacuously"
  # HOME and ORCA_CLI_BIN_DIR are pinned so the adapter's fallback locations
  # cannot reach the operator's real Orca CLI.
  out=$( HOME="$CASE_DIR/home" ORCA_CLI_BIN_DIR='' PATH="$orca_free" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_kill term-123' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "kill reported success for a close its missing CLI never attempted"
  assert_contains "$out" "backend=orca selected but the 'orca' CLI is not installed" \
    "kill did not name the missing CLI as the reason the close never happened"
  [ ! -s "$LOG" ] || fail "kill invoked orca despite the CLI being absent"
  pass "fm_backend_orca_kill: a close its missing CLI never attempted reports the failure instead of a success"
}

test_remove_worktree_refuses_empty_id() {
  local out status
  orca_case remove-empty
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_remove_worktree ""' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "remove_worktree should fail when the Orca worktree id is empty"
  assert_contains "$out" "missing Orca worktree id" "remove_worktree did not explain the missing id"
  [ ! -s "$LOG" ] || fail "remove_worktree should not call Orca with an empty id"
  pass "fm_backend_orca_remove_worktree: refuses empty worktree ids"
}

test_remove_worktree_asks_orca_to_delete_the_branch_safely() {
  local expect
  orca_case remove-delete-branch
  printf '{"ok":true,"result":{"removed":true}}\n' > "$RESP/1.out"
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_remove_worktree wt-branch::/orca/wt-branch' "$ROOT" \
    || fail "remove_worktree should succeed when Orca reports success"
  expect="orca"$'\x1f'"worktree"$'\x1f'"rm"$'\x1f'"--worktree"$'\x1f'"id:wt-branch::/orca/wt-branch"$'\x1f'"--force"$'\x1f'"--delete-branch"$'\x1f'"--json"
  [ "$(cat "$LOG")" = "$expect" ] \
    || fail "remove_worktree should make exactly one Orca call: worktree rm --force --delete-branch, got: $(tr '\037' ' ' < "$LOG")"
  pass "fm_backend_orca_remove_worktree: releases with --force and Orca's safe --delete-branch, nothing else"
}

test_remove_worktree_rejects_orca_error_json() {
  local out status
  orca_case remove-error-json
  printf '{"ok":false,"error":{"code":"worktree_not_found","message":"worktree not found"}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_remove_worktree wt-gone::/orca/wt-gone' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "remove_worktree should fail on Orca ok:false JSON"
  assert_contains "$out" "worktree not found" "remove_worktree should surface the Orca removal error"
  pass "fm_backend_orca_remove_worktree: fails closed on ok:false JSON"
}

test_worktree_path_resolves_id() {
  local out
  orca_case path-resolve
  printf '{"ok":true,"result":{"worktree":{"id":"wt-123::/orca/wt-123","path":"/tmp/orca-wt"}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_worktree_path wt-123::/orca/wt-123' "$ROOT" )
  [ "$out" = /tmp/orca-wt ] || fail "worktree path helper should print the resolved path, got '$out'"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''show'$'\x1f''--worktree'$'\x1f''id:wt-123::/orca/wt-123'$'\x1f''--json' \
    "worktree path helper did not call orca worktree show"
  pass "fm_backend_orca_worktree_path: resolves an Orca worktree id to its path"
}

test_json_get_ignores_undocumented_terminal_id_shapes() {
  local out status wt_id wt_path term
  orca_case parser-pruned-terminal-shapes

  set +e
  out=$( printf '{"ok":true,"result":{"id":"term-root-id"}}\n' | \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_json_get terminal-handle' "$ROOT" )
  status=$?
  set +e
  [ "$status" -ne 0 ] || fail "terminal-handle should not treat undocumented result.id as a terminal handle, got '$out'"

  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-123"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-123::/orca/wt-123","path":"/tmp/orca-wt","terminal":{"handle":"term-nested"}}}}\n' > "$RESP/3.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_worktree_create "$FM_TEST_REPO" fm-task' "$ROOT" )
  wt_id=${out%%$'\t'*}
  wt_path=${out#*$'\t'}
  term=${wt_path#*$'\t'}
  wt_path=${wt_path%%$'\t'*}
  [ "$wt_id" = wt-123::/orca/wt-123 ] || fail "worktree helper should still print worktree id, got '$wt_id'"
  [ "$wt_path" = /tmp/orca-wt ] || fail "worktree helper should still print worktree path, got '$wt_path'"
  [ "$term" = "$wt_path" ] || fail "worktree helper should ignore undocumented result.worktree.terminal and omit an implicit terminal, got '$out'"
  pass "fm_backend_orca_json_get: ignores undocumented terminal id shapes"
}

test_worktree_and_terminal_helpers_parse_json() {
  local out wt_id wt_path term
  orca_case lifecycle-helpers
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-123"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-123::/orca/wt-123","path":"/tmp/orca-wt"}}}\n' > "$RESP/3.out"
  printf '{"ok":true,"result":{"terminal":{"handle":"term-123"}}}\n' > "$RESP/4.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_worktree_create "$FM_TEST_REPO" fm-task' "$ROOT" )
  wt_id=${out%%$'\t'*}
  wt_path=${out#*$'\t'}
  [ "$wt_id" = wt-123::/orca/wt-123 ] || fail "worktree helper should print worktree id, got '$wt_id'"
  [ "$wt_path" = /tmp/orca-wt ] || fail "worktree helper should print worktree path, got '$wt_path'"
  term=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_terminal_create wt-123::/orca/wt-123 fm-task' "$ROOT" )
  [ "$term" = term-123 ] || fail "terminal helper should print terminal handle, got '$term'"
  assert_contains "$(cat "$LOG")" $'orca\x1f''repo'$'\x1f''show'$'\x1f''--repo'$'\x1f'"path:$FM_TEST_REPO"$'\x1f''--json' \
    "worktree helper should first check repo registration"
  assert_contains "$(cat "$LOG")" $'orca\x1f''repo'$'\x1f''add'$'\x1f''--path'$'\x1f'"$FM_TEST_REPO"$'\x1f''--json' \
    "worktree helper should register an absent repo"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''create'$'\x1f''--repo'$'\x1f''id:repo-123'$'\x1f''--name'$'\x1f''fm-task'$'\x1f''--no-parent'$'\x1f''--setup'$'\x1f''skip'$'\x1f''--json' \
    "worktree helper did not create an independent no-hook worktree"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''create'$'\x1f''--worktree'$'\x1f''id:wt-123::/orca/wt-123'$'\x1f''--title'$'\x1f''fm-task'$'\x1f''--json' \
    "terminal helper did not create a titled terminal for the worktree"
  pass "Orca lifecycle helpers: register repo, create worktree, create terminal, parse stable ids"
}

test_worktree_create_removes_worktree_when_path_missing() {
  local out status
  orca_case lifecycle-missing-path
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-no-path"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-no-path::/orca/wt-no-path"},"terminal":{"handle":"term-no-path"}}}\n' > "$RESP/3.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_worktree_create "$FM_TEST_REPO" fm-task' "$ROOT" 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "worktree helper should fail when Orca omits the worktree path"
  assert_contains "$out" "orca worktree create did not return a path for fm-task" \
    "worktree helper did not explain the missing path"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-no-path'$'\x1f''--json' \
    "worktree helper did not close the implicit terminal when path parsing failed"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-no-path::/orca/wt-no-path'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "worktree helper did not remove the pathless Orca worktree"
  pass "fm_backend_orca_worktree_create: removes created worktree when path is missing"
}

test_spawn_preserves_orca_metadata_when_pathless_worktree_cleanup_fails() {
  local proj data state config id out status
  id="orcapathlessz6"
  proj="$TMP_ROOT/pathless-cleanup-project"
  data="$TMP_ROOT/pathless-cleanup-data"
  state="$TMP_ROOT/pathless-cleanup-state"
  config="$TMP_ROOT/pathless-cleanup-config"
  fm_git_init_commit "$proj"
  mkdir -p "$data/$id" "$state" "$config"
  write_spawn_brief "$data" "$id"
  touch "$state/.last-watcher-beat"
  orca_case pathless-cleanup-fail
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-pathless-cleanup"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-pathless-cleanup::/orca/wt-pathless-cleanup"}}}\n' > "$RESP/3.out"
  printf '{"ok":false,"error":{"code":"worktree_not_removed","message":"worktree not removed"}}\n' > "$RESP/4.out"
  printf '{"ok":false,"error":{"code":"worktree_not_removed","message":"worktree not removed"}}\n' > "$RESP/5.out"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "Orca spawn should fail when path parsing and cleanup fail"
  assert_contains "$out" "orca worktree create did not return a path" \
    "pathless worktree failure should explain the missing path"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-pathless-cleanup::/orca/wt-pathless-cleanup'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "pathless cleanup should attempt helper-backed worktree removal"
  assert_present "$state/$id.meta" "failed pathless cleanup should preserve metadata"
  assert_grep "window=fm-$id" "$state/$id.meta" "preserved pathless metadata missing stable window alias"
  assert_grep "backend=orca" "$state/$id.meta" "preserved pathless metadata missing backend=orca"
  assert_grep "orca_worktree_id=wt-pathless-cleanup::/orca/wt-pathless-cleanup" "$state/$id.meta" "preserved pathless metadata missing Orca worktree id"
  assert_no_grep "terminal=" "$state/$id.meta" "preserved pathless metadata should not invent a terminal handle"
  pass "fm-spawn.sh --backend orca: preserves metadata when pathless cleanup fails"
}

test_spawn_writes_orca_metadata_and_launches_harness() {
  local proj wt data state config id out log staged launch
  id="orcaspawnz1"
  proj="$TMP_ROOT/spawn-project"
  wt="$TMP_ROOT/spawn-wt"
  data="$TMP_ROOT/spawn-data"
  state="$TMP_ROOT/spawn-state"
  config="$TMP_ROOT/spawn-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  write_spawn_brief "$data" "$id"
  touch "$state/.last-watcher-beat"
  orca_case spawn
  log="$LOG"
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-spawn"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-spawn::/orca/wt-spawn","path":"%s"},"terminal":{"handle":"term-spawn"}}}\n' "$wt" > "$RESP/3.out"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  expect_code 0 $? "fm-spawn.sh --backend orca should succeed with fake Orca"$'\n'"$out"
  assert_contains "$out" "spawned $id harness=claude kind=ship mode=no-mistakes yolo=off window=fm-$id worktree=$wt" \
    "spawn output missing Orca window/worktree summary"
  assert_grep "backend=orca" "$state/$id.meta" "meta missing backend=orca"
  assert_grep "window=fm-$id" "$state/$id.meta" "meta missing stable Orca window alias"
  assert_grep "terminal=term-spawn" "$state/$id.meta" "meta missing terminal handle"
  assert_grep "orca_worktree_id=wt-spawn::/orca/wt-spawn" "$state/$id.meta" "meta missing Orca worktree id"
  assert_grep "worktree=$wt" "$state/$id.meta" "meta missing Orca worktree path"
  assert_not_contains "$(cat "$log")" $'orca\x1f''terminal'$'\x1f''create' \
    "spawn should reuse the implicit terminal returned by Orca worktree creation"
  assert_contains "$(cat "$log")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-spawn'$'\x1f''--text'$'\x1f''export GOTMPDIR=/tmp/fm-orcaspawnz1/gotmp'$'\x1f''--enter'$'\x1f''--json' \
    "spawn did not export GOTMPDIR through the Orca terminal"
  staged=$(tr '\037' '\n' < "$log" | sed -n "s/^\. '\([^']*\)'$/\1/p" | tail -1)
  [ -n "$staged" ] && [ -f "$staged" ] \
    || fail "spawn did not send Orca a readable staged launch command"
  launch=$(cat "$staged")
  add_dirs="--add-dir '$(cd "$state" && pwd -P)/operational-inbox' --add-dir '$(cd "$state" && pwd -P)/$id.inbox' --add-dir '$(cd "$data" && pwd -P)/$id' --add-dir '$(cd "$ROOT" && pwd -P)/.agents/skills'"
  assert_contains "$launch" "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false CLAUDE_CODE_SEND_FEEDBACK=0 claude --dangerously-skip-permissions $add_dirs --settings '{\"feedbackDrafts\":\"off\",\"attribution\":{\"commit\":\"\",\"pr\":\"\",\"sessionUrl\":false}}'" \
    "the staged launch sent through Orca did not select the Claude harness"
  rm -rf "/tmp/fm-$id" "$(dirname "$staged")"
  pass "fm-spawn.sh --backend orca: reuses implicit terminal, records metadata, launches harness"
}

test_spawn_refuses_orca_secondmate_before_home_mutation() {
  local home subhome data state config id out status
  id="orcasmz1"
  home="$TMP_ROOT/secondmate-refusal-home"
  subhome="$TMP_ROOT/secondmate-refusal-subhome"
  data="$home/data"
  state="$home/state"
  config="$home/config"
  mkdir -p "$data" "$state" "$config" "$subhome/bin" "$subhome/data" "$subhome/state" "$subhome/projects"
  printf '%s\n' "$id" > "$subhome/.fm-secondmate-home"
  printf 'firstmate\n' > "$subhome/AGENTS.md"
  printf 'claude\n' > "$config/crew-harness"
  touch "$state/.last-watcher-beat"
  set +e
  out=$( FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$subhome" claude --backend orca --secondmate 2>&1 )
  status=$?
  set +e
  [ "$status" -ne 0 ] || fail "backend=orca --secondmate should be refused"
  assert_contains "$out" "backend=orca does not support --secondmate spawns yet" \
    "orca secondmate refusal should happen at backend selection"
  assert_absent "$subhome/config/crew-harness" \
    "orca secondmate refusal should not propagate inherited local material into the secondmate home"
  pass "fm-spawn.sh --backend orca --secondmate: refuses before secondmate-home mutation"
}

test_spawn_refuses_orca_when_runtime_not_ready() {
  local proj data state config id out status
  id="orcaruntimez6"
  proj="$TMP_ROOT/runtime-down-project"
  data="$TMP_ROOT/runtime-down-data"
  state="$TMP_ROOT/runtime-down-state"
  config="$TMP_ROOT/runtime-down-config"
  fm_git_init_commit "$proj"
  mkdir -p "$data/$id" "$state" "$config"
  write_spawn_brief "$data" "$id"
  touch "$state/.last-watcher-beat"
  orca_case runtime-down-spawn
  printf '{"ok":true,"result":{"runtime":{"reachable":false,"state":"starting"}}}\n' > "$RESP/1.out"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_RESPONSE=sequence \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "fm-spawn.sh --backend orca should refuse when Orca runtime is not ready"
  assert_contains "$out" "requires a ready Orca runtime" \
    "runtime readiness refusal should explain the Orca requirement"
  assert_absent "$state/$id.meta" "runtime refusal must not record metadata"
  assert_contains "$(cat "$LOG")" $'orca\x1f''status'$'\x1f''--json' \
    "spawn did not probe Orca runtime readiness"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''repo' \
    "spawn should fail before repo/worktree creation when runtime is not ready"
  pass "fm-spawn.sh --backend orca: refuses before mutation when Orca runtime is not ready"
}

test_spawn_refuses_orca_nonisolated_worktree() {
  local proj data state config id out status
  id="orcabadwtz4"
  proj="$TMP_ROOT/bad-spawn-project"
  data="$TMP_ROOT/bad-spawn-data"
  state="$TMP_ROOT/bad-spawn-state"
  config="$TMP_ROOT/bad-spawn-config"
  fm_git_init_commit "$proj"
  mkdir -p "$data/$id" "$state" "$config"
  write_spawn_brief "$data" "$id"
  touch "$state/.last-watcher-beat"
  orca_case bad-spawn
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-bad"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-bad::/orca/wt-bad","path":"%s"},"terminal":{"handle":"term-bad"}}}\n' "$proj" > "$RESP/3.out"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  status=$?
  expect_code 1 "$status" "fm-spawn.sh --backend orca should refuse a primary checkout worktree"
  assert_contains "$out" "orca worktree create did not yield an isolated worktree" \
    "Orca spawn should reuse the isolated-worktree guard"
  assert_absent "$state/$id.meta" "aborted Orca spawn must not record meta"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''create' \
    "Orca spawn should validate the worktree before creating a terminal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-bad'$'\x1f''--json' \
    "Orca spawn should close the implicit terminal after validation aborts"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-bad::/orca/wt-bad'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "Orca spawn should remove the worktree after validation aborts"
  pass "fm-spawn.sh --backend orca: refuses non-isolated worktrees and closes implicit terminals"
}

test_spawn_removes_orca_worktree_when_terminal_create_fails() {
  local proj wt data state config id out status
  id="orcatermfailz8"
  proj="$TMP_ROOT/terminal-fail-project"
  wt="$TMP_ROOT/terminal-fail-wt"
  data="$TMP_ROOT/terminal-fail-data"
  state="$TMP_ROOT/terminal-fail-state"
  config="$TMP_ROOT/terminal-fail-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  write_spawn_brief "$data" "$id"
  touch "$state/.last-watcher-beat"
  orca_case terminal-fail
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-terminal-fail"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-terminal-fail::/orca/wt-terminal-fail","path":"%s"}}}\n' "$wt" > "$RESP/3.out"
  printf '1\n' > "$RESP/4.exit"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "Orca spawn should fail when terminal creation fails"
  assert_absent "$state/$id.meta" "terminal-create abort should not record metadata after successful cleanup"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''create'$'\x1f''--worktree'$'\x1f''id:wt-terminal-fail::/orca/wt-terminal-fail'$'\x1f''--title'$'\x1f'"fm-$id"$'\x1f''--json' \
    "Orca spawn should attempt terminal creation before abort cleanup"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-terminal-fail::/orca/wt-terminal-fail'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "Orca spawn should remove the worktree when terminal creation fails"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close' \
    "Orca spawn should not close a terminal when no handle was recorded"
  pass "fm-spawn.sh --backend orca: removes worktree when terminal creation fails"
}

test_spawn_preserves_orca_metadata_when_abort_cleanup_fails() {
  local proj wt data state config id out status
  id="orcacleanupleakz0"
  proj="$TMP_ROOT/cleanup-fail-project"
  wt="$TMP_ROOT/cleanup-fail-wt"
  data="$TMP_ROOT/cleanup-fail-data"
  state="$TMP_ROOT/cleanup-fail-state"
  config="$TMP_ROOT/cleanup-fail-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  write_spawn_brief "$data" "$id"
  touch "$state/.last-watcher-beat"
  orca_case cleanup-fail
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-cleanup-fail"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-cleanup-fail::/orca/wt-cleanup-fail","path":"%s"}}}\n' "$wt" > "$RESP/3.out"
  printf '1\n' > "$RESP/4.exit"
  printf '1\n' > "$RESP/5.exit"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "Orca spawn should fail when terminal creation and abort cleanup fail"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-cleanup-fail::/orca/wt-cleanup-fail'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "Orca spawn should attempt helper cleanup before preserving metadata"
  assert_present "$state/$id.meta" "failed Orca abort cleanup should preserve metadata"
  assert_grep "window=fm-$id" "$state/$id.meta" "preserved metadata missing stable window alias"
  assert_grep "backend=orca" "$state/$id.meta" "preserved metadata missing backend=orca"
  assert_grep "orca_worktree_id=wt-cleanup-fail::/orca/wt-cleanup-fail" "$state/$id.meta" "preserved metadata missing Orca worktree id"
  assert_no_grep "terminal=" "$state/$id.meta" "preserved metadata should not invent a terminal handle"
  pass "fm-spawn.sh --backend orca: preserves metadata when abort cleanup fails"
}

test_spawn_releases_orca_resources_when_metadata_write_fails() {
  local proj wt data state config id out status
  id="orcametafailz9"
  proj="$TMP_ROOT/meta-fail-project"
  wt="$TMP_ROOT/meta-fail-wt"
  data="$TMP_ROOT/meta-fail-data"
  state="$TMP_ROOT/meta-fail-state"
  config="$TMP_ROOT/meta-fail-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state/$id.meta" "$config"
  write_spawn_brief "$data" "$id"
  orca_case meta-fail
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-meta-fail"}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-meta-fail::/orca/wt-meta-fail","path":"%s"}}}\n' "$wt" > "$RESP/3.out"
  printf '{"ok":true,"result":{"terminal":{"handle":"term-meta-fail"}}}\n' > "$RESP/4.out"
  out=$( HOME="$SPAWN_HOME" CLAUDE_CONFIG_DIR='' PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/unused-projects" FM_SPAWN_NO_GUARD=1 \
    "$ROOT/bin/fm-spawn.sh" "$id" "$proj" claude --mode no-mistakes --yolo off --backend orca 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "Orca spawn should fail when metadata cannot be written"
  assert_contains "$out" "task record for $id could not be published" \
    "spawn should report metadata publication failure without relying on platform-specific mv output"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-meta-fail'$'\x1f''--json' \
    "Orca spawn should close the recorded terminal when a later abort occurs"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-meta-fail::/orca/wt-meta-fail'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "Orca spawn should remove the recorded worktree when a later abort occurs"
  [ ! -f "$state/$id.meta" ] || fail "metadata-write abort should not publish a regular metadata file"
  pass "fm-spawn.sh --backend orca: releases terminal and worktree on later aborts"
}

test_peek_send_and_crew_state_route_through_orca_meta() {
  local wt state id out neutral record body
  id="orcaiopathz2"
  wt="$TMP_ROOT/io-wt"
  fm_git_init_commit "$wt"
  state="$TMP_ROOT/io-state"; mkdir -p "$state"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-io" "worktree=$wt" "project=$wt" "harness=claude" "kind=scout" "backend=orca"
  touch "$state/.last-watcher-beat"
  orca_case io-path
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  printf '{"ok":true,"result":{"terminal":{"tail":["ready"]}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_SEND_SETTLE=0 \
    "$ROOT/bin/fm-peek.sh" "fm-$id" 10 )
  [ "$out" = ready ] || fail "fm-peek should read through Orca metadata, got '$out'"
  printf '{"ok":true,"result":{"send":{"handle":"term-io","accepted":true}}}\n' > "$RESP/2.out"
  printf '{"ok":true,"result":{"send":{"handle":"term-io","accepted":true}}}\n' > "$RESP/3.out"
  printf '{"ok":true,"result":{"terminal":{"tail":["│ > │"]}}}\n' > "$RESP/4.out"
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_HOME="$neutral" FM_STATE_OVERRIDE="$state" FM_SEND_SETTLE=0 \
    "$ROOT/bin/fm-send.sh" "fm-$id" "hello orca"
  printf '{"ok":true,"result":{"terminal":{"tail":["idle prompt"]}}}\n' > "$RESP/5.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" "$ROOT/bin/fm-crew-state.sh" "$id" )
  assert_contains "$out" "state: unknown" "crew-state should fall back cleanly for an idle Orca scout"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''read'$'\x1f''--terminal'$'\x1f''term-io' \
    "peek/crew-state did not read the recorded Orca terminal"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''read'$'\x1f''--terminal'$'\x1f'"fm-$id" \
    "crew-state should not read the stable Orca alias as a terminal handle"
  record="$state/$id.inbox/001.msg"
  [ -f "$record" ] || fail "send did not enqueue through the task inbox"
  body=$(bash -c '. "$1"; fm_task_inbox_body "$2"' _ "$ROOT/bin/fm-task-inbox-lib.sh" "$record")
  [ "$body" = "hello orca" ] || fail "Orca task inbox did not preserve the send body, got '$body'"
  assert_not_contains "$(cat "$LOG")" $'--text\x1fhello orca\x1f' \
    "send typed the payload instead of recording it"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-io'$'\x1f''--text'$'\x1f'': Firstmate instruction waiting:' \
    "send did not ring the inbox doorbell through the recorded Orca terminal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-io'$'\x1f''--text'$'\x1f\x1f''--enter'$'\x1f''--json' \
    "send did not submit the doorbell through the recorded Orca terminal"
  pass "fm-peek/fm-send/fm-crew-state route through backend=orca metadata and its durable inbox"
}

test_peek_and_crew_state_fail_closed_on_orca_error_json() {
  local wt state id out status neutral
  id="orcareaderrz7"
  wt="$TMP_ROOT/read-error-wt"
  fm_git_init_commit "$wt"
  state="$TMP_ROOT/read-error-state"; mkdir -p "$state"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-stale" "worktree=$wt" "project=$wt" "harness=claude" "kind=scout" "backend=orca"
  touch "$state/.last-watcher-beat"
  orca_case read-error-json
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" "$ROOT/bin/fm-peek.sh" "fm-$id" 10 2>&1 )
  status=$?
  [ "$status" -ne 0 ] || fail "fm-peek should fail when Orca reports a stale terminal"
  assert_contains "$out" "terminal handle stale" "fm-peek should surface the Orca read error message"
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/2.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" "$ROOT/bin/fm-crew-state.sh" "$id" )
  assert_contains "$out" "state: unknown" "crew-state should not treat an Orca read error as a live endpoint"
  assert_contains "$out" "backend target gone: term-stale" "crew-state should report the stale Orca terminal as gone"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''read'$'\x1f''--terminal'$'\x1f''term-stale' \
    "fm-peek did not read the recorded Orca terminal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''show'$'\x1f''--terminal'$'\x1f''term-stale' \
    "fm-crew-state did not read the recorded Orca terminal's endpoint record"
  [ "$(grep -a -c -F $'orca\x1fterminal\x1fshow' "$LOG")" -eq 1 ] \
    || fail "fm-crew-state should read the Orca endpoint record once, log: $(cat "$LOG")"
  pass "fm-peek/fm-crew-state: Orca read error JSON fails closed"
}

test_target_exists_rejects_orca_error_json() {
  local status
  orca_case target-exists-error-json
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal handle stale"}}\n' > "$RESP/1.out"
  set +e
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/fm-backend.sh"; fm_backend_target_exists orca term-stale fm-task' "$ROOT"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "fm_backend_target_exists should reject Orca ok:false read JSON"
  pass "fm_backend_target_exists: Orca ok:false read JSON is not live"
}

test_scout_teardown_removes_orca_worktree_via_helper() {
  local proj wt data state config id out rc neutral
  id="orcateardownz3"
  proj="$TMP_ROOT/teardown-project"
  wt="$TMP_ROOT/teardown-wt"
  data="$TMP_ROOT/teardown-data"
  state="$TMP_ROOT/teardown-state"
  config="$TMP_ROOT/teardown-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  printf 'report\n' > "$data/$id/report.md"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-teardown" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-teardown::/orca/wt-teardown" \
    "decisions_reviewed=1" "decision_keys="
  orca_case teardown
  printf '{"ok":true,"result":{"worktree":{"id":"wt-teardown::/orca/wt-teardown","path":"%s"}}}\n' "$wt" > "$RESP/1.out"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  expect_code 0 "$rc" "Orca scout teardown should succeed once report exists"$'\n'"$out"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-teardown'$'\x1f''--json' \
    "teardown did not close the recorded Orca terminal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-teardown::/orca/wt-teardown'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "teardown did not remove the Orca worktree through orca worktree rm"
  assert_absent "$state/$id.meta" "teardown should remove task metadata"
  pass "fm-teardown.sh backend=orca: scout report gate then helper-backed worktree removal"
}

test_scout_teardown_refuses_orca_id_path_mismatch() {
  local proj wt other_wt data state config id out rc neutral
  id="orcascoutmismatchz5"
  proj="$TMP_ROOT/scout-mismatch-project"
  wt="$TMP_ROOT/scout-mismatch-wt"
  other_wt="$TMP_ROOT/scout-mismatch-other-wt"
  data="$TMP_ROOT/scout-mismatch-data"
  state="$TMP_ROOT/scout-mismatch-state"
  config="$TMP_ROOT/scout-mismatch-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  git -C "$proj" worktree add --quiet -b "fm/$id-other" "$other_wt"
  mkdir -p "$data/$id" "$state" "$config"
  printf 'report\n' > "$data/$id/report.md"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-scout-mismatch" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-scout-mismatch::/orca/wt-scout-mismatch" \
    "decisions_reviewed=1" "decision_keys="
  orca_case scout-mismatch
  printf '{"ok":true,"result":{"worktree":{"id":"wt-scout-mismatch::/orca/wt-scout-mismatch","path":"%s"}}}\n' "$other_wt" > "$RESP/1.out"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca scout teardown should refuse when id path differs from worktree="
  assert_contains "$out" "not inspected worktree" \
    "mismatched Orca scout worktree path refusal should name the mismatch"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close' \
    "refused mismatched Orca scout teardown should not close terminals"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm' \
    "refused mismatched Orca scout teardown should not remove worktrees"
  assert_present "$state/$id.meta" "refused mismatched scout teardown should preserve metadata"
  pass "fm-teardown.sh backend=orca: scout teardown refuses id/path mismatches"
}

test_teardown_removes_orca_worktree_when_path_missing() {
  local proj wt data state config id out rc neutral
  id="orcamissingpathz7"
  proj="$TMP_ROOT/missing-path-project"
  wt="$TMP_ROOT/missing-path-wt"
  data="$TMP_ROOT/missing-path-data"
  state="$TMP_ROOT/missing-path-state"
  config="$TMP_ROOT/missing-path-config"
  mkdir -p "$data/$id" "$state" "$config"
  printf 'report\n' > "$data/$id/report.md"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-missing-path" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-missing-path::/orca/wt-missing-path" \
    "decisions_reviewed=1" "decision_keys="
  orca_case missing-path
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  expect_code 0 "$rc" "Orca teardown should release helpers even when the path is absent"$'\n'"$out"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-missing-path'$'\x1f''--json' \
    "teardown did not close the recorded Orca terminal when the path was absent"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-missing-path::/orca/wt-missing-path'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "teardown did not remove the recorded Orca worktree when the path was absent"
  assert_absent "$state/$id.meta" "successful helper cleanup should remove task metadata"
  pass "fm-teardown.sh backend=orca: releases terminal/worktree when path is absent"
}

test_teardown_preserves_metadata_when_orca_remove_error_json() {
  local proj wt data state config id out rc neutral
  id="orcaremoveerrz2"
  proj="$TMP_ROOT/remove-error-project"
  wt="$TMP_ROOT/remove-error-wt"
  data="$TMP_ROOT/remove-error-data"
  state="$TMP_ROOT/remove-error-state"
  config="$TMP_ROOT/remove-error-config"
  mkdir -p "$data/$id" "$state" "$config"
  printf 'report\n' > "$data/$id/report.md"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-remove-error" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-remove-error::/orca/wt-remove-error" \
    "decisions_reviewed=1" "decision_keys="
  orca_case remove-error-teardown
  printf '{"ok":true,"result":{}}\n' > "$RESP/1.out"
  printf '{"ok":false,"error":{"code":"worktree_not_removed","message":"worktree not removed"}}\n' > "$RESP/2.out"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca teardown should fail when worktree removal returns ok:false JSON"
  assert_contains "$out" "worktree not removed" "teardown should surface the Orca removal error"
  assert_present "$state/$id.meta" "failed Orca removal should preserve task metadata"
  pass "fm-teardown.sh backend=orca: preserves metadata on remove ok:false JSON"
}

test_scout_teardown_refuses_orca_missing_report_when_path_missing() {
  local proj wt data state config id out rc neutral
  id="orcanoreportz4"
  proj="$TMP_ROOT/missing-report-project"
  wt="$TMP_ROOT/missing-report-wt"
  data="$TMP_ROOT/missing-report-data"
  state="$TMP_ROOT/missing-report-state"
  config="$TMP_ROOT/missing-report-config"
  mkdir -p "$data/$id" "$state" "$config"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-missing-report" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-missing-report::/orca/wt-missing-report"
  orca_case missing-report
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca scout teardown should refuse without a report even when the path is absent"
  assert_contains "$out" "has no report" "Orca scout teardown should explain the missing report"
  [ ! -s "$LOG" ] || fail "refused Orca scout teardown should not close terminals or remove worktrees"
  assert_present "$state/$id.meta" "refused Orca scout teardown should preserve metadata"
  pass "fm-teardown.sh backend=orca: scout report gate precedes pathless helper cleanup"
}

test_ship_teardown_refuses_orca_missing_worktree_path() {
  local proj wt data state config id out rc neutral
  id="orcashipmissingz8"
  proj="$TMP_ROOT/missing-ship-project"
  wt="$TMP_ROOT/missing-ship-wt"
  data="$TMP_ROOT/missing-ship-data"
  state="$TMP_ROOT/missing-ship-state"
  config="$TMP_ROOT/missing-ship-config"
  fm_git_init_commit "$proj"
  mkdir -p "$data/$id" "$state" "$config"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-missing-ship" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=ship" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-missing-ship::/orca/wt-missing-ship"
  orca_case missing-ship-path
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca ship teardown should refuse a missing worktree path"
  assert_contains "$out" "no inspectable git worktree" \
    "Orca ship teardown should explain the fail-closed worktree requirement"
  [ ! -s "$LOG" ] || fail "refused Orca ship teardown should not close terminals or remove worktrees"
  assert_present "$state/$id.meta" "refused Orca ship teardown should preserve metadata"
  pass "fm-teardown.sh backend=orca: ship teardown fails closed when worktree path is missing"
}

test_ship_teardown_removes_orca_worktree_when_id_path_matches() {
  local proj wt data state config id out rc neutral
  id="orcashipmatchz2"
  proj="$TMP_ROOT/ship-match-project"
  wt="$TMP_ROOT/ship-match-wt"
  data="$TMP_ROOT/ship-match-data"
  state="$TMP_ROOT/ship-match-state"
  config="$TMP_ROOT/ship-match-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-ship-match" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=ship" "mode=local-only" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-ship-match::/orca/wt-ship-match"
  orca_case ship-match
  printf '{"ok":true,"result":{"worktree":{"id":"wt-ship-match::/orca/wt-ship-match","path":"%s"}}}\n' "$wt" > "$RESP/1.out"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  expect_code 0 "$rc" "Orca ship teardown should succeed when the id path matches the inspected worktree"$'\n'"$out"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''show'$'\x1f''--worktree'$'\x1f''id:wt-ship-match::/orca/wt-ship-match'$'\x1f''--json' \
    "teardown did not resolve the Orca worktree id before removal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-ship-match'$'\x1f''--json' \
    "teardown did not close the matched Orca terminal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-ship-match::/orca/wt-ship-match'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "teardown did not remove the matched Orca worktree"
  assert_absent "$state/$id.meta" "successful matched teardown should remove task metadata"
  pass "fm-teardown.sh backend=orca: ship teardown requires a matching Orca id path"
}

test_ship_teardown_completes_when_orca_keeps_the_branch() {
  local proj wt data state config id out rc neutral n
  id="orcakeepbranchz1"
  proj="$TMP_ROOT/keep-branch-project"
  wt="$TMP_ROOT/keep-branch-wt"
  data="$TMP_ROOT/keep-branch-data"
  state="$TMP_ROOT/keep-branch-state"
  config="$TMP_ROOT/keep-branch-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-keep-branch" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=ship" "mode=local-only" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-keep-branch::/orca/wt-keep-branch"
  orca_case keep-branch
  printf '{"ok":true,"result":{"worktree":{"id":"wt-keep-branch::/orca/wt-keep-branch","path":"%s"}}}\n' "$wt" > "$RESP/1.out"
  # Orca keeps a branch it cannot prove merged and then reports a removal with
  # no branch-deletion evidence; that must not fail the release.
  for n in 2 3 4 5 6; do
    printf '{"ok":true,"result":{"removed":true}}\n' > "$RESP/$n.out"
  done
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  expect_code 0 "$rc" "teardown should complete when Orca reports a removal without branch evidence"$'\n'"$out"$'\n'"$(tr '\037' ' ' < "$LOG")"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-keep-branch::/orca/wt-keep-branch'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "teardown should ask Orca to delete the branch safely"
  assert_absent "$state/$id.meta" "teardown should remove task metadata once Orca released the worktree"
  pass "fm-teardown.sh backend=orca: a release that reports no branch deletion still completes"
}

test_ship_teardown_refuses_orca_unresolvable_worktree_id() {
  local proj wt data state config id out rc neutral
  id="orcashipunresolvedz1"
  proj="$TMP_ROOT/ship-unresolved-project"
  wt="$TMP_ROOT/ship-unresolved-wt"
  data="$TMP_ROOT/ship-unresolved-data"
  state="$TMP_ROOT/ship-unresolved-state"
  config="$TMP_ROOT/ship-unresolved-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-ship-unresolved" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=ship" "mode=local-only" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-ship-unresolved::/orca/wt-ship-unresolved"
  orca_case ship-unresolved
  printf '1\n' > "$RESP/1.exit"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca ship teardown should refuse when the worktree id cannot be resolved"
  assert_contains "$out" "cannot resolve Orca worktree id wt-ship-unresolved::/orca/wt-ship-unresolved" \
    "unresolvable Orca worktree id refusal should explain the fail-closed check"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''show'$'\x1f''--worktree'$'\x1f''id:wt-ship-unresolved::/orca/wt-ship-unresolved'$'\x1f''--json' \
    "teardown did not attempt to resolve the Orca worktree id"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close' \
    "refused unresolved Orca ship teardown should not close terminals"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm' \
    "refused unresolved Orca ship teardown should not remove worktrees"
  assert_present "$state/$id.meta" "refused unresolved Orca ship teardown should preserve metadata"
  pass "fm-teardown.sh backend=orca: ship teardown fails closed when id resolution fails"
}

test_ship_teardown_refuses_orca_id_path_mismatch() {
  local proj wt other_wt data state config id out rc neutral
  id="orcashipmismatchz9"
  proj="$TMP_ROOT/ship-mismatch-project"
  wt="$TMP_ROOT/ship-mismatch-wt"
  other_wt="$TMP_ROOT/ship-mismatch-other-wt"
  data="$TMP_ROOT/ship-mismatch-data"
  state="$TMP_ROOT/ship-mismatch-state"
  config="$TMP_ROOT/ship-mismatch-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  git -C "$proj" worktree add --quiet -b "fm/$id-other" "$other_wt"
  mkdir -p "$data/$id" "$state" "$config"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-ship-mismatch" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=ship" "mode=local-only" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-ship-mismatch::/orca/wt-ship-mismatch"
  orca_case ship-mismatch
  printf '{"ok":true,"result":{"worktree":{"id":"wt-ship-mismatch::/orca/wt-ship-mismatch","path":"%s"}}}\n' "$other_wt" > "$RESP/1.out"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca ship teardown should refuse when the id path differs from worktree="
  assert_contains "$out" "not inspected worktree" \
    "mismatched Orca worktree path refusal should name the mismatch"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''show'$'\x1f''--worktree'$'\x1f''id:wt-ship-mismatch::/orca/wt-ship-mismatch'$'\x1f''--json' \
    "teardown did not resolve the mismatched Orca worktree id"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close' \
    "refused mismatched Orca ship teardown should not close terminals"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm' \
    "refused mismatched Orca ship teardown should not remove worktrees"
  assert_present "$state/$id.meta" "refused mismatched Orca ship teardown should preserve metadata"
  pass "fm-teardown.sh backend=orca: ship teardown refuses id/path mismatches"
}

test_teardown_refuses_orca_missing_worktree_id() {
  local proj wt data state config id out rc neutral
  id="orcamissingidz5"
  proj="$TMP_ROOT/missing-id-project"
  wt="$TMP_ROOT/missing-id-wt"
  data="$TMP_ROOT/missing-id-data"
  state="$TMP_ROOT/missing-id-state"
  config="$TMP_ROOT/missing-id-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  printf 'report\n' > "$data/$id/report.md"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-missing-id" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" "backend=orca" \
    "decisions_reviewed=1" "decision_keys="
  orca_case missing-id
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca teardown should refuse missing orca_worktree_id"
  assert_contains "$out" "missing orca_worktree_id" "teardown did not explain the missing Orca worktree id"
  assert_present "$state/$id.meta" "failed teardown must preserve task metadata"
  [ ! -s "$LOG" ] || fail "teardown should fail before closing terminals or removing worktrees without an Orca worktree id"
  pass "fm-teardown.sh backend=orca: refuses missing worktree ids before cleanup"
}

test_teardown_refuses_orca_worktree_without_terminal_handle() {
  local proj wt data state config id out rc neutral
  id="orcanotermz0"
  proj="$TMP_ROOT/no-terminal-project"
  wt="$TMP_ROOT/no-terminal-wt"
  data="$TMP_ROOT/no-terminal-data"
  state="$TMP_ROOT/no-terminal-state"
  config="$TMP_ROOT/no-terminal-config"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  mkdir -p "$data/$id" "$state" "$config"
  printf 'report\n' > "$data/$id/report.md"
  touch "$state/.last-watcher-beat"
  fm_write_meta "$state/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "worktree=$wt" "project=$proj" \
    "harness=claude" "kind=scout" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-no-terminal::/orca/wt-no-terminal" \
    "decisions_reviewed=1" "decision_keys="
  orca_case no-terminal
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$state" FM_DATA_OVERRIDE="$data" FM_CONFIG_OVERRIDE="$config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "Orca teardown accepted metadata without a terminal handle"
  assert_contains "$out" "missing terminal" "teardown did not explain the incomplete Orca endpoint"
  [ ! -s "$LOG" ] || fail "teardown dispatched to Orca before rejecting the incomplete endpoint"
  assert_present "$state/$id.meta" "missing-terminal refusal removed task metadata"
  pass "fm-teardown.sh backend=orca: refuses incomplete worktree-only endpoint metadata before runtime dispatch"
}

test_secondmate_force_teardown_removes_orca_child_via_orca() {
  local home subhome childproj childwt child_id neutral out rc
  home="$TMP_ROOT/orca-child-parent"
  subhome="$TMP_ROOT/orca-child-secondmate"
  childproj="$subhome/projects/alpha"
  childwt="$TMP_ROOT/orca-child-worktree"
  child_id="orcachildz6"
  mkdir -p "$home/state" "$home/data" "$subhome/state" "$subhome/projects"
  printf 'domain\n' > "$subhome/.fm-secondmate-home"
  fm_git_worktree "$childproj" "$childwt" "fm/$child_id"
  fm_write_meta "$home/state/domain.meta" \
    "window=firstmate:fm-domain" "worktree=$subhome" "project=$subhome" \
    "harness=echo" "kind=secondmate" "mode=secondmate" "yolo=off" \
    "home=$subhome" "projects=alpha"
  printf '%s\n' "- domain - Orca child cleanup (home: $subhome; scope: orca cleanup; projects: alpha; added 2026-07-03)" \
    > "$home/data/secondmates.md"
  fm_write_meta "$subhome/state/$child_id.meta" \
    "window=fm-$child_id" "endpoint_task_id=$child_id" \
    "terminal=term-child-cleanup" "worktree=$childwt" "project=$childproj" \
    "harness=claude" "kind=ship" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-child-cleanup::/orca/wt-child-cleanup"
  orca_case secondmate-child-cleanup
  printf '{"ok":true,"result":{"worktree":{"id":"wt-child-cleanup::/orca/wt-child-cleanup","path":"%s"}}}\n' "$childwt" > "$RESP/1.out"
  printf '{"ok":true,"result":{"worktree":{"id":"wt-child-cleanup::/orca/wt-child-cleanup","path":"%s"}}}\n' "$childwt" > "$RESP/2.out"
  printf '{"ok":true,"result":{}}\n' > "$RESP/3.out"
  printf '{"ok":true,"result":{}}\n' > "$RESP/4.out"
  add_tmux_fake "$FB"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_HOME="$home" "$ROOT/bin/fm-teardown.sh" domain --force 2>&1 )
  rc=$?
  set -e
  expect_code 0 "$rc" "forced secondmate teardown should remove Orca child work through Orca"$'\n'"$out"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-child-cleanup'$'\x1f''--json' \
    "child cleanup did not close the recorded Orca terminal"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-child-cleanup::/orca/wt-child-cleanup'$'\x1f''--force'$'\x1f''--delete-branch'$'\x1f''--json' \
    "child cleanup did not remove the Orca worktree through orca worktree rm"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f'"fm-$child_id" \
    "child cleanup closed the stable alias instead of the Orca terminal"
  assert_absent "$home/state/domain.meta" "parent metadata should be removed after forced teardown"
  pass "fm-teardown.sh --force: removes Orca secondmate children through Orca"
}

test_secondmate_force_teardown_refuses_orca_child_id_path_mismatch() {
  local home subhome childproj childwt other_wt child_id neutral out rc
  home="$TMP_ROOT/orca-child-mismatch-parent"
  subhome="$TMP_ROOT/orca-child-mismatch-secondmate"
  childproj="$subhome/projects/alpha"
  childwt="$TMP_ROOT/orca-child-mismatch-worktree"
  other_wt="$TMP_ROOT/orca-child-mismatch-other-worktree"
  child_id="orcachildmismatchz1"
  mkdir -p "$home/state" "$home/data" "$subhome/state" "$subhome/projects"
  printf 'domain\n' > "$subhome/.fm-secondmate-home"
  fm_git_worktree "$childproj" "$childwt" "fm/$child_id"
  git -C "$childproj" worktree add --quiet -b "fm/$child_id-other" "$other_wt"
  fm_write_meta "$home/state/domain.meta" \
    "window=firstmate:fm-domain" "worktree=$subhome" "project=$subhome" \
    "harness=echo" "kind=secondmate" "mode=secondmate" "yolo=off" \
    "home=$subhome" "projects=alpha"
  printf '%s\n' "- domain - Orca child cleanup (home: $subhome; scope: orca cleanup; projects: alpha; added 2026-07-03)" \
    > "$home/data/secondmates.md"
  fm_write_meta "$subhome/state/$child_id.meta" \
    "window=fm-$child_id" "endpoint_task_id=$child_id" \
    "terminal=term-child-mismatch" "worktree=$childwt" "project=$childproj" \
    "harness=claude" "kind=ship" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-child-mismatch::/orca/wt-child-mismatch"
  orca_case secondmate-child-mismatch
  printf '{"ok":true,"result":{"worktree":{"id":"wt-child-mismatch::/orca/wt-child-mismatch","path":"%s"}}}\n' "$other_wt" > "$RESP/1.out"
  add_tmux_fake "$FB"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_HOME="$home" "$ROOT/bin/fm-teardown.sh" domain --force 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "forced secondmate teardown should refuse mismatched Orca child id/path"
  assert_contains "$out" "not inspected worktree" \
    "mismatched Orca child worktree path refusal should name the mismatch"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close' \
    "refused mismatched Orca child cleanup should not close terminals"
  assert_not_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm' \
    "refused mismatched Orca child cleanup should not remove worktrees"
  assert_present "$home/state/domain.meta" "refused forced secondmate teardown should preserve parent metadata"
  pass "fm-teardown.sh --force: refuses Orca child id/path mismatches"
}

test_secondmate_force_teardown_refuses_partial_orca_child() {
  local home subhome childproj childwt child_id neutral out rc
  home="$TMP_ROOT/orca-partial-child-parent"
  subhome="$TMP_ROOT/orca-partial-child-secondmate"
  childproj="$subhome/projects/alpha"
  childwt="$TMP_ROOT/orca-partial-child-worktree"
  child_id="orcapartialz9"
  mkdir -p "$home/state" "$home/data" "$subhome/state" "$subhome/projects"
  printf 'domain\n' > "$subhome/.fm-secondmate-home"
  fm_git_worktree "$childproj" "$childwt" "fm/$child_id"
  fm_write_meta "$home/state/domain.meta" \
    "window=firstmate:fm-domain" "worktree=$subhome" "project=$subhome" \
    "harness=echo" "kind=secondmate" "mode=secondmate" "yolo=off" \
    "home=$subhome" "projects=alpha"
  printf '%s\n' "- domain - Orca partial child cleanup (home: $subhome; scope: orca cleanup; projects: alpha; added 2026-07-03)" \
    > "$home/data/secondmates.md"
  fm_write_meta "$subhome/state/$child_id.meta" \
    "window=fm-$child_id" "endpoint_task_id=$child_id" \
    "worktree=$childwt" "project=$childproj" \
    "harness=claude" "kind=ship" "mode=no-mistakes" "yolo=off" \
    "backend=orca" "orca_worktree_id=wt-partial-child::/orca/wt-partial-child"
  orca_case secondmate-partial-child-cleanup
  add_tmux_fake "$FB"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  set +e
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_HOME="$home" "$ROOT/bin/fm-teardown.sh" domain --force 2>&1 )
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "forced secondmate teardown accepted a child with no terminal identity"
  assert_contains "$out" "missing terminal" "partial child refusal did not explain the incomplete endpoint"
  [ ! -s "$LOG" ] || fail "partial child refusal dispatched to Orca or tmux"
  assert_present "$home/state/domain.meta" "partial child refusal removed parent metadata"
  assert_present "$subhome/state/$child_id.meta" "partial child refusal removed child metadata"
  pass "fm-teardown.sh --force: refuses partial Orca secondmate children before runtime dispatch"
}

test_dispatcher_sources_orca_and_routes_primitives() {
  local out
  orca_case dispatch
  printf '{"result":{"terminal":{"tail":["via dispatch"]}}}\n' > "$RESP/1.out"
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/fm-backend.sh"; fm_backend_validate orca; fm_backend_capture orca term-123 9' "$ROOT" )
  [ "$out" = "via dispatch" ] || fail "dispatcher should route capture to the Orca adapter, got '$out'"
  pass "fm-backend dispatcher: accepts orca and routes capture through bin/backends/orca.sh"
}

# orca_json_get: run fm_backend_orca_json_get <field> over a worktree create
# result of <shape>; prints the field and returns the parser's status.
orca_json_get() {  # <field> <shape>
  orca_worktree_response wt-json /tmp/orca-wt "$2" | \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_json_get "$1"' "$ROOT" "$1"
}

# run_orca_worktree_create: call fm_backend_orca_worktree_create /repo/path
# fm-task against a fake Orca whose worktree creation reports <shape> with
# <path> (blank omits it). Sets CREATE_OUT (stdout and stderr), CREATE_RC and
# the case's LOG. Extra arguments are numbered responses: "<n>=<json>" writes
# call <n>'s output and "<n>=exit:<code>" makes call <n> exit with that code.
run_orca_worktree_create() {  # <case> <shape> <path-or-empty> [<n>=<json>|<n>=exit:<code>...]
  local case_name=$1 shape=$2 path=$3 arg
  shift 3
  orca_case "$case_name"
  printf '1\n' > "$RESP/1.exit"
  printf '{"ok":true,"result":{"repo":{"id":"repo-%s"}}}\n' "$case_name" > "$RESP/2.out"
  orca_worktree_response "wt-$case_name::/orca/wt-$case_name" "$path" "$shape" > "$RESP/3.out"
  for arg in "$@"; do
    case "${arg#*=}" in
      exit:*) printf '%s\n' "${arg#*=exit:}" > "$RESP/${arg%%=*}.exit" ;;
      *) printf '%s\n' "${arg#*=}" > "$RESP/${arg%%=*}.out" ;;
    esac
  done
  CREATE_OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_worktree_create "$FM_TEST_REPO" fm-task' "$ROOT" 2>&1 )
  CREATE_RC=$?
}

ORCA_TERMINAL_CREATE_RESPONSE='{"ok":true,"result":{"terminal":{"handle":"term-created"}}}'

test_spawn_adopts_the_terminal_shape_and_prefers_it_over_a_startup_terminal() {
  local shape id n=0
  for shape in terminal both; do
    n=$((n + 1))
    id="orcashapez$n"
    run_orca_spawn "spawn-shape-$shape" "$id" "$shape"
    expect_code 0 "$SPAWN_RC" "spawn should succeed with the $shape result"$'\n'"$SPAWN_OUT"
    assert_grep "terminal=term-legacy" "$SPAWN_STATE/$id.meta" "meta should record the result.terminal handle for $shape"
    [ "$(orca_log_count terminal create)" = 0 ] || fail "spawn must not create a second terminal for $shape"
  done
  pass "fm-spawn.sh --backend orca: adopts result.terminal, and prefers it when a startup terminal is also reported"
}

test_spawn_titles_a_terminal_reported_in_the_terminal_shape() {
  local id=orcatitleshapez1
  run_orca_spawn spawn-title-terminal-shape "$id" terminal
  expect_code 0 "$SPAWN_RC" "spawn should succeed with the terminal result"$'\n'"$SPAWN_OUT"
  [ "$(orca_log_count terminal rename)" = 1 ] \
    || fail "spawn should title an adopted result.terminal terminal exactly once"$'\n'"$(tr '\037' ' ' < "$LOG")"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''rename'$'\x1f''--terminal'$'\x1f''term-legacy'$'\x1f''--title'$'\x1f'"fm-$id"$'\x1f''--json' \
    "the adopted result.terminal terminal should be titled with the task name"
  pass "fm-spawn.sh --backend orca: titles a terminal reported in the result.terminal shape"
}

test_spawn_creates_one_titled_terminal_when_orca_reports_none() {
  local id=orcanoneterm1
  run_orca_spawn spawn-no-terminal "$id" none "4=$ORCA_TERMINAL_CREATE_RESPONSE"
  expect_code 0 "$SPAWN_RC" "spawn should fall back to creating a terminal"$'\n'"$SPAWN_OUT"
  [ "$(orca_log_count terminal create)" = 1 ] || fail "spawn should create exactly one terminal when Orca reports none"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''create'$'\x1f''--worktree'$'\x1f''id:wt-spawn-no-terminal::/orca/wt-spawn-no-terminal'$'\x1f''--title'$'\x1f'"fm-$id"$'\x1f''--json' \
    "the created terminal should be titled with the task name"
  [ "$(orca_log_count terminal rename)" = 0 ] || fail "a terminal created with its title needs no rename"
  assert_grep "terminal=term-created" "$SPAWN_STATE/$id.meta" "meta should record the created terminal"
  pass "fm-spawn.sh --backend orca: creates exactly one titled terminal when Orca reports none"
}

test_spawn_creates_a_terminal_for_an_unusable_startup_terminal() {
  local shape id n=0
  for shape in startup-unspawned startup-emptyhandle startup-nohandle; do
    n=$((n + 1))
    id="orcaunusablez$n"
    run_orca_spawn "spawn-unusable-$shape" "$id" "$shape" "4=$ORCA_TERMINAL_CREATE_RESPONSE"
    expect_code 0 "$SPAWN_RC" "spawn should fall back to creating a terminal for $shape"$'\n'"$SPAWN_OUT"
    [ "$(orca_log_count terminal create)" = 1 ] || fail "spawn should create exactly one terminal for $shape"
    assert_grep "terminal=term-created" "$SPAWN_STATE/$id.meta" "meta should record the created terminal for $shape"
  done
  pass "fm-spawn.sh --backend orca: creates a terminal when the startup terminal was not spawned or has no handle"
}

test_spawn_with_a_pathless_startup_terminal_closes_and_releases_everything() {
  local id=orcapathlessst1
  SPAWN_OMIT_PATH=1 run_orca_spawn spawn-pathless-startup "$id" startup
  [ "$SPAWN_RC" -ne 0 ] || fail "spawn should fail when Orca omits the worktree path"
  assert_contains "$SPAWN_OUT" "orca worktree create did not return a path" "spawn should explain the missing path"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-startup'$'\x1f''--json' \
    "spawn should close the startup terminal of a pathless worktree"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-spawn-pathless-startup::/orca/wt-spawn-pathless-startup' \
    "spawn should release the pathless worktree"
  [ "$(orca_log_count terminal rename)" = 0 ] || fail "a worktree being released must not have its terminal titled"
  pass "fm-spawn.sh --backend orca: a pathless startup-terminal worktree is closed and released"
}

test_spawn_succeeds_when_titling_the_adopted_terminal_fails() {
  local id=orcarenamefailz1
  run_orca_spawn spawn-rename-fails "$id" startup 4=exit:1
  [ "$(orca_log_count terminal rename)" = 1 ] || fail "the rename should have been attempted"
  expect_code 0 "$SPAWN_RC" "a failed title must not fail the spawn"$'\n'"$SPAWN_OUT"
  assert_grep "terminal=term-startup" "$SPAWN_STATE/$id.meta" "meta should still record the adopted terminal"
  [ "$(orca_log_count terminal create)" = 0 ] || fail "a failed title must not trigger a second terminal"
  pass "fm-spawn.sh --backend orca: a failed terminal title does not fail the spawn"
}

test_worktree_create_titles_the_adopted_startup_terminal() {
  run_orca_worktree_create create-rename-startup startup /tmp/orca-wt
  expect_code 0 "$CREATE_RC" "worktree create should succeed with a startup terminal"$'\n'"$CREATE_OUT"
  [ "$(orca_log_count terminal rename)" = 1 ] \
    || fail "worktree create should title the adopted terminal exactly once"$'\n'"$(cat "$LOG")"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''rename'$'\x1f''--terminal'$'\x1f''term-startup'$'\x1f''--title'$'\x1f''fm-task'$'\x1f''--json' \
    "worktree create should title the adopted terminal with the task name"
  pass "fm_backend_orca_worktree_create: titles the adopted startup terminal with the task name"
}

test_worktree_create_prints_the_startup_terminal_as_the_third_field() {
  local expect
  run_orca_worktree_create create-print-startup startup /tmp/orca-wt
  expect=$'wt-create-print-startup::/orca/wt-create-print-startup\t/tmp/orca-wt\tterm-startup'
  expect_code 0 "$CREATE_RC" "worktree create should succeed with a startup terminal"$'\n'"$CREATE_OUT"
  [ "$CREATE_OUT" = "$expect" ] || fail "worktree create should print id, path, and the startup handle, got '$CREATE_OUT'"
  pass "fm_backend_orca_worktree_create: prints the startup terminal handle after the id and path"
}

test_worktree_create_survives_a_rename_that_exits_non_zero() {
  local expect
  run_orca_worktree_create create-rename-exit startup /tmp/orca-wt 4=exit:1
  expect=$'wt-create-rename-exit::/orca/wt-create-rename-exit\t/tmp/orca-wt\tterm-startup'
  [ "$(orca_log_count terminal rename)" = 1 ] || fail "the rename should have been attempted"
  expect_code 0 "$CREATE_RC" "a rename that exits non-zero must not fail worktree create"$'\n'"$CREATE_OUT"
  [ "$CREATE_OUT" = "$expect" ] || fail "worktree create should still adopt the terminal after a failed rename, got '$CREATE_OUT'"
  pass "fm_backend_orca_worktree_create: a rename that exits non-zero does not fail the create"
}

test_worktree_create_survives_a_rename_that_reports_an_error() {
  local expect
  run_orca_worktree_create create-rename-error startup /tmp/orca-wt \
    '4={"ok":false,"error":{"code":"terminal_not_found","message":"terminal not found"}}'
  expect=$'wt-create-rename-error::/orca/wt-create-rename-error\t/tmp/orca-wt\tterm-startup'
  [ "$(orca_log_count terminal rename)" = 1 ] || fail "the rename should have been attempted"
  expect_code 0 "$CREATE_RC" "a rename that reports ok:false must not fail worktree create"$'\n'"$CREATE_OUT"
  [ "$CREATE_OUT" = "$expect" ] || fail "worktree create should still adopt the terminal after a rename error, got '$CREATE_OUT'"
  pass "fm_backend_orca_worktree_create: a rename that reports ok:false does not fail the create"
}

test_worktree_create_issues_no_rename_without_a_terminal() {
  local expect
  run_orca_worktree_create create-no-terminal none /tmp/orca-wt
  expect=$'wt-create-no-terminal::/orca/wt-create-no-terminal\t/tmp/orca-wt'
  expect_code 0 "$CREATE_RC" "worktree create should succeed with no terminal"$'\n'"$CREATE_OUT"
  [ "$CREATE_OUT" = "$expect" ] || fail "worktree create should print only id and path with no terminal, got '$CREATE_OUT'"
  [ "$(orca_log_count terminal rename)" = 0 ] || fail "there is no terminal to title, so no rename should be issued"
  pass "fm_backend_orca_worktree_create: issues no rename when Orca returns no terminal"
}

test_worktree_create_releases_a_pathless_worktree_and_its_startup_terminal() {
  run_orca_worktree_create create-pathless-startup startup ''
  [ "$CREATE_RC" -ne 0 ] || fail "worktree create should fail when Orca omits the path"
  assert_contains "$CREATE_OUT" "orca worktree create did not return a path for fm-task" \
    "worktree create did not explain the missing path"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-startup'$'\x1f''--json' \
    "worktree create did not close the startup terminal when the path was missing"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f''id:wt-create-pathless-startup::/orca/wt-create-pathless-startup' \
    "worktree create did not release the pathless worktree"
  [ "$(orca_log_count terminal rename)" = 0 ] || fail "a worktree that is being released must not have its terminal titled"
  pass "fm_backend_orca_worktree_create: closes the startup terminal and releases the worktree when the path is missing"
}

test_spawn_adopts_startup_terminal_without_creating_another() {
  local id=orcastartz1
  run_orca_spawn startup-adopt "$id" startup
  expect_code 0 "$SPAWN_RC" "spawn should succeed when Orca reports a startup terminal"$'\n'"$SPAWN_OUT"
  assert_grep "terminal=term-startup" "$SPAWN_STATE/$id.meta" "meta should record the startup terminal"
  [ "$(orca_log_count terminal create)" = 0 ] \
    || fail "spawn must not create a second terminal when Orca reports a startup terminal"
  [ "$(orca_log_count terminal rename)" = 1 ] \
    || fail "spawn should title the adopted startup terminal exactly once"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''rename'$'\x1f''--terminal'$'\x1f''term-startup'$'\x1f''--title'$'\x1f'"fm-$id"$'\x1f''--json' \
    "the adopted startup terminal should be titled with the task name"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''send'$'\x1f''--terminal'$'\x1f''term-startup'$'\x1f''--text'$'\x1f''export GOTMPDIR=/tmp/fm-'"$id"'/gotmp' \
    "the launch should reach the harness through the adopted terminal"
  pass "fm-spawn.sh --backend orca: adopts the startup terminal and creates no second terminal"
}

test_json_get_adopts_startup_terminal_handle() {
  local out
  out=$(orca_json_get worktree-terminal-handle startup)
  [ "$out" = term-startup ] || fail "worktree-terminal-handle should read result.startupTerminal.handle, got '$out'"
  pass "fm_backend_orca_json_get: worktree-terminal-handle adopts result.startupTerminal.handle"
}

test_json_get_ignores_startup_terminal_that_was_not_spawned() {
  local out status
  out=$(orca_json_get worktree-terminal-handle startup-unspawned)
  status=$?
  [ "$status" -ne 0 ] || fail "worktree-terminal-handle should find no terminal when spawned is false, got '$out'"
  [ -z "$out" ] || fail "worktree-terminal-handle should print nothing when spawned is false, got '$out'"
  pass "fm_backend_orca_json_get: worktree-terminal-handle ignores a startup terminal Orca did not spawn"
}

test_json_get_adopts_startup_terminal_without_spawned_flag() {
  local out
  out=$(orca_json_get worktree-terminal-handle startup-nospawned)
  [ "$out" = term-startup ] || fail "a startup terminal with no spawned flag is not 'spawned: false' and should be adopted, got '$out'"
  pass "fm_backend_orca_json_get: worktree-terminal-handle adopts a startup terminal whose spawned flag is absent"
}

test_json_get_ignores_startup_terminal_without_a_handle() {
  local out status shape
  for shape in startup-emptyhandle startup-nohandle; do
    out=$(orca_json_get worktree-terminal-handle "$shape")
    status=$?
    [ "$status" -ne 0 ] || fail "worktree-terminal-handle should find no terminal for $shape, got '$out'"
    [ -z "$out" ] || fail "worktree-terminal-handle should print nothing for $shape, got '$out'"
  done
  pass "fm_backend_orca_json_get: worktree-terminal-handle ignores a startup terminal with an empty or missing handle"
}

test_json_get_prefers_terminal_over_startup_terminal() {
  local out
  out=$(orca_json_get worktree-terminal-handle both)
  [ "$out" = term-legacy ] || fail "result.terminal should win when both shapes are present, got '$out'"
  pass "fm_backend_orca_json_get: worktree-terminal-handle prefers result.terminal over result.startupTerminal"
}

test_json_get_terminal_handle_field_ignores_startup_terminal() {
  local out status
  out=$(orca_json_get terminal-handle startup)
  status=$?
  [ "$status" -ne 0 ] || fail "terminal-handle parses a terminal create result and must not read startupTerminal, got '$out'"
  [ -z "$out" ] || fail "terminal-handle should print nothing for a startupTerminal-only result, got '$out'"
  pass "fm_backend_orca_json_get: terminal-handle (terminal create results) ignores result.startupTerminal"
}

# orca_list_json: an Orca `terminal list --worktree` result holding the given
# row objects, in the shape observed live on Orca 1.4.261.
orca_list_json() {  # <row-json>...
  local rows=
  while [ "$#" -gt 0 ]; do
    rows="${rows:+$rows,}$1"
    shift
  done
  printf '{"ok":true,"result":{"terminals":[%s],"hostScope":{"hostIds":["local"],"omittedHostIds":[]},"totalCount":1,"truncated":false}}\n' "$rows"
}

# listed_handle: run `fm_backend_orca_json_get listed-terminal-handle <id>` over
# a terminal list result; prints the handle and returns the parser's status.
listed_handle() {  # <worktree-id> <list-json>
  printf '%s' "$2" | bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_json_get listed-terminal-handle "$1"' "$ROOT" "$1"
}

test_json_get_listed_terminal_reads_the_first_handle() {
  local out
  out=$(listed_handle wt-a "$(orca_list_json \
    '{"handle":"term-first","worktreeId":"wt-a","orphaned":false,"connected":true,"writable":true}' \
    '{"handle":"term-second","worktreeId":"wt-a","orphaned":false,"writable":true}')")
  [ "$out" = term-first ] || fail "listed-terminal-handle should read the first usable row, got '$out'"
  pass "fm_backend_orca_json_get: listed-terminal-handle reads the first listed terminal"
}

test_json_get_listed_terminal_skips_unusable_rows() {
  local out status
  out=$(listed_handle wt-a "$(orca_list_json \
    '{"handle":"term-orphan","worktreeId":"wt-a","orphaned":true,"writable":true}' \
    '{"handle":"term-ro","worktreeId":"wt-a","orphaned":false,"writable":false}' \
    '{"handle":"term-other","worktreeId":"wt-b","orphaned":false,"writable":true}' \
    '{"handle":"","worktreeId":"wt-a"}' \
    '{"worktreeId":"wt-a"}' \
    '{"handle":"term-good","worktreeId":"wt-a"}')")
  [ "$out" = term-good ] || fail "listed-terminal-handle should skip orphaned, unwritable, other-worktree, and handle-less rows, got '$out'"
  out=$(listed_handle wt-a "$(orca_list_json '{"handle":"term-nowt"}')")
  [ "$out" = term-nowt ] || fail "a row that names no worktree is the filtered worktree's, got '$out'"
  status=0
  out=$(listed_handle wt-a "$(orca_list_json \
    '{"handle":"term-orphan","worktreeId":"wt-a","orphaned":true}' \
    '{"handle":"term-other","worktreeId":"wt-b"}')") || status=$?
  [ "$status" -ne 0 ] && [ -z "$out" ] || fail "listed-terminal-handle should find nothing when every row is unusable, got '$out' (status $status)"
  status=0
  out=$(listed_handle wt-a '{"ok":true,"result":{"terminals":[],"totalCount":0}}') || status=$?
  [ "$status" -ne 0 ] && [ -z "$out" ] || fail "listed-terminal-handle should find nothing in an empty list, got '$out'"
  status=0
  out=$(listed_handle wt-a '{"ok":false,"error":{"code":"x","message":"boom"}}' 2>/dev/null) || status=$?
  [ "$status" -ne 0 ] && [ -z "$out" ] || fail "listed-terminal-handle should find nothing in an error result, got '$out'"
  pass "fm_backend_orca_json_get: listed-terminal-handle skips orphaned, unwritable, other-worktree, and handle-less terminals"
}

# orca_listed_row: one `terminal list` row for the worktree a case created
# (the id run_orca_worktree_create and run_orca_spawn give it).
orca_listed_row() {  # <case> <handle>
  printf '{"handle":"%s","worktreeId":"wt-%s::/orca/wt-%s","orphaned":false,"connected":true,"writable":true}' "$2" "$1" "$1"
}

test_worktree_create_adopts_the_listed_terminal_as_the_third_field() {
  local expect id
  id="wt-create-list-adopt::/orca/wt-create-list-adopt"
  run_orca_worktree_create create-list-adopt none /tmp/orca-wt \
    "terminal-list=$(orca_list_json "$(orca_listed_row create-list-adopt term-listed)")"
  expect="$id"$'\t/tmp/orca-wt\tterm-listed'
  expect_code 0 "$CREATE_RC" "worktree create should succeed with a listed terminal"$'\n'"$CREATE_OUT"
  [ "$CREATE_OUT" = "$expect" ] || fail "worktree create should print id, path, and the listed handle, got '$CREATE_OUT'"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''list'$'\x1f''--worktree'$'\x1f'"id:$id"$'\x1f''--json' \
    "worktree create should list the new worktree's terminals by exact id"
  [ "$(orca_log_count terminal create)" = 0 ] || fail "worktree create must not create a terminal when one is listed"
  pass "fm_backend_orca_worktree_create: adopts the listed terminal when the response names none"
}

test_worktree_create_titles_the_listed_terminal() {
  run_orca_worktree_create create-list-title none /tmp/orca-wt \
    "terminal-list=$(orca_list_json "$(orca_listed_row create-list-title term-listed)")"
  expect_code 0 "$CREATE_RC" "worktree create should succeed with a listed terminal"$'\n'"$CREATE_OUT"
  [ "$(orca_log_count terminal rename)" = 1 ] \
    || fail "worktree create should title the listed terminal exactly once"$'\n'"$(tr '\037' ' ' < "$LOG")"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''rename'$'\x1f''--terminal'$'\x1f''term-listed'$'\x1f''--title'$'\x1f''fm-task'$'\x1f''--json' \
    "worktree create should title the listed terminal with the task name"
  pass "fm_backend_orca_worktree_create: titles the listed terminal with the task name"
}

test_spawn_adopts_the_listed_terminal_when_the_response_names_none() {
  local id=orcalistadopt1
  run_orca_spawn spawn-list-adopt "$id" none \
    "terminal-list=$(orca_list_json "$(orca_listed_row spawn-list-adopt term-listed)")"
  expect_code 0 "$SPAWN_RC" "spawn should adopt the listed terminal"$'\n'"$SPAWN_OUT"
  assert_grep "terminal=term-listed" "$SPAWN_STATE/$id.meta" "meta should record the listed terminal"
  [ "$(orca_log_count terminal create)" = 0 ] || fail "spawn must not create a terminal when Orca lists one"
  [ "$(orca_log_count terminal rename)" = 1 ] || fail "spawn should title the listed terminal exactly once"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''rename'$'\x1f''--terminal'$'\x1f''term-listed'$'\x1f''--title'$'\x1f'"fm-$id"$'\x1f''--json' \
    "the listed terminal should be titled with the task name"
  pass "fm-spawn.sh --backend orca: adopts the listed terminal and creates no second terminal when the response names none"
}

test_spawn_does_not_list_terminals_when_the_response_names_one() {
  local shape id n=0
  for shape in terminal startup both; do
    n=$((n + 1))
    id="orcanolistz$n"
    run_orca_spawn "spawn-nolist-$shape" "$id" "$shape" \
      "terminal-list=$(orca_list_json "$(orca_listed_row "spawn-nolist-$shape" term-listed)")"
    expect_code 0 "$SPAWN_RC" "spawn should succeed with the $shape result"$'\n'"$SPAWN_OUT"
    [ "$(orca_log_count terminal list)" = 0 ] || fail "spawn must not list terminals when the response names one ($shape)"
    ! grep -q "terminal=term-listed" "$SPAWN_STATE/$id.meta" || fail "the listed terminal must not win over the response's own ($shape)"
  done
  pass "fm-spawn.sh --backend orca: a terminal named by the response is adopted without listing terminals"
}

test_spawn_creates_one_terminal_when_the_list_is_empty() {
  local id=orcalistempty1
  run_orca_spawn spawn-list-empty "$id" none "4=$ORCA_TERMINAL_CREATE_RESPONSE"
  expect_code 0 "$SPAWN_RC" "spawn should fall back to creating a terminal"$'\n'"$SPAWN_OUT"
  [ "$(orca_log_count terminal list)" = 1 ] || fail "spawn should look for the worktree's terminal before creating one"
  [ "$(orca_log_count terminal create)" = 1 ] || fail "spawn should create exactly one terminal when the list is empty"
  assert_grep "terminal=term-created" "$SPAWN_STATE/$id.meta" "meta should record the created terminal"
  pass "fm-spawn.sh --backend orca: creates exactly one terminal when Orca lists none for the worktree"
}

test_spawn_creates_a_terminal_when_the_list_cannot_be_read() {
  local id n=0 mode
  for mode in 'exit:1' '{"ok":false,"error":{"code":"runtime_unavailable","message":"no runtime"}}' 'not json at all'; do
    n=$((n + 1))
    id="orcalistbadz$n"
    run_orca_spawn "spawn-list-bad-$n" "$id" none "terminal-list=$mode" "4=$ORCA_TERMINAL_CREATE_RESPONSE"
    expect_code 0 "$SPAWN_RC" "an unreadable list ($mode) must not fail the spawn"$'\n'"$SPAWN_OUT"
    [ "$(orca_log_count terminal create)" = 1 ] || fail "spawn should create exactly one terminal when the list is unreadable ($mode)"
    assert_grep "terminal=term-created" "$SPAWN_STATE/$id.meta" "meta should record the created terminal ($mode)"
  done
  pass "fm-spawn.sh --backend orca: an unreadable terminal list falls back to creating one terminal"
}

test_spawn_creates_a_terminal_when_no_listed_terminal_is_usable() {
  local id=orcalistunusable1 c=spawn-list-unusable
  run_orca_spawn "$c" "$id" none "4=$ORCA_TERMINAL_CREATE_RESPONSE" \
    "terminal-list=$(orca_list_json \
      "{\"handle\":\"term-orphan\",\"worktreeId\":\"wt-$c::/orca/wt-$c\",\"orphaned\":true,\"writable\":true}" \
      "{\"handle\":\"term-ro\",\"worktreeId\":\"wt-$c::/orca/wt-$c\",\"orphaned\":false,\"writable\":false}" \
      '{"handle":"term-foreign","worktreeId":"someone-else::/elsewhere","orphaned":false,"writable":true}')"
  expect_code 0 "$SPAWN_RC" "spawn should fall back to creating a terminal"$'\n'"$SPAWN_OUT"
  [ "$(orca_log_count terminal create)" = 1 ] || fail "spawn should create exactly one terminal when no listed terminal is usable"
  assert_grep "terminal=term-created" "$SPAWN_STATE/$id.meta" "meta should record the created terminal"
  [ "$(orca_log_count terminal rename)" = 0 ] || fail "a foreign or unusable terminal must never be titled"
  pass "fm-spawn.sh --backend orca: creates a terminal when the list holds only unusable or foreign terminals"
}

test_spawn_with_a_pathless_listed_terminal_closes_and_releases_everything() {
  local id=orcapathlesslist1 c=spawn-pathless-list
  SPAWN_OMIT_PATH=1 run_orca_spawn "$c" "$id" none \
    "terminal-list=$(orca_list_json "$(orca_listed_row "$c" term-listed)")"
  [ "$SPAWN_RC" -ne 0 ] || fail "spawn should fail when Orca omits the worktree path"
  assert_contains "$SPAWN_OUT" "orca worktree create did not return a path" "spawn should explain the missing path"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-listed'$'\x1f''--json' \
    "spawn should close the listed terminal of a pathless worktree"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f'"id:wt-$c::/orca/wt-$c" \
    "spawn should release the pathless worktree"
  [ "$(orca_log_count terminal rename)" = 0 ] || fail "a worktree being released must not have its terminal titled"
  pass "fm-spawn.sh --backend orca: a pathless worktree's listed terminal is closed and the worktree released"
}

test_spawn_succeeds_when_titling_the_listed_terminal_fails() {
  local id=orcalistrenamefail1 c=spawn-list-rename-fails
  run_orca_spawn "$c" "$id" none 4=exit:1 \
    "terminal-list=$(orca_list_json "$(orca_listed_row "$c" term-listed)")"
  [ "$(orca_log_count terminal rename)" = 1 ] || fail "the rename should have been attempted"
  expect_code 0 "$SPAWN_RC" "a failed title must not fail the spawn"$'\n'"$SPAWN_OUT"
  assert_grep "terminal=term-listed" "$SPAWN_STATE/$id.meta" "meta should still record the listed terminal"
  [ "$(orca_log_count terminal create)" = 0 ] || fail "a failed title must not trigger a second terminal"
  pass "fm-spawn.sh --backend orca: a failed title of the listed terminal does not fail the spawn"
}

# A task whose terminal was adopted from the list is torn down through the same
# path as any other: exactly the recorded handle is closed, and the worktree is
# released afterwards.
test_teardown_closes_exactly_the_adopted_listed_terminal() {
  local id=orcalistteardown1 c=spawn-list-teardown next out rc neutral
  run_orca_spawn "$c" "$id" none \
    "terminal-list=$(orca_list_json "$(orca_listed_row "$c" term-listed)")"
  expect_code 0 "$SPAWN_RC" "spawn should adopt the listed terminal"$'\n'"$SPAWN_OUT"
  assert_grep "terminal=term-listed" "$SPAWN_STATE/$id.meta" "meta should record the listed terminal"
  : > "$LOG"
  next=$(( $(cat "$RESP/.count") + 1 ))
  printf '{"ok":true,"result":{"worktree":{"id":"wt-%s::/orca/wt-%s","path":"%s"}}}\n' "$c" "$c" "$SPAWN_WT" > "$RESP/$next.out"
  neutral=$(neutral_fm_root "$CASE_DIR/neutral")
  out=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$neutral" FM_STATE_OVERRIDE="$SPAWN_STATE" FM_DATA_OVERRIDE="$TMP_ROOT/$c-data" FM_CONFIG_OVERRIDE="$TMP_ROOT/$c-config" \
    "$ROOT/bin/fm-teardown.sh" "$id" 2>&1 ) && rc=0 || rc=$?
  expect_code 0 "$rc" "teardown of an adopted-terminal task should succeed"$'\n'"$out"
  [ "$(orca_log_count terminal close)" = 1 ] || fail "teardown should close exactly one terminal"$'\n'"$(tr '\037' ' ' < "$LOG")"
  assert_contains "$(cat "$LOG")" $'orca\x1f''terminal'$'\x1f''close'$'\x1f''--terminal'$'\x1f''term-listed'$'\x1f''--json' \
    "teardown should close the recorded, adopted terminal"
  [ "$(orca_log_count terminal list)" = 0 ] || fail "teardown must not list terminals; it closes only the recorded one"
  assert_contains "$(cat "$LOG")" $'orca\x1f''worktree'$'\x1f''rm'$'\x1f''--worktree'$'\x1f'"id:wt-$c::/orca/wt-$c" \
    "teardown should release the worktree"
  assert_absent "$SPAWN_STATE/$id.meta" "teardown should remove the task metadata"
  pass "fm-teardown.sh backend=orca: closes exactly the terminal that spawn adopted from the list"
}

test_json_get_listed_terminal_reads_the_first_handle
test_json_get_listed_terminal_skips_unusable_rows
test_worktree_create_adopts_the_listed_terminal_as_the_third_field
test_worktree_create_titles_the_listed_terminal
test_spawn_adopts_the_listed_terminal_when_the_response_names_none
test_spawn_does_not_list_terminals_when_the_response_names_one
test_spawn_creates_one_terminal_when_the_list_is_empty
test_spawn_creates_a_terminal_when_the_list_cannot_be_read
test_spawn_creates_a_terminal_when_no_listed_terminal_is_usable
test_spawn_with_a_pathless_listed_terminal_closes_and_releases_everything
test_spawn_succeeds_when_titling_the_listed_terminal_fails
test_teardown_closes_exactly_the_adopted_listed_terminal
test_spawn_adopts_startup_terminal_without_creating_another
test_spawn_adopts_the_terminal_shape_and_prefers_it_over_a_startup_terminal
test_spawn_titles_a_terminal_reported_in_the_terminal_shape
test_spawn_creates_one_titled_terminal_when_orca_reports_none
test_spawn_creates_a_terminal_for_an_unusable_startup_terminal
test_spawn_with_a_pathless_startup_terminal_closes_and_releases_everything
test_spawn_succeeds_when_titling_the_adopted_terminal_fails
test_worktree_create_titles_the_adopted_startup_terminal
test_worktree_create_prints_the_startup_terminal_as_the_third_field
test_worktree_create_survives_a_rename_that_exits_non_zero
test_worktree_create_survives_a_rename_that_reports_an_error
test_worktree_create_issues_no_rename_without_a_terminal
test_worktree_create_releases_a_pathless_worktree_and_its_startup_terminal
test_json_get_adopts_startup_terminal_handle
test_json_get_ignores_startup_terminal_that_was_not_spawned
test_json_get_adopts_startup_terminal_without_spawned_flag
test_json_get_ignores_startup_terminal_without_a_handle
test_json_get_prefers_terminal_over_startup_terminal
test_json_get_terminal_handle_field_ignores_startup_terminal
test_capture_reads_terminal_tail_json
test_capture_falls_back_to_text_fields
test_capture_fails_on_orca_error_json
test_runtime_check_accepts_ready_orca_status
test_runtime_check_refuses_unready_orca_status
test_send_text_submit_verifies_empty_composer_after_enter
test_send_text_submit_borderless_claude_confirms
test_composer_state_stale_banner_never_wins
test_send_text_submit_retries_when_composer_stays_pending
test_composer_state_popup_placeholder_fill_is_pending
test_composer_state_bare_shell_prompt_is_unknown
test_send_text_submit_popup_autocomplete_requires_second_enter
test_send_literal_constructs_non_enter_send
test_send_text_submit_reports_send_failed
test_send_helpers_reject_orca_error_json
test_send_key_enter_and_interrupt
test_send_key_refuses_unknown_key
test_send_key_escape_sends_a_raw_escape_byte
test_send_key_ctrl_u_sends_a_raw_nak_byte
test_send_key_escape_and_ctrl_u_accept_their_spellings
test_send_key_refuses_escape_and_ctrl_u_without_the_capability
test_send_key_refuses_escape_when_the_status_is_unreadable
test_send_key_enter_and_ctrl_c_ignore_the_capability_gate
test_runtime_check_records_the_version_and_capabilities
test_runtime_check_refuses_a_version_below_the_floor
test_runtime_check_accepts_the_floor_and_anything_above_it
test_runtime_check_does_not_refuse_a_missing_or_unreadable_version
test_kill_is_best_effort_close
test_kill_refuses_when_the_orca_cli_is_absent
test_remove_worktree_refuses_empty_id
test_remove_worktree_asks_orca_to_delete_the_branch_safely
test_remove_worktree_rejects_orca_error_json
test_worktree_path_resolves_id
# --- delivery receipts (specs/007-orca-delivery-receipts) ---------------------------------
# The fake orca lists the receipt capability when FM_ORCA_STATUS_CAPS is set, and
# can answer a verb with a fixed response (by-<noun>-<verb>.out/.exit) so a
# whole-script run does not depend on the call count.

RECEIPT_CAPS='["terminal.program-status.v1","terminal.prompt-delivery.v1"]'
COMPOSER_EMPTY='{"ok":true,"result":{"terminal":{"tail":["╭───╮","│ > │","╰───╯"]}}}'
COMPOSER_PENDING='{"ok":true,"result":{"terminal":{"tail":["╭─────────────────╮","│ > hello captain │","╰─────────────────╯"]}}}'
COMPOSER_UNKNOWN='{"ok":true,"result":{"terminal":{"tail":["some earlier output","kunchen@mac firstmate $ "]}}}'
ACCEPT_OK='{"ok":true,"result":{"send":{"handle":"term-123","accepted":true}}}'

rc_prompt() {  # <request-id> <stages-json> <provider> <observation> [replayed]
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true,"bytesWritten":13,"prompt":{"requestId":"%s","stages":%s,"provider":"%s","observation":"%s"}},"mutation":{"requestId":"%s","replayed":%s}}}\n' \
    "$1" "$2" "$3" "$4" "$1" "${5:-false}"
}
rc_started() { rc_prompt "$1" '["input_accepted","turn_started"]' claude supported "${2:-false}"; }
rc_accepted() { rc_prompt "$1" '["input_accepted"]' claude supported "${2:-false}"; }
rc_unsupported() { rc_prompt "$1" '["input_accepted"]' unsupported unsupported; }
rc_blocked() {  # <request-id> (the runtime's refusal while a permission or trust prompt is showing)
  printf '{"ok":false,"error":{"code":"agent_prompt_blocked","message":"The agent is showing a permission or trust prompt; to answer it, send --text and --enter as separate commands. Terminal prompt request ID: %s. Re-issue the exact command with --retry-request %s; do not retry it without that ID."}}\n' "$1" "$1"
}
rc_hookless() {  # <request-id> (accepted by a recognized agent with no hook events: a warning, no turn_started)
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":true,"bytesWritten":13,"prompt":{"requestId":"%s","stages":["input_accepted"],"provider":"claude","observation":"supported"}},"mutation":{"requestId":"%s","replayed":false},"warnings":["no turn start was observed; replay with --retry-request %s --wait-submit <seconds>"]}}\n' "$1" "$1" "$1"
}
rc_gone() {  # <request-id>
  printf '{"ok":false,"error":{"code":"terminal_not_writable","message":"terminal_not_writable Terminal prompt request ID: %s. Re-issue the exact command with --retry-request %s --wait-submit <seconds>; do not retry it without that ID."}}\n' "$1" "$1"
}

# receipt_run <terminal> <text> <retries>: the adapter against the fake, with the
# receipt capability listed unless RECEIPT_NO_CAPS=1. Sets OUT, ERR, RC.
receipt_run() {
  local caps=$RECEIPT_CAPS
  [ "${RECEIPT_NO_CAPS:-0}" != 1 ] || caps=
  RC=0
  OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_CAPS="$caps" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit "$1" "$2" "$3" 0.01 0.01' "$ROOT" "$1" "$2" "$3" 2>"$CASE_DIR/err" ) || RC=$?
  ERR=$(cat "$CASE_DIR/err")
}
orca_sends() { grep -a -F $'orca\x1fterminal\x1fsend' "$LOG" || true; }
orca_send_count() { orca_sends | grep -a -c -F -e "$1" || true; }
# Enter-only sends (the shared Enter retry), and replays that carry a request id.
orca_enter_only_count() { orca_send_count $'--text\x1f\x1f--enter'; }
orca_replay_count() { orca_send_count $'--retry-request'; }
orca_all_sends() { orca_sends | grep -a -c . || true; }

test_has_capability_reads_the_status_list() {
  local cap=terminal.prompt-delivery.v1 rc
  has() {  # <env-assignment...> -> rc of fm_backend_orca_has_capability
    # shellcheck disable=SC2016  # the single quotes are deliberate: $0 belongs to the inner bash
    env PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" "$@" \
      bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_has_capability terminal.prompt-delivery.v1' "$ROOT"
  }
  orca_case caps
  rc=0; has FM_ORCA_STATUS_CAPS="$RECEIPT_CAPS" || rc=$?
  [ "$rc" -eq 0 ] || fail "a status list naming $cap should report the capability, got rc=$rc"
  rc=0; has FM_ORCA_STATUS_CAPS='["terminal.program-status.v1"]' || rc=$?
  [ "$rc" -ne 0 ] || fail "a status list without $cap must not report it"
  rc=0; has FM_ORCA_STATUS_CAPS='["terminal.prompt-delivery.v10","x.terminal.prompt-delivery.v1"]' || rc=$?
  [ "$rc" -ne 0 ] || fail "only an exact capability name may match, not a longer or prefixed one"
  rc=0; has FM_ORCA_STATUS_RAW='{"ok":true,"result":{"runtime":{"reachable":true,"state":"ready"}}}' || rc=$?
  [ "$rc" -ne 0 ] || fail "a status with no capability list must not report the capability"
  rc=0; has FM_ORCA_STATUS_RAW='not json at all' || rc=$?
  [ "$rc" -ne 0 ] || fail "an unparseable status must not report the capability"
  rc=0; has FM_ORCA_STATUS_RAW='' FM_ORCA_STATUS_EXIT=1 || rc=$?
  [ "$rc" -ne 0 ] || fail "a failed status call must not report the capability"
  pass "fm_backend_orca_has_capability: true only for an exact name in the status list; every other answer is not supported"
}

test_receipt_class_matrix() {
  local got
  cls() { printf '%s' "$1" | bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_receipt_class' "$ROOT"; }
  expect() {  # <label> <json> <expected>
    got=$(cls "$2")
    [ "$got" = "$3" ] || fail "receipt class for $1: expected '$3', got '$got'"
  }
  expect "a started turn" "$(rc_started req-1)" $'started\treq-1'
  expect "input accepted, no turn yet" "$(rc_accepted req-2)" $'accepted\treq-2'
  expect "a plain shell" "$(rc_unsupported req-3)" $'unsupported\treq-3'
  expect "an old host" "$(rc_prompt unsupported-old-host '["input_accepted"]' old-host unsupported)" $'unsupported\tunsupported-old-host'
  expect "accepted with no prompt object" '{"ok":true,"result":{"send":{"handle":"t","accepted":true}}}' $'unsupported\t'
  expect "input not accepted" '{"ok":true,"result":{"send":{"handle":"t","accepted":false,"bytesWritten":0}}}' $'failed\tnot-accepted'
  expect "a closed or exited terminal" "$(rc_gone req-4)" $'gone\tterminal_not_writable'
  expect "a parked permission or trust prompt" "$(rc_blocked req-5)" $'blocked\tagent_prompt_blocked'
  expect "a hook-less agent that accepted input with a warning" "$(rc_hookless req-6)" $'accepted\treq-6'
  expect "an unknown handle" '{"ok":false,"error":{"code":"terminal_handle_stale","message":"stale"}}' $'gone\tterminal_handle_stale'
  expect "another runtime error" '{"ok":false,"error":{"code":"runtime_error","message":"boom"}}' $'failed\truntime_error'
  expect "invalid JSON" 'not json' $'failed\tinvalid-json'
  expect "empty output" '' $'failed\tinvalid-json'
  expect "an accepted prompt with a started stage but no request id" '{"ok":true,"result":{"send":{"accepted":true,"prompt":{"stages":["input_accepted","turn_started"],"observation":"supported"}}}}' $'started\t'
  expect "an accepted supported prompt with no request id" '{"ok":true,"result":{"send":{"accepted":true,"prompt":{"stages":["input_accepted"],"observation":"supported"}}}}' $'unsupported\t'
  pass "fm_backend_orca_receipt_class: started, accepted, unsupported, gone, and failed answers each map to one class"
}

test_receipt_started_is_empty() {
  orca_case rc-started
  rc_started req-1 > "$RESP/1.out"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = empty ] || fail "a started receipt should report empty, got '$OUT'"
  [ "$RC" -eq 0 ] || fail "a started receipt should exit 0, got $RC"
  [ "$(orca_all_sends)" -eq 1 ] || fail "a started receipt needs exactly one send, got $(orca_all_sends)"
  assert_contains "$(orca_sends)" $'--terminal\x1fterm-123\x1f--text\x1fhello captain\x1f--enter\x1f--wait-submit\x1f2\x1f--json' \
    "the receipt send must carry the text, the enter flag, and the default 2 second wait"
  [ "$(orca_log_count terminal read)" -eq 0 ] || fail "a started receipt must not read the composer"
  assert_not_contains "$(cat "$LOG")" '--retry-request' "a first send carries no request id"
  pass "fm_backend_orca_send_text_submit: a started receipt is delivery proof after one send and no composer read"
}

test_receipt_accepted_is_replayed_by_id() {
  orca_case rc-replay
  rc_accepted req-7 > "$RESP/1.out"
  rc_started req-7 true > "$RESP/2.out"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = empty ] || fail "a replay that proves the turn should report empty, got '$OUT'"
  [ "$(orca_all_sends)" -eq 2 ] || fail "one send and one replay expected, got $(orca_all_sends)"
  [ "$(orca_replay_count)" -eq 1 ] || fail "exactly one send should carry a request id, got $(orca_replay_count)"
  assert_contains "$(orca_sends | sed -n 2p)" $'--text\x1fhello captain\x1f--enter\x1f--wait-submit\x1f2\x1f--retry-request\x1freq-7' \
    "the replay must carry the same text and the first receipt's request id"
  [ "$(orca_enter_only_count)" -eq 0 ] || fail "a replay must not press Enter by itself"
  pass "fm_backend_orca_send_text_submit: an unproven receipt is replayed by its request id with the same text"
}

test_receipt_exhausted_with_empty_composer_is_empty() {
  orca_case rc-exhaust-empty
  rc_accepted req-1 > "$RESP/1.out"
  rc_accepted req-1 true > "$RESP/2.out"
  rc_accepted req-1 true > "$RESP/3.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/4.out"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = empty ] || fail "an accepted input that left the composer should report empty, got '$OUT'"
  [ "$(orca_all_sends)" -eq 3 ] || fail "the budget of 3 allows one send and two replays, got $(orca_all_sends) sends"
  [ "$(orca_replay_count)" -eq 2 ] || fail "two replays expected, got $(orca_replay_count)"
  [ "$(orca_log_count terminal read)" -eq 1 ] || fail "exactly one composer read after the budget, got $(orca_log_count terminal read)"
  pass "fm_backend_orca_send_text_submit: a receipt unproven for the whole budget with an empty composer is delivered, with no unnumbered resend"
}

test_receipt_exhausted_with_pending_composer_retries_enter_only() {
  orca_case rc-exhaust-pending
  rc_accepted req-1 > "$RESP/1.out"
  rc_accepted req-1 true > "$RESP/2.out"
  printf '%s\n' "$COMPOSER_PENDING" > "$RESP/3.out"
  printf '%s\n' "$ACCEPT_OK" > "$RESP/4.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/5.out"
  receipt_run term-123 "hello captain" 2
  [ "$OUT" = empty ] || fail "a swallowed Enter retried to an empty composer should report empty, got '$OUT'"
  [ "$(orca_enter_only_count)" -eq 1 ] || fail "exactly one Enter-only retry expected, got $(orca_enter_only_count)"
  [ "$(orca_send_count $'--text\x1fhello captain')" -eq 2 ] || fail "the text must be sent only by the receipt send and its replay"
  pass "fm_backend_orca_send_text_submit: a proven-pending composer after the receipts retries Enter only, never the text"
}

test_receipt_exhausted_with_unreadable_composer_is_pending() {
  orca_case rc-exhaust-unknown
  rc_accepted req-1 > "$RESP/1.out"
  printf '%s\n' "$COMPOSER_UNKNOWN" > "$RESP/2.out"
  receipt_run term-123 "hello captain" 1
  [ "$OUT" = pending ] || fail "input Orca accepted but the screen cannot confirm should report pending, got '$OUT'"
  [ "$RC" -eq 0 ] || fail "pending is not a send failure, got rc=$RC"
  [ "$(orca_enter_only_count)" -eq 0 ] || fail "an unreadable composer must not be blindly Entered"
  pass "fm_backend_orca_send_text_submit: accepted input with an unreadable composer is pending, never a failure"
}

test_receipt_unsupported_falls_back_to_the_composer() {
  orca_case rc-unsupported-empty
  rc_unsupported req-1 > "$RESP/1.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/2.out"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = empty ] || fail "an unsupported receipt with an empty composer should report empty, got '$OUT'"
  [ "$(orca_replay_count)" -eq 0 ] || fail "an unsupported receipt has no observation to replay"
  [ "$(orca_all_sends)" -eq 1 ] || fail "the text must be sent once, got $(orca_all_sends)"
  orca_case rc-unsupported-pending
  rc_unsupported req-1 > "$RESP/1.out"
  printf '%s\n' "$COMPOSER_PENDING" > "$RESP/2.out"
  printf '%s\n' "$ACCEPT_OK" > "$RESP/3.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/4.out"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = empty ] || fail "an unsupported receipt with a swallowed Enter should end empty, got '$OUT'"
  [ "$(orca_enter_only_count)" -eq 1 ] || fail "one Enter-only retry expected, got $(orca_enter_only_count)"
  [ "$(orca_replay_count)" -eq 0 ] || fail "an unsupported receipt must never be replayed"
  pass "fm_backend_orca_send_text_submit: an unsupported receipt falls back to the composer verdict without retyping or replaying"
}

test_receipt_gone_terminal_is_terminal_gone() {
  orca_case rc-gone
  rc_gone req-9 > "$RESP/1.out"
  printf '1\n' > "$RESP/1.exit"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = terminal-gone ] || fail "a closed or exited terminal should report terminal-gone, got '$OUT'"
  [ "$RC" -eq 1 ] || fail "terminal-gone must exit 1 so every caller reads a failed send, got $RC"
  assert_contains "$ERR" term-123 "the failure must name the terminal"
  assert_contains "$ERR" terminal_not_writable "the failure must carry the runtime's code"
  assert_contains "$ERR" "nothing was delivered" "the failure must say nothing was delivered"
  [ "$(orca_all_sends)" -eq 1 ] || fail "a gone terminal is not retried, got $(orca_all_sends) sends"
  orca_case rc-gone-unknown
  printf '{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale Terminal prompt request ID: r."}}\n' > "$RESP/1.out"
  printf '1\n' > "$RESP/1.exit"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = terminal-gone ] || fail "a handle the runtime does not know should report terminal-gone, got '$OUT'"
  assert_contains "$ERR" terminal_handle_stale "the failure must carry the runtime's code"
  pass "fm_backend_orca_send_text_submit: a gone terminal prints terminal-gone, exits 1, and names the terminal and the runtime's code"
}

test_receipt_other_failures_stay_send_failed() {
  orca_case rc-stale
  printf '{"ok":false,"error":{"code":"runtime_error","message":"the runtime tripped"}}\n' > "$RESP/1.out"
  printf '1\n' > "$RESP/1.exit"
  receipt_run term-123 "hello" 3
  [ "$OUT" = send-failed ] || fail "another runtime error is not a gone terminal, got '$OUT'"
  [ "$RC" -eq 0 ] || fail "send-failed keeps the adapter's exit 0, got $RC"
  assert_contains "$ERR" "the runtime tripped" "the runtime's message must reach stderr"
  orca_case rc-garbage
  printf 'segfault\n' > "$RESP/1.out"
  printf '1\n' > "$RESP/1.exit"
  receipt_run term-123 "hello" 3
  [ "$OUT" = send-failed ] || fail "an unparseable failure should report send-failed, got '$OUT'"
  orca_case rc-not-accepted
  printf '{"ok":true,"result":{"send":{"handle":"term-123","accepted":false,"bytesWritten":0}}}\n' > "$RESP/1.out"
  receipt_run term-123 "hello" 3
  [ "$OUT" = send-failed ] || fail "input the runtime did not accept is not delivered, got '$OUT'"
  pass "fm_backend_orca_send_text_submit: every failure other than a gone terminal stays send-failed"
}

test_receipt_blocked_prompt_is_prompt_blocked() {
  orca_case rc-blocked
  rc_blocked req-7 > "$RESP/1.out"
  printf '1\n' > "$RESP/1.exit"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = prompt-blocked ] || fail "a parked permission or trust prompt should report prompt-blocked, got '$OUT'"
  [ "$RC" -eq 1 ] || fail "prompt-blocked must exit 1 so every caller reads a failed send, got $RC"
  assert_contains "$ERR" term-123 "the failure must name the terminal"
  assert_contains "$ERR" agent_prompt_blocked "the failure must carry the runtime's code"
  assert_contains "$ERR" "permission or trust prompt" "the failure must name the blocked prompt"
  assert_contains "$ERR" "nothing was delivered" "the failure must say nothing was delivered"
  assert_not_contains "$ERR" "is gone" "a parked prompt is not a dead terminal"
  [ "$(orca_all_sends)" -eq 1 ] || fail "a blocked prompt is not retried, got $(orca_all_sends) sends"
  [ "$(orca_replay_count)" -eq 0 ] || fail "a blocked prompt must not be replayed"
  [ "$(orca_enter_only_count)" -eq 0 ] || fail "an Enter must never be sent into a parked prompt"
  pass "fm_backend_orca_send_text_submit: a parked prompt prints prompt-blocked, exits 1, names it, and sends exactly once"
}

test_receipt_blocked_replay_is_prompt_blocked() {
  orca_case rc-blocked-replay
  rc_accepted req-1 > "$RESP/1.out"
  rc_blocked req-1 > "$RESP/2.out"
  printf '1\n' > "$RESP/2.exit"
  receipt_run term-123 "hello captain" 3
  [ "$OUT" = prompt-blocked ] || fail "a replay refused by a parked prompt should report prompt-blocked, got '$OUT'"
  [ "$RC" -eq 1 ] || fail "prompt-blocked must exit 1, got $RC"
  [ "$(orca_all_sends)" -eq 2 ] || fail "the send and its one replay only, got $(orca_all_sends)"
  [ "$(orca_enter_only_count)" -eq 0 ] || fail "an Enter must never be sent into a parked prompt"
  pass "fm_backend_orca_send_text_submit: a replay refused by a parked prompt ends on prompt-blocked with nothing further typed"
}

test_receipt_hookless_accepted_is_replayed_by_id() {
  orca_case rc-hookless
  rc_hookless req-1 > "$RESP/1.out"
  rc_hookless req-1 > "$RESP/2.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/3.out"
  receipt_run term-123 "hello captain" 2
  [ "$OUT" = empty ] || fail "a hook-less accepted send that left the composer should report empty, got '$OUT'"
  [ "$RC" -eq 0 ] || fail "a hook-less accepted send is not a failure, got $RC"
  [ "$(orca_replay_count)" -eq 1 ] || fail "a hook-less accepted receipt is replayed once by id, got $(orca_replay_count)"
  [ "$(orca_all_sends)" -eq 2 ] || fail "the send and its one replay only, got $(orca_all_sends)"
  assert_contains "$(orca_sends)" $'--retry-request\x1freq-1' "the replay must carry the first receipt's id"
  pass "fm_backend_orca_send_text_submit: a hook-less send that Orca accepted with a warning is an accepted delivery, replayed by id"
}

test_receipt_wait_window_is_tunable() {
  orca_case rc-wait
  rc_started req-1 > "$RESP/1.out"
  OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_CAPS="$RECEIPT_CAPS" FM_ORCA_SUBMIT_WAIT=5 \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 hello 3 0.01 0.01' "$ROOT" )
  [ "$OUT" = empty ] || fail "got '$OUT'"
  assert_contains "$(orca_sends)" $'--wait-submit\x1f5\x1f--json' "FM_ORCA_SUBMIT_WAIT must set the wait window"
  orca_case rc-wait-bad
  rc_started req-1 > "$RESP/1.out"
  OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_CAPS="$RECEIPT_CAPS" FM_ORCA_SUBMIT_WAIT='2;rm -rf x' \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 hello 3 0.01 0.01' "$ROOT" )
  assert_contains "$(orca_sends)" $'--wait-submit\x1f2\x1f--json' "a non-numeric window must fall back to the default"
  pass "fm_backend_orca_send_text_submit: the wait window defaults to 2 seconds, is tunable, and ignores a non-numeric value"
}

test_receipt_text_is_one_argument() {
  local text=$'--dash "dq" \'sq\' $(touch /nope)\nsecond line'
  orca_case rc-text
  rc_accepted req-1 > "$RESP/1.out"
  rc_started req-1 true > "$RESP/2.out"
  receipt_run term-123 "$text" 3
  [ "$OUT" = empty ] || fail "got '$OUT'"
  assert_contains "$(cat "$LOG")" $'--text\x1f'"$text"$'\x1f--enter\x1f--wait-submit\x1f2\x1f--json' "the send must carry the text as one argument"
  assert_contains "$(cat "$LOG")" $'--text\x1f'"$text"$'\x1f--enter\x1f--wait-submit\x1f2\x1f--retry-request\x1freq-1' "the replay must carry the same text as one argument"
  [ ! -e /nope ] || fail "the text was evaluated"
  pass "fm_backend_orca_send_text_submit: the text, with quotes, a leading dash, and a newline, is one argument on the send and the replay"
}

test_failed_status_read_selects_the_current_path() {
  orca_case rc-nocaps
  printf '%s\n' "$ACCEPT_OK" > "$RESP/1.out"
  printf '%s\n' "$ACCEPT_OK" > "$RESP/2.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/3.out"
  RECEIPT_NO_CAPS=1 receipt_run term-123 "hello captain" 3
  [ "$OUT" = empty ] || fail "got '$OUT'"
  assert_not_contains "$(cat "$LOG")" '--wait-submit' "no capability means no receipt options"
  assert_contains "$(orca_sends)" $'--text\x1fhello captain\x1f--json' "the literal send is unchanged"
  assert_contains "$(orca_sends)" $'--text\x1f\x1f--enter\x1f--json' "the Enter send is unchanged"
  orca_case rc-status-down
  printf '%s\n' "$ACCEPT_OK" > "$RESP/1.out"
  printf '%s\n' "$ACCEPT_OK" > "$RESP/2.out"
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/3.out"
  OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_RAW='' FM_ORCA_STATUS_EXIT=1 \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_send_text_submit term-123 "hello captain" 3 0.01 0.01' "$ROOT" )
  [ "$OUT" = empty ] || fail "an unreadable status must select the current path, got '$OUT'"
  assert_not_contains "$(cat "$LOG")" '--wait-submit' "an unreadable status means no receipt options"
  pass "fm_backend_orca_send_text_submit: without the capability, or when status cannot be read, the current send loop runs unchanged"
}

# Whole-script cases: bin/fm-send.sh against an Orca task record and the fake.
orca_fm_send_case() {  # <case> -> sets SEND_STATE SEND_NEUTRAL; the fake answers by verb
  local id=orcarcpt1
  orca_case "$1"
  SEND_ID=$id
  SEND_STATE="$CASE_DIR/state"; mkdir -p "$SEND_STATE"
  fm_write_meta "$SEND_STATE/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=term-io" "worktree=$CASE_DIR" "project=$CASE_DIR" "harness=claude" "kind=scout" "backend=orca"
  touch "$SEND_STATE/.last-watcher-beat"
  SEND_NEUTRAL=$(neutral_fm_root "$CASE_DIR/neutral")
  printf '%s\n' "$COMPOSER_EMPTY" > "$RESP/by-terminal-read.out"
}
orca_fm_send() {  # <text> -> sets SEND_OUT SEND_RC
  SEND_RC=0
  SEND_OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" FM_ORCA_STATUS_CAPS="$RECEIPT_CAPS" \
    FM_ROOT_OVERRIDE="$SEND_NEUTRAL" FM_HOME="$SEND_NEUTRAL" FM_STATE_OVERRIDE="$SEND_STATE" FM_SEND_SETTLE=0 FM_SEND_SLEEP=0.01 \
    "$ROOT/bin/fm-send.sh" "fm-$SEND_ID" "$1" 2>&1 ) || SEND_RC=$?
}

test_fm_send_typed_uses_the_receipt_on_orca() {
  orca_fm_send_case send-typed-receipt
  rc_started req-1 > "$RESP/by-terminal-send.out"
  orca_fm_send "/compact"
  [ "$SEND_RC" -eq 0 ] || fail "a typed send confirmed by a started receipt should exit 0, got $SEND_RC: $SEND_OUT"
  [ "$(orca_all_sends)" -eq 1 ] || fail "one receipt send expected, got $(orca_all_sends)"
  assert_contains "$(orca_sends)" $'--text\x1f/compact\x1f--enter\x1f--wait-submit\x1f2\x1f--json' "the typed text must ride the receipt send"
  [ "$(orca_enter_only_count)" -eq 0 ] || fail "no separate Enter is sent on the receipt path"
  pass "fm-send (typed): an Orca send that the runtime proves started exits 0 on one receipt send"
}

test_fm_send_doorbell_uses_the_receipt_on_orca() {
  orca_fm_send_case send-doorbell-receipt
  rc_started req-1 > "$RESP/by-terminal-send.out"
  orca_fm_send "please continue"
  [ "$SEND_RC" -eq 0 ] || fail "an ordinary steer should exit 0, got $SEND_RC: $SEND_OUT"
  [ -f "$SEND_STATE/$SEND_ID.inbox/001.msg" ] || fail "the steer must be recorded in the durable inbox"
  assert_contains "$(orca_sends)" $'--text\x1f: Firstmate instruction waiting:' "the doorbell must ride the receipt send"
  assert_contains "$(orca_sends)" $'--enter\x1f--wait-submit\x1f2' "the doorbell must request the receipt"
  assert_not_contains "$SEND_OUT" "doorbell" "a delivered doorbell must print no warning"
  pass "fm-send (doorbell): the Orca doorbell rides the receipt send and prints no warning"
}

test_fm_send_typed_names_a_gone_terminal() {
  orca_fm_send_case send-typed-gone
  rc_gone req-1 > "$RESP/by-terminal-send.out"
  printf '1\n' > "$RESP/by-terminal-send.exit"
  orca_fm_send "/compact"
  [ "$SEND_RC" -ne 0 ] || fail "a typed send to a gone terminal must fail"
  assert_contains "$SEND_OUT" "term-io" "the error must name the terminal"
  assert_contains "$SEND_OUT" "is gone" "the error must say the terminal is gone"
  assert_contains "$SEND_OUT" "nothing was delivered" "the error must say nothing was delivered"
  assert_not_contains "$SEND_OUT" "delivery unconfirmed" "a gone terminal is not an unconfirmed delivery"
  pass "fm-send (typed): a gone Orca terminal fails with an error that names the terminal and says nothing was delivered"
}

test_fm_send_typed_names_a_blocked_prompt() {
  orca_fm_send_case send-typed-blocked
  rc_blocked req-1 > "$RESP/by-terminal-send.out"
  printf '1\n' > "$RESP/by-terminal-send.exit"
  orca_fm_send "/compact"
  [ "$SEND_RC" -ne 0 ] || fail "a typed send to a parked prompt must fail"
  assert_contains "$SEND_OUT" "term-io" "the error must name the terminal"
  assert_contains "$SEND_OUT" "permission or trust prompt" "the error must name the blocked prompt"
  assert_contains "$SEND_OUT" "nothing was delivered" "the error must say nothing was delivered"
  assert_not_contains "$SEND_OUT" "is gone" "a parked prompt is not a gone terminal"
  assert_not_contains "$SEND_OUT" "delivery unconfirmed" "a refused send is not an unconfirmed delivery"
  [ "$(orca_all_sends)" -eq 1 ] || fail "a parked prompt gets one send and nothing more, got $(orca_all_sends)"
  pass "fm-send (typed): a parked Orca prompt fails with an error that names the prompt and says nothing was delivered"
}

test_fm_send_without_the_capability_is_unchanged() {
  orca_fm_send_case send-typed-nocaps
  printf '%s\n' "$ACCEPT_OK" > "$RESP/by-terminal-send.out"
  SEND_RC=0
  SEND_OUT=$( PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$SEND_NEUTRAL" FM_HOME="$SEND_NEUTRAL" FM_STATE_OVERRIDE="$SEND_STATE" FM_SEND_SETTLE=0 FM_SEND_SLEEP=0.01 \
    "$ROOT/bin/fm-send.sh" "fm-$SEND_ID" "/compact" 2>&1 ) || SEND_RC=$?
  [ "$SEND_RC" -eq 0 ] || fail "the current path should still deliver, got $SEND_RC: $SEND_OUT"
  assert_not_contains "$(cat "$LOG")" '--wait-submit' "no capability means no receipt options"
  assert_contains "$(orca_sends)" $'--text\x1f/compact\x1f--json' "the literal send is unchanged"
  assert_contains "$(orca_sends)" $'--text\x1f\x1f--enter\x1f--json' "the Enter send is unchanged"
  pass "fm-send (typed): without the receipt capability the Orca send is the current literal send and Enter"
}


# --- endpoint presence (specs/008-orca-endpoint-presence) --------------------
#
# Real `terminal show` answers recorded in the isolated lab (Orca 1.4.261):
# a live shell is connected and writable; an exited shell and a closed terminal
# are neither, with an exitCause; a handle the runtime never issued answers
# ok:false terminal_handle_stale and exits 1.

es_live() { printf '{"ok":true,"result":{"terminal":{"handle":"%s","connected":true,"writable":true,"agentWait":null,"executionHostId":"local"}}}\n' "${1:-term-es}"; }
es_exited() { printf '{"ok":true,"result":{"terminal":{"handle":"%s","connected":false,"writable":false,"exitCause":{"kind":"exited","exitCode":0},"executionHostId":"local"}}}\n' "${1:-term-es}"; }
es_closed() { printf '{"ok":true,"result":{"terminal":{"handle":"%s","connected":false,"writable":false,"exitCause":{"kind":"operator_close"},"executionHostId":"local"}}}\n' "${1:-term-es}"; }
ES_STALE='{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale","data":{"nextSteps":["Terminal handles belong to the Orca server that issued them."]}}}'

# es_answer <body> [exit]: the fake answers every `terminal show` with it. It
# also answers `terminal read` the way the real runtime does for the same
# terminal (ok:true with status running for a live one, ok:true with status
# exited for an exited or closed one - the answer that made the old presence
# read call a dead terminal present - and the stale error), so a presence read
# that still went through `terminal read` is told apart from one that did not.
es_answer() {
  local read_body
  rm -f "$RESP"/by-terminal-show.* "$RESP"/by-terminal-read.*
  printf '%s\n' "$1" > "$RESP/by-terminal-show.out"
  [ -z "${2:-}" ] || printf '%s\n' "$2" > "$RESP/by-terminal-show.exit"
  case "$1" in
    *'"connected":true'*) read_body='{"ok":true,"result":{"terminal":{"handle":"term-es","status":"running","tail":["idle prompt"]}}}' ;;
    *'"connected":false'*) read_body='{"ok":true,"result":{"terminal":{"handle":"term-es","status":"exited","tail":[]}}}' ;;
    *terminal_handle_stale*) read_body=$1 ;;
    *) read_body='' ;;
  esac
  [ -z "$read_body" ] || printf '%s\n' "$read_body" > "$RESP/by-terminal-read.out"
  [ "${2:-}" != 1 ] || [ -z "$read_body" ] || printf '1\n' > "$RESP/by-terminal-read.exit"
}
es_state() {  # <terminal> -> the adapter's endpoint verdict
  # shellcheck disable=SC2016  # the single quotes are deliberate: $0 and $1 belong to the inner bash
  env PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_endpoint_state "$1"' "$ROOT" "${1:-term-es}" 2>/dev/null
}
es_expect() {  # <label> <expected>
  local got
  got=$(es_state term-es)
  [ "$got" = "$2" ] || fail "endpoint state for $1: expected '$2', got '$got'"
}

test_endpoint_state_four_states() {
  orca_case endpoint-four
  es_answer "$(es_live)"; es_expect "a live terminal" present
  es_answer "$(es_exited)"; es_expect "an exited shell" missing
  es_answer "$(es_closed)"; es_expect "a closed terminal" missing
  es_answer "$ES_STALE" 1; es_expect "a handle the runtime does not know" missing
  es_answer "$(es_live)" 1; es_expect "a live answer carried with a failing exit status" present
  pass "fm_backend_orca_endpoint_state: live is present; exited, closed, and stale are missing"
}

test_endpoint_state_unreadable_matrix() {
  orca_case endpoint-unreadable
  es_answer '{"ok":true,"result":{"terminal":{"handle":"term-es","connected":true,"writable":false}}}'
  es_expect "connected but not writable" unreadable
  es_answer '{"ok":true,"result":{"terminal":{"handle":"term-es","connected":false,"writable":true}}}'
  es_expect "writable but not connected" unreadable
  es_answer "$(es_live term-other)"; es_expect "an answer about another handle" unreadable
  es_answer '{"ok":true,"result":{"terminal":{"handle":"term-es","connected":true,"writable":true,"status":"exited"}}}'
  es_expect "a live record contradicted by status exited" unreadable
  es_answer '{"ok":true,"result":{"terminal":{"handle":"term-es","connected":false,"writable":false,"status":"running"}}}'
  es_expect "a dead record contradicted by status running" unreadable
  es_answer '{"ok":false,"error":{"code":"runtime_error","message":"boom"}}' 1; es_expect "another error code" unreadable
  es_answer '{"ok":false}' 1; es_expect "an error with no code" unreadable
  es_answer '{"ok":true,"result":{}}'; es_expect "an answer with no terminal record" unreadable
  es_answer '{"ok":true,"result":{"terminal":{"handle":"term-es"}}}'; es_expect "a record with no connected or writable" unreadable
  es_answer '{"ok":true,"result":{"terminal":{"handle":"term-es","connected":"true","writable":"true"}}}'
  es_expect "string booleans" unreadable
  es_answer 'not json'; es_expect "invalid JSON" unreadable
  es_answer '' 1; es_expect "empty output and a failing CLI" unreadable
  pass "fm_backend_orca_endpoint_state: every other answer is unreadable, never missing"
}

test_endpoint_state_is_one_read_only_call() {
  local lines
  orca_case endpoint-one-call
  es_answer "$(es_live term-es)"
  es_state term-es >/dev/null
  lines=$(grep -a -c . "$LOG" || true)
  [ "$lines" -eq 1 ] || fail "an endpoint read should make exactly one orca call, made $lines: $(cat "$LOG")"
  assert_contains "$(cat "$LOG")" $'orca\x1fterminal\x1fshow\x1f--terminal\x1fterm-es\x1f--json' \
    "the endpoint read should be one explicit-terminal terminal show"
  pass "fm_backend_orca_endpoint_state: one read-only terminal show naming the terminal"
}

test_endpoint_state_without_the_cli_is_unreadable() {
  local home got
  orca_case endpoint-no-cli
  home="$CASE_DIR/home"; mkdir -p "$home"
  orca_free_path
  # shellcheck disable=SC2016  # the single quotes are deliberate: $0 and $1 belong to the inner bash
  got=$(env -u ORCA_CLI_BIN_DIR HOME="$home" PATH="$ORCA_FREE_PATH_CACHE" \
    bash -c '. "$0/bin/backends/orca.sh"; fm_backend_orca_endpoint_state term-es' "$ROOT" 2>/dev/null)
  [ "$got" = unreadable ] || fail "with no orca CLI the endpoint read should be unreadable, got '$got'"
  pass "fm_backend_orca_endpoint_state: no reachable orca CLI is unreadable, not missing"
}

test_target_exists_reads_the_four_endpoint_states() {
  local rc
  te() {  # -> rc of fm_backend_target_exists orca term-es
    # shellcheck disable=SC2016  # the single quotes are deliberate: $0 and $1 belong to the inner bash
    env PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
      bash -c '. "$0/bin/fm-backend.sh"; fm_backend_target_exists orca term-es fm-task' "$ROOT"
  }
  orca_case target-exists-states
  es_answer "$(es_live)"; rc=0; te || rc=$?
  [ "$rc" -eq 0 ] || fail "a live terminal should exist, got rc=$rc"
  es_answer "$(es_exited)"; rc=0; te || rc=$?
  [ "$rc" -ne 0 ] || fail "an exited shell must not read as present"
  es_answer "$(es_closed)"; rc=0; te || rc=$?
  [ "$rc" -ne 0 ] || fail "a closed terminal must not read as present"
  es_answer "$ES_STALE" 1; rc=0; te || rc=$?
  [ "$rc" -ne 0 ] || fail "a stale handle must not read as present"
  es_answer 'not json'; rc=0; te || rc=$?
  [ "$rc" -ne 0 ] || fail "an unreadable answer must not read as present"
  pass "fm_backend_target_exists: Orca presence needs a connected, writable terminal"
}

test_agent_state_missing_unverified_unreadable() {
  local got
  as() {  # <function> -> the backend verdict for term-es
    # shellcheck disable=SC2016  # the single quotes are deliberate: $0 and $1 belong to the inner bash
    env PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
      bash -c '. "$0/bin/fm-backend.sh"; "$1" orca term-es' "$ROOT" "$1" 2>/dev/null
  }
  orca_case agent-state-verdicts
  es_answer "$(es_exited)"
  got=$(as fm_backend_agent_state); [ "$got" = missing ] || fail "an exited Orca terminal should be missing, got '$got'"
  got=$(as fm_backend_agent_alive); [ "$got" = dead ] || fail "a missing Orca endpoint should fold to dead, got '$got'"
  es_answer "$ES_STALE" 1
  got=$(as fm_backend_agent_state); [ "$got" = missing ] || fail "a stale Orca handle should be missing, got '$got'"
  es_answer "$(es_closed)"
  got=$(as fm_backend_agent_state); [ "$got" = missing ] || fail "a closed Orca terminal should be missing, got '$got'"
  es_answer "$(es_live)"
  got=$(as fm_backend_agent_state); [ "$got" = unverified ] || fail "a live Orca terminal has no process classifier yet and should be unverified, got '$got'"
  got=$(as fm_backend_agent_alive); [ "$got" = unknown ] || fail "a live Orca terminal should fold to unknown, got '$got'"
  es_answer 'not json'
  got=$(as fm_backend_agent_state); [ "$got" = unreadable ] || fail "an unreadable Orca answer should be unreadable, got '$got'"
  got=$(as fm_backend_agent_alive); [ "$got" = unknown ] || fail "an unreadable Orca answer should fold to unknown, got '$got'"
  pass "fm_backend_agent_state: Orca reports missing, unverified, and unreadable"
}

test_a_missing_orca_endpoint_does_not_unlock_the_control_plane() {
  local got
  orca_case control-stays-refused
  es_answer "$(es_exited)"
  # shellcheck disable=SC2016  # the single quotes are deliberate: $0 and $1 belong to the inner bash
  got=$(env PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    bash -c '. "$0/bin/fm-backend.sh"; . "$0/bin/fm-control-lib.sh"; if fm_control_backend_state_verified orca; then echo verified; else echo refused; fi; fm_backend_agent_state orca term-es' "$ROOT" 2>/dev/null | tr '\n' ' ')
  [ "$got" = "refused missing" ] || fail "a missing Orca endpoint must leave the stop-proving verbs refused, got '$got'"
  pass "fm-control-lib: a missing Orca endpoint verdict leaves exit and relaunch refused"
}

# crew state: the no-run fallback reads Orca presence through target_exists.
orca_crew_state_case() {  # <case> <terminal>  -> sets CS_STATE CS_NEUTRAL
  local wt id=orcacspz$RANDOM
  CS_ID=$id
  wt="$TMP_ROOT/$1-wt"
  fm_git_init_commit "$wt"
  CS_STATE="$TMP_ROOT/$1-state"; mkdir -p "$CS_STATE"
  fm_write_meta "$CS_STATE/$id.meta" \
    "window=fm-$id" "endpoint_task_id=$id" "terminal=$2" "worktree=$wt" "project=$wt" "harness=claude" "kind=scout" "backend=orca"
  touch "$CS_STATE/.last-watcher-beat"
  orca_case "$1"
}
orca_crew_state() {
  PATH="$FB:$PATH" FM_ORCA_LOG="$LOG" FM_ORCA_RESPONSES="$RESP" \
    FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$CS_STATE" "$ROOT/bin/fm-crew-state.sh" "$CS_ID" 2>&1
}

test_crew_state_reports_a_dead_orca_endpoint_gone() {
  local out
  orca_crew_state_case crew-state-dead term-es
  # es_answer also gives the successful tail read that Orca returns for an exited terminal.
  es_answer "$(es_exited)"
  out=$(orca_crew_state)
  assert_contains "$out" "state: unknown" "crew-state should not claim a state for an exited Orca terminal"
  assert_contains "$out" "backend target gone: term-es" "crew-state should report an exited Orca terminal as gone"
  es_answer "$(es_closed)"
  assert_contains "$(orca_crew_state)" "backend target gone: term-es" "crew-state should report a closed Orca terminal as gone"
  es_answer "$ES_STALE" 1
  assert_contains "$(orca_crew_state)" "backend target gone: term-es" "crew-state should report a stale Orca handle as gone"
  es_answer "$(es_live)"
  out=$(orca_crew_state)
  assert_not_contains "$out" "backend target gone" "a live Orca terminal must not be reported gone"
  pass "fm-crew-state: an exited, closed, or stale Orca terminal is gone; a live one is not"
}

test_crew_state_does_not_call_an_unreadable_orca_endpoint_gone() {
  local out
  orca_crew_state_case crew-state-unreadable term-es
  es_answer 'not json'
  printf '{"ok":true,"result":{"terminal":{"handle":"term-es","status":"running","tail":["x"]}}}\n' > "$RESP/by-terminal-read.out"
  out=$(orca_crew_state)
  assert_contains "$out" "state: unknown" "crew-state should stay unknown for an unreadable Orca answer"
  assert_contains "$out" "orca endpoint state: unreadable" "crew-state should name the unreadable endpoint state"
  assert_not_contains "$out" "backend target gone" "an unreadable Orca answer is not proof the terminal is gone"
  pass "fm-crew-state: an unreadable Orca answer is unreachable, never gone"
}


test_dispatcher_sources_orca_and_routes_primitives
test_json_get_ignores_undocumented_terminal_id_shapes
test_worktree_and_terminal_helpers_parse_json
test_json_get_reads_repo_kind
test_repo_ensure_refuses_a_folder_repo
test_repo_ensure_accepts_git_and_kindless_repos
test_repo_ensure_unregistered_path_probes_git_before_add
test_spawn_refuses_a_folder_kind_repo_before_any_mutation
test_tool_check_resolution_order
test_tool_check_skips_unusable_candidates
test_tool_check_refusal_is_actionable
test_worktree_create_uses_a_cli_found_off_path
test_spawn_finds_the_orca_cli_under_orca_cli_bin_dir
test_worktree_create_removes_worktree_when_path_missing
test_spawn_preserves_orca_metadata_when_pathless_worktree_cleanup_fails
test_spawn_writes_orca_metadata_and_launches_harness
test_spawn_refuses_orca_secondmate_before_home_mutation
test_spawn_refuses_orca_when_runtime_not_ready
test_spawn_refuses_orca_nonisolated_worktree
test_spawn_removes_orca_worktree_when_terminal_create_fails
test_spawn_preserves_orca_metadata_when_abort_cleanup_fails
test_spawn_releases_orca_resources_when_metadata_write_fails
test_peek_send_and_crew_state_route_through_orca_meta
test_peek_and_crew_state_fail_closed_on_orca_error_json
test_target_exists_rejects_orca_error_json
test_scout_teardown_removes_orca_worktree_via_helper
test_scout_teardown_refuses_orca_id_path_mismatch
test_teardown_removes_orca_worktree_when_path_missing
test_teardown_preserves_metadata_when_orca_remove_error_json
test_scout_teardown_refuses_orca_missing_report_when_path_missing
test_ship_teardown_refuses_orca_missing_worktree_path
test_ship_teardown_removes_orca_worktree_when_id_path_matches
test_ship_teardown_completes_when_orca_keeps_the_branch
test_ship_teardown_refuses_orca_unresolvable_worktree_id
test_ship_teardown_refuses_orca_id_path_mismatch
test_teardown_refuses_orca_missing_worktree_id
test_teardown_refuses_orca_worktree_without_terminal_handle
test_secondmate_force_teardown_removes_orca_child_via_orca
test_secondmate_force_teardown_refuses_orca_child_id_path_mismatch
test_secondmate_force_teardown_refuses_partial_orca_child
test_has_capability_reads_the_status_list
test_receipt_class_matrix
test_receipt_started_is_empty
test_receipt_accepted_is_replayed_by_id
test_receipt_exhausted_with_empty_composer_is_empty
test_receipt_exhausted_with_pending_composer_retries_enter_only
test_receipt_exhausted_with_unreadable_composer_is_pending
test_receipt_unsupported_falls_back_to_the_composer
test_receipt_gone_terminal_is_terminal_gone
test_receipt_other_failures_stay_send_failed
test_receipt_blocked_prompt_is_prompt_blocked
test_receipt_blocked_replay_is_prompt_blocked
test_receipt_hookless_accepted_is_replayed_by_id
test_receipt_wait_window_is_tunable
test_receipt_text_is_one_argument
test_failed_status_read_selects_the_current_path
test_fm_send_typed_uses_the_receipt_on_orca
test_fm_send_doorbell_uses_the_receipt_on_orca
test_fm_send_typed_names_a_gone_terminal
test_fm_send_typed_names_a_blocked_prompt
test_fm_send_without_the_capability_is_unchanged
test_endpoint_state_four_states
test_endpoint_state_unreadable_matrix
test_endpoint_state_is_one_read_only_call
test_endpoint_state_without_the_cli_is_unreadable
test_target_exists_reads_the_four_endpoint_states
test_agent_state_missing_unverified_unreadable
test_a_missing_orca_endpoint_does_not_unlock_the_control_plane
test_crew_state_reports_a_dead_orca_endpoint_gone
test_crew_state_does_not_call_an_unreadable_orca_endpoint_gone
