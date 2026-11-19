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
    # Like the real runtime: --branch names the branch exactly, --base-branch
    # is its start point, no --branch gets an Orca-made name, and
    # FM_TEST_ORCA_SUFFIX=1 renames a "taken" branch with a numeric suffix.
    name=
    branch=
    base=
    prev=
    for a in "$@"; do
      [ "$prev" = --name ] && name=$a
      [ "$prev" = --branch ] && branch=$a
      [ "$prev" = --base-branch ] && base=$a
      prev=$a
    done
    wt="$DIR/orca-worktrees/$name"
    mkdir -p "$DIR/orca-worktrees"
    [ -n "$branch" ] || branch="orca-$name"
    [ -z "${FM_TEST_ORCA_SUFFIX:-}" ] || branch="$branch-2"
    git -C "$DIR/project" worktree add --quiet -b "$branch" "$wt" ${base:+"$base"} >&2 || exit 1
    printf '{"ok":true,"result":{"worktree":{"id":"wt-%s","path":"%s","branch":"refs/heads/%s"}}}\n' "$name" "$wt" "$branch"
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

# orca_ship_case <name> <ship|scout> [<extra fm-spawn args>...]: spawn on the
# fake Orca and leave ORCA_CASE_DIR, ORCA_CASE_HOME, ORCA_CASE_ID, ORCA_STATUS,
# ORCA_OUT behind. ORCA_BRIEF_EXTRA is appended to the brief, and
# ORCA_WITH_ORIGIN=1 gives the project an origin that carries release/1.
orca_ship_case() {
  local name=$1 kind=$2 case_dir home id fb args=()
  shift 2
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  id="$name-a1"
  mkdir -p "$home/data" "$home/projects" "$home/state" "$home/config" "$case_dir/user-home"
  touch "$home/state/.last-watcher-beat"
  printf 'codex\n' > "$home/config/crew-harness"
  printf 'manual\n' > "$home/config/backlog-backend"
  fm_git_init_commit "$case_dir/project"
  if [ "${ORCA_WITH_ORIGIN:-0}" = 1 ]; then
    fm_git_add_origin "$case_dir/project" "$case_dir/project.origin.git"
    git -C "$case_dir/project" branch release/1
    git -C "$case_dir/project" push -q origin release/1
    if [ "${ORCA_DROP_BASE_REFS:-0}" = 1 ]; then
      git -C "$case_dir/project" branch -D release/1 >/dev/null
      git -C "$case_dir/project" update-ref -d refs/remotes/origin/release/1
    fi
  fi
  mkdir -p "$home/data/$id"
  cat > "$home/data/$id/brief.md" <<BRIEF
# Task
## Captain's intent
Exercise the Orca branch at create for $id.

## Firstmate spec
Confirm the branch is named when the worktree is created.
${ORCA_BRIEF_EXTRA:-}
BRIEF
  fb=$(make_orca_fakebin "$case_dir")
  if [ "$kind" = scout ]; then
    args=(--scout)
  else
    args=(--mode no-mistakes --yolo off)
  fi
  ORCA_OUT=$(FM_ROOT_OVERRIDE='' FM_HOME="$home" HOME="$case_dir/user-home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_TEST_ORCA_DIR="$case_dir" FM_TEST_ORCA_SUFFIX="${ORCA_SUFFIX:-}" PATH="$fb:$PATH" \
    "$SPAWN" "$id" "$case_dir/project" "${args[@]}" --backend orca "$@" 2>&1)
  ORCA_STATUS=$?
  ORCA_CASE_DIR=$case_dir
  ORCA_CASE_HOME=$home
  ORCA_CASE_ID=$id
}

# orca_create_args: the argument line of the fake Orca's one worktree create call.
orca_create_args() {
  grep -a '^worktree create ' "$ORCA_CASE_DIR/orca.log"
}

test_orca_ship_spawn_names_the_branch_at_create() {
  local wt branch
  orca_ship_case orca-branch-default ship
  expect_code 0 "$ORCA_STATUS" "an Orca ship spawn should succeed"$'\n'"$ORCA_OUT"
  assert_contains "$(orca_create_args)" "--branch fm/$ORCA_CASE_ID " "a default-prefix ship should create on fm/<id>"
  wt=$(sed -n 's/^worktree=//p' "$ORCA_CASE_HOME/state/$ORCA_CASE_ID.meta")
  branch=$(git -C "$wt" symbolic-ref --short HEAD)
  [ "$branch" = "fm/$ORCA_CASE_ID" ] || fail "the worktree should be on fm/$ORCA_CASE_ID, got '$branch'"
  assert_grep "branch=fm/$ORCA_CASE_ID" "$ORCA_CASE_HOME/state/$ORCA_CASE_ID.meta" "meta should record the same ship branch"

  ORCA_BRIEF_EXTRA='Ship branch: team/orca-branch-prefix-a1' orca_ship_case orca-branch-prefix ship --branch-prefix team/
  expect_code 0 "$ORCA_STATUS" "an Orca ship spawn with a prefix should succeed"$'\n'"$ORCA_OUT"
  assert_contains "$(orca_create_args)" "--branch team/$ORCA_CASE_ID " "an explicit prefix should name team/<id>"
  wt=$(sed -n 's/^worktree=//p' "$ORCA_CASE_HOME/state/$ORCA_CASE_ID.meta")
  [ "$(git -C "$wt" symbolic-ref --short HEAD)" = "team/$ORCA_CASE_ID" ] || fail "the worktree should be on team/$ORCA_CASE_ID"

  ORCA_BRIEF_EXTRA='Ship branch: orca-branch-bare-a1' orca_ship_case orca-branch-bare ship --branch-prefix ''
  expect_code 0 "$ORCA_STATUS" "an Orca ship spawn with an empty prefix should succeed"$'\n'"$ORCA_OUT"
  assert_contains "$(orca_create_args)" "--branch $ORCA_CASE_ID " "an empty prefix should name the bare id"
  pass "fm-spawn.sh backend=orca: a ship's worktree is created on <prefix><id> and meta records it"
}

test_orca_ship_spawn_passes_the_base_branch_only_when_set() {
  local wt
  orca_ship_case orca-base-unset ship
  expect_code 0 "$ORCA_STATUS" "an Orca ship spawn should succeed"$'\n'"$ORCA_OUT"
  assert_not_contains "$(orca_create_args)" "--base-branch" "no base branch should mean no --base-branch"

  # The task base is origin's branch, and Orca hands the ref to git as given, so
  # the spawn fetches it and passes origin/<base>: a base that exists only on
  # origin (no local branch, no remote-tracking ref yet) must still work.
  ORCA_DROP_BASE_REFS=1 ORCA_WITH_ORIGIN=1 ORCA_BRIEF_EXTRA=$'\n# Setup\nYou are in a disposable git worktree of project, at a detached HEAD on a clean copy of its base branch.\nBase branch: release/1' \
    orca_ship_case orca-base-set ship --base-branch release/1
  expect_code 0 "$ORCA_STATUS" "an Orca ship spawn with an origin-only base branch should succeed"$'\n'"$ORCA_OUT"
  assert_contains "$(orca_create_args)" "--base-branch origin/release/1 " "the task base branch should reach worktree create as origin/<base>"
  wt=$(sed -n 's/^worktree=//p' "$ORCA_CASE_HOME/state/$ORCA_CASE_ID.meta")
  [ "$(git -C "$wt" symbolic-ref --short HEAD)" = "fm/$ORCA_CASE_ID" ] || fail "the base-branch worktree should still be on the ship branch"
  pass "fm-spawn.sh backend=orca: the task base branch is fetched and passed to worktree create as origin/<base>, only when one is set"
}

test_orca_spawn_refuses_an_unfetchable_base_branch() {
  ORCA_WITH_ORIGIN=1 ORCA_BRIEF_EXTRA=$'\n# Setup\nYou are in a disposable git worktree of project, at a detached HEAD on a clean copy of its base branch.\nBase branch: no-such-base' \
    orca_ship_case orca-base-missing ship --base-branch no-such-base
  [ "$ORCA_STATUS" -ne 0 ] || fail "a base branch origin does not have should be refused"$'\n'"$ORCA_OUT"
  assert_contains "$ORCA_OUT" "no-such-base" "the refusal should name the base branch"
  assert_not_contains "$(cat "$ORCA_CASE_DIR/orca.log" 2>/dev/null)" "worktree create" "nothing should be created for an unfetchable base"
  assert_absent "$ORCA_CASE_HOME/state/$ORCA_CASE_ID.meta" "a refused spawn should leave no task record"
  pass "fm-spawn.sh backend=orca: a base branch origin cannot supply is refused before any worktree is created"
}

test_orca_scout_spawn_passes_no_branch() {
  orca_ship_case orca-scout-nobranch scout
  expect_code 0 "$ORCA_STATUS" "an Orca scout spawn should succeed"$'\n'"$ORCA_OUT"
  assert_not_contains "$(orca_create_args)" "--branch" "a scout makes no branch, so create must not name one"
  assert_not_contains "$(orca_create_args)" "--base-branch" "a scout with no base must not pass --base-branch"
  pass "fm-spawn.sh backend=orca: a scout's worktree is created with no --branch"
}

test_orca_spawn_refuses_a_renamed_branch() {
  ORCA_SUFFIX=1 orca_ship_case orca-branch-renamed ship
  [ "$ORCA_STATUS" -ne 0 ] || fail "a worktree on another branch than requested should be refused"$'\n'"$ORCA_OUT"
  assert_contains "$ORCA_OUT" "fm/$ORCA_CASE_ID" "the refusal should name the requested branch"
  assert_contains "$ORCA_OUT" "fm/$ORCA_CASE_ID-2" "the refusal should name the branch Orca used"
  assert_contains "$(cat "$ORCA_CASE_DIR/orca.log")" "worktree rm --worktree id:wt-fm-$ORCA_CASE_ID" \
    "the worktree Orca made should be released"
  assert_absent "$ORCA_CASE_HOME/state/$ORCA_CASE_ID.meta" "a refused spawn should leave no task record"
  pass "fm-spawn.sh backend=orca: a worktree Orca put on another branch is refused and released"
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
test_orca_ship_spawn_names_the_branch_at_create
test_orca_ship_spawn_passes_the_base_branch_only_when_set
test_orca_spawn_refuses_an_unfetchable_base_branch
test_orca_scout_spawn_passes_no_branch
test_orca_spawn_refuses_a_renamed_branch

echo "# all fm-spawn-orca-worktree tests passed"
