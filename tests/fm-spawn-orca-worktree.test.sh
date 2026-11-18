#!/usr/bin/env bash
# tests/fm-spawn-orca-worktree.test.sh - regression coverage for the
# backend=orca carve-outs in bin/fm-spawn.sh's worktree-entry proof (#4991,
# bacadc4).
#
# spawn_current_path (bin/fm-spawn.sh) has no `orca` case, because Orca hands
# back a terminal that is already bound to the worktree it just created -
# there is no shared pane whose cwd firstmate must poll for. Without an
# explicit skip, spawn_assert_agent_worktree's post-launch proof would poll
# spawn_current_path in a loop, read nothing but empty output every time, and
# hard-refuse EVERY Orca launch once its 20-read deadline elapsed. This test
# spawns a real (fake-Orca-backed) task and asserts it succeeds and records
# the worktree Orca actually created, proving the skip does not just avoid an
# error but lets a genuine Orca launch complete.
#
# The matching relaunch-side carve-out at the `[ "$RELAUNCH" -eq 1 ] &&
# [ "$BACKEND" = orca ]` branch is guarded by an earlier, unconditional gate:
# fm_control_backend_state_verified (bin/fm-control-lib.sh) only recognizes
# tmux and herdr as having a recovery-grade agent-state classifier, so any
# `--relaunch` on backend=orca is refused before that branch can ever run.
# The second test below pins that refusal so a future change that starts
# routing orca through the classifier does not silently reach the untested
# branch without also covering it.
#
# The launch-env cases (specs/005-orca-fleet-plumbing) spawn on the fake Orca,
# then EXECUTE the launch the terminal received under a synthetic Orca terminal
# environment, with the harness replaced by a probe that prints the environment
# it was started with, so they assert what an agent would have received.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-orca-worktree)

# make_orca_fakebin <dir>: a fake `orca` CLI that performs a REAL `git
# worktree add` for `worktree create` (so spawn_worktree_isolated's checks are
# exercised against a genuine, isolated worktree) and answers every other
# lifecycle call (status/repo/terminal/send) with the minimal JSON shape
# bin/backends/orca.sh's node-based parsers accept.
make_orca_fakebin() {
  local dir=$1 fb
  fb=$(fm_fakebin "$dir")
  cat > "$fb/orca" <<'SH'
#!/usr/bin/env bash
set -u
DIR="${FM_TEST_ORCA_DIR:?}"
printf '%s\n' "$*" >> "$DIR/orca.log"
case "$1 $2" in
  "status --json")
    printf '{"ok":true,"result":{"runtime":{"reachable":true,"state":"ready"}}}\n'
    exit 0
    ;;
  "repo show")
    exit 1
    ;;
  "repo add")
    printf '{"ok":true,"result":{"repo":{"id":"repo1"}}}\n'
    exit 0
    ;;
  "worktree create")
    name=
    prev=
    for a in "$@"; do
      [ "$prev" = --name ] && name=$a
      prev=$a
    done
    wt="$DIR/orca-worktrees/$name"
    mkdir -p "$DIR/orca-worktrees"
    git -C "$DIR/project" worktree add --quiet -b "orca-$name" "$wt" >&2 || exit 1
    printf '{"ok":true,"result":{"worktree":{"id":"wt-%s","path":"%s"}}}\n' "$name" "$wt"
    exit 0
    ;;
  "terminal create")
    printf '{"ok":true,"result":{"terminal":{"handle":"term-1"}}}\n'
    exit 0
    ;;
  "terminal send")
    printf '{"ok":true}\n'
    exit 0
    ;;
esac
exit 0
SH
  chmod +x "$fb/orca"
  printf '%s\n' "$fb"
}

test_orca_fresh_spawn_enters_the_worktree_it_created() {
  local case_dir home id=orca-fresh-a1 fb out status wt_recorded
  case_dir="$TMP_ROOT/fresh"
  home="$case_dir/home"
  mkdir -p "$home/data" "$home/projects" "$home/state" "$home/config"
  touch "$home/state/.last-watcher-beat"
  printf 'codex\n' > "$home/config/crew-harness"
  printf 'manual\n' > "$home/config/backlog-backend"
  fm_git_init_commit "$case_dir/project"
  mkdir -p "$home/data/$id"
  cat > "$home/data/$id/brief.md" <<EOF
# Task
## Captain's intent
Exercise an Orca-backed spawn for $id.

## Firstmate spec
Confirm the launch enters the worktree Orca created for it.
EOF
  fb=$(make_orca_fakebin "$case_dir")

  out=$(FM_ROOT_OVERRIDE='' FM_HOME="$home" HOME="$case_dir/user-home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_TEST_ORCA_DIR="$case_dir" PATH="$fb:$PATH" \
    "$SPAWN" "$id" "$case_dir/project" --mode no-mistakes --yolo off --backend orca 2>&1)
  status=$?

  expect_code 0 "$status" "an Orca-backed spawn should succeed"$'\n'"$out"
  assert_contains "$out" "spawned $id" "spawn did not report success"$'\n'"$out"
  wt_recorded=$(grep '^worktree=' "$home/state/$id.meta" | cut -d= -f2-)
  [ -n "$wt_recorded" ] || fail "meta did not record a worktree"
  [ -d "$wt_recorded" ] || fail "the recorded worktree '$wt_recorded' does not exist"
  [ "$(cd "$wt_recorded" && git rev-parse --show-toplevel)" = "$(cd "$wt_recorded" && pwd -P)" ] \
    || fail "the recorded worktree is not the isolated worktree Orca created"
  pass "an Orca-backed fresh spawn enters the worktree Orca created for it, instead of hard-refusing on the post-launch proof"
}

test_orca_relaunch_is_refused_before_the_worktree_carveout_could_run() {
  local case_dir home proj wt id=orca-relaunch-a2 out status
  case_dir="$TMP_ROOT/relaunch"
  home="$case_dir/home"
  proj="$case_dir/proj"
  wt="$case_dir/wt"
  mkdir -p "$home/data" "$home/projects" "$home/state" "$home/config"
  touch "$home/state/.last-watcher-beat"
  printf 'manual\n' > "$home/config/backlog-backend"
  fm_git_worktree "$proj" "$wt" "task-$id"
  mkdir -p "$home/data/$id"
  cat > "$home/data/$id/brief.md" <<EOF
# Task
## Captain's intent
Exercise a relaunch attempt against a recorded Orca task.

## Firstmate spec
Confirm the relaunch is refused before any worktree re-entry logic runs.
EOF
  {
    echo "window=fm-$id"
    echo "endpoint_task_id=$id"
    echo "worktree=$wt"
    echo "project=$proj"
    echo "harness=codex"
    echo "kind=ship"
    echo "mode=no-mistakes"
    echo "yolo=off"
    echo "backend=orca"
    echo "orca_worktree_id=wt-1::$wt"
    echo "terminal=term-1"
  } > "$home/state/$id.meta"

  out=$(FM_ROOT_OVERRIDE='' FM_HOME="$home" HOME="$case_dir/user-home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 \
    "$SPAWN" "$id" --relaunch 2>&1)
  status=$?

  expect_code 1 "$status" "a relaunch against a recorded Orca task should refuse"$'\n'"$out"
  assert_contains "$out" "no recovery-grade agent-state classifier" \
    "the refusal should name the missing classifier, proving relaunch never reaches the worktree carve-out"
  pass "a relaunch against an Orca-backed task is refused before the RELAUNCH+orca worktree carve-out could run"
}

# Every ORCA_ name an Orca 1.4.261 terminal exports (specs/005-orca-fleet-plumbing
# research.md). The allowlist floor must hand each one through when the terminal
# carries it.
ORCA_FLOOR_NAMES="ORCA_AGENT_HOOK_ENDPOINT ORCA_AGENT_HOOK_ENV ORCA_AGENT_HOOK_OPENCODE_TUI \
ORCA_AGENT_HOOK_PORT ORCA_AGENT_HOOK_TOKEN ORCA_AGENT_HOOK_TRANSPORT ORCA_AGENT_HOOK_VERSION \
ORCA_AGENT_PANE ORCA_APP_VERSION ORCA_CLAUDE_AGENT_VIEW_PLUGIN_DIR ORCA_CLAUDE_CONFIG_DIR \
ORCA_CLAUDE_PROFILE_POINTER ORCA_CLI_BIN_DIR ORCA_CLI_COMMAND ORCA_HISTFILE ORCA_IMAGE_PROTOCOL \
ORCA_OMP_FRESH_CONFIG ORCA_OMP_SOURCE_AGENT_DIR ORCA_OMP_STATUS_EXTENSION ORCA_OPENCODE_AGENT \
ORCA_PANE_KEY ORCA_PI_SOURCE_AGENT_DIR ORCA_REMOTE_VIEWER_CLIPBOARD ORCA_RUNTIME_SOURCE_ID \
ORCA_RUNTIME_SOURCE_INCARNATION ORCA_RUNTIME_SOURCE_PROFILE_PATH ORCA_TAB_ID ORCA_TERMINAL_HANDLE \
ORCA_USER_DATA ORCA_USER_DATA_PATH ORCA_VERSION ORCA_WORKSPACE_ID ORCA_WORKTREE_ID"
# Names the synthetic terminal deliberately leaves unset, to prove an unset floor
# name stays unset rather than becoming empty.
ORCA_UNSET_NAMES="ORCA_VERSION ORCA_TAB_ID"

# orca_launch_case <name> <allowlist: on|off>: spawn a codex ship on the fake
# Orca and leave the staged launch file path in ORCA_LAUNCH_FILE and the case
# directory in ORCA_CASE_DIR. The harness is a probe printing its environment.
orca_launch_case() {
  local name=$1 allowlist=$2 case_dir home id fb out status
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  id="$name-a1"
  mkdir -p "$home/data" "$home/projects" "$home/state" "$home/config" "$case_dir/user-home"
  touch "$home/state/.last-watcher-beat"
  printf 'codex\n' > "$home/config/crew-harness"
  printf 'manual\n' > "$home/config/backlog-backend"
  if [ "$allowlist" = on ]; then : > "$home/config/launch-env-allowlist"; fi
  fm_git_init_commit "$case_dir/project"
  mkdir -p "$home/data/$id"
  cat > "$home/data/$id/brief.md" <<BRIEF
# Task
## Captain's intent
Exercise the Orca launch environment for $id.

## Firstmate spec
Confirm the allowlist floor keeps Orca's variables.
BRIEF
  fb=$(make_orca_fakebin "$case_dir")
  printf '#!/bin/sh\nenv\n' > "$fb/codex"
  chmod +x "$fb/codex"
  out=$(FM_ROOT_OVERRIDE='' FM_HOME="$home" HOME="$case_dir/user-home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_TEST_ORCA_DIR="$case_dir" PATH="$fb:$PATH" \
    "$SPAWN" "$id" "$case_dir/project" --mode no-mistakes --yolo off --backend orca 2>&1)
  status=$?
  expect_code 0 "$status" "the Orca spawn for $name should succeed"$'\n'"$out"
  ORCA_CASE_DIR=$case_dir
  ORCA_FAKEBIN=$fb
  ORCA_LAUNCH_FILE=$(grep -o '/tmp/fm-[^ "'"'"']*/launch\.[^ "'"'"']*\.sh' "$case_dir/orca.log" | tail -1)
  if [ -z "$ORCA_LAUNCH_FILE" ] || [ ! -f "$ORCA_LAUNCH_FILE" ]; then
    fail "$name: the launch file the terminal was told to source was not found in the fake Orca's log"
  fi
}

# orca_terminal_env <extra NAME=value>...: the harness's environment after the
# staged launch runs in a synthetic Orca terminal carrying every floor name
# except ORCA_UNSET_NAMES, plus the extra assignments.
orca_terminal_env() {
  local args=() name
  for name in $ORCA_FLOOR_NAMES; do
    case " $ORCA_UNSET_NAMES " in *" $name "*) continue ;; esac
    args+=("$name=value-of-$name")
  done
  env -i HOME="$ORCA_CASE_DIR/pane-home" PATH="$ORCA_FAKEBIN:/usr/bin:/bin" TERM=xterm \
    "${args[@]}" "$@" /bin/sh -c ". '$ORCA_LAUNCH_FILE'"
}

test_orca_allowlisted_launch_keeps_the_orca_floor() {
  local seen name
  orca_launch_case orca-floor on
  seen=$(orca_terminal_env ORCA_UNLISTED_X=1 UNRELATED_X=2) || fail "the emitted Orca launch failed to run"
  for name in $ORCA_FLOOR_NAMES; do
    case " $ORCA_UNSET_NAMES " in
      *" $name "*)
        if printf '%s\n' "$seen" | grep -q "^$name="; then
          fail "$name was unset in the terminal and must stay unset, not appear in the agent environment"
        fi
        ;;
      *)
        printf '%s\n' "$seen" | grep -Fxq "$name=value-of-$name" \
          || fail "an allowlisted Orca launch dropped $name from the agent environment"
        ;;
    esac
  done
  if printf '%s\n' "$seen" | grep -q '^ORCA_UNLISTED_X='; then
    fail "an ORCA_ name outside the observed Orca set must not survive the cleared environment"
  fi
  if printf '%s\n' "$seen" | grep -q '^UNRELATED_X='; then
    fail "an unrelated name must not survive the cleared environment"
  fi
  pass "an allowlisted Orca launch keeps every observed ORCA_ variable and still clears the rest"
}

test_orca_launch_without_an_allowlist_is_unfiltered() {
  local seen
  orca_launch_case orca-no-allowlist off
  seen=$(orca_terminal_env ORCA_UNLISTED_X=1 UNRELATED_X=2) || fail "the emitted Orca launch failed to run"
  printf '%s\n' "$seen" | grep -Fxq 'ORCA_TERMINAL_HANDLE=value-of-ORCA_TERMINAL_HANDLE' \
    || fail "an unfiltered Orca launch should keep ORCA_TERMINAL_HANDLE"
  printf '%s\n' "$seen" | grep -Fxq 'ORCA_UNLISTED_X=1' \
    || fail "with no allowlist the agent inherits the whole terminal environment"
  printf '%s\n' "$seen" | grep -Fxq 'UNRELATED_X=2' \
    || fail "with no allowlist the agent inherits the whole terminal environment"
  pass "an Orca launch with no allowlist file still inherits the terminal environment unchanged"
}

test_orca_fresh_spawn_enters_the_worktree_it_created
test_orca_relaunch_is_refused_before_the_worktree_carveout_could_run
test_orca_allowlisted_launch_keeps_the_orca_floor
test_orca_launch_without_an_allowlist_is_unfiltered

echo "# all fm-spawn-orca-worktree tests passed"
