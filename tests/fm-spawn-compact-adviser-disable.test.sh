#!/usr/bin/env bash
# tests/fm-spawn-compact-adviser-disable.test.sh - every agent this fleet
# launches must start with COMPACT_ADVISER_DISABLE=1 in its environment, with its
# steering inbox in FM_TASK_INBOX, and with CHROME_DEVTOOLS_AXI_SESSION set to its
# task id so each worker has its own browser session (the "per-worker browser
# session" section; fm_browser_session_name in bin/fm-pr-lib.sh owns which ids
# name one).
#
# The assertions never read bin/fm-spawn.sh's source. They drive the real spawn
# against a fake pane and a real isolated git worktree, then EXECUTE the launch
# command the pane actually received, under a synthetic pane environment, with
# the harness binary replaced by a probe that prints the environment it was
# started with. What the probe prints is what a real agent would have received.
#
# The remote second-mate route never reaches this path; its coverage lives in
# tests/fm-spawn-compact-adviser-disable-remote.test.sh.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

CONTROL="$ROOT/bin/fm-control.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-compact-adviser)

# A synthetic pane value the launch must override rather than inherit: the
# switch is a floor, so a pane that already carries the wrong value still has to
# start its agent with 1.
CONTRARY=0

# make_case <name> <harness> <id>...
# Echoes "<case-dir>|<home>|<project>|<worktree>|<fakebin>|<launch-log>|<pane-log>".
make_case() {
  local name=$1 harness=$2 case_dir home proj wt fakebin launchlog panelog id
  shift 2
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  launchlog="$case_dir/launch.log"
  panelog="$case_dir/pane.log"
  fakebin=$(fm_test_make_spawn_fakebin "$case_dir/fake")
  fm_test_spawn_home "$home" "$harness"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  for id in "$@"; do
    fm_test_spawn_brief "$home" "$id"
  done
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$launchlog|$panelog"
}

read_case() {
  IFS='|' read -r CASE_DIR HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR LAUNCH_LOG PANE_LOG <<EOF
$1
EOF
}

run_case_spawn() {
  : > "$LAUNCH_LOG"
  : > "$PANE_LOG"
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" FM_FAKE_PANE_LOG="$PANE_LOG" \
    fm_test_run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$@"
}

# Replace the harness binary with a probe that reports the single environment
# fact under test, so executing the emitted launch answers "what would the agent
# have seen" rather than "what does the command text look like".
install_env_probe() {  # <fakebin> <harness> [variable]
  cat > "$1/$2" <<SH
#!/bin/sh
printf '%s\n' "\${${3:-COMPACT_ADVISER_DISABLE}-unset}"
SH
  chmod +x "$1/$2"
}

# Run the emitted launch command in a synthetic pane shell. The pane carries the
# CONTRARY value, so a launch that merely forwarded the ambient environment
# would be caught here rather than reported as a pass.
#   emitted_launch_env <fakebin> <launch-log> <pane-log>
emitted_launch_env() {
  local fakebin=$1 launchlog=$2 panelog=$3 launch preamble
  launch=$(cat "$launchlog")
  # The pane exports run before the launch command in the real pane shell, so
  # replay them here in the same order: the filtered launch environment retains
  # what the pane holds, and dropping them would test a pane that never existed.
  preamble=$(grep '^export ' "$panelog")
  env -i HOME="$TMP_ROOT/pane-home" PATH="$fakebin:$PATH" TERM=xterm \
    TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
    /bin/sh -c "$preamble
$launch"
}

pane_export_lines() { grep -c '^export COMPACT_ADVISER_DISABLE=1$' "$1" || true; }

assert_pane_export_precedes_launch() {  # <pane-log> <label>
  local panelog=$1 label=$2
  [ "$(pane_export_lines "$panelog")" = 1 ] \
    || fail "$label: the pane shell should receive exactly one compact-adviser export, got $(pane_export_lines "$panelog")"
  # Ordering: the export must ride the same pre-launch site as GOTMPDIR, which
  # is what makes it set before the agent process starts.
  local gotmp switch
  gotmp=$(grep -n '^export GOTMPDIR=' "$panelog" | tail -1 | cut -d: -f1)
  switch=$(grep -n '^export COMPACT_ADVISER_DISABLE=1$' "$panelog" | tail -1 | cut -d: -f1)
  [ -n "$gotmp" ] && [ -n "$switch" ] \
    || fail "$label: the pane log is missing the pre-launch exports"
  [ "$switch" -gt "$gotmp" ] \
    || fail "$label: the compact-adviser export must ride the GOTMPDIR pre-launch site (gotmp=$gotmp switch=$switch)"
}

test_ship_allowlist_absent() {
  local rec out status seen
  rec=$(make_case ship-open codex ship-open-a1)
  read_case "$rec"
  out=$(run_case_spawn ship-open-a1 "$PROJ_DIR" --mode no-mistakes --yolo off)
  status=$?
  expect_code 0 "$status" "ship spawn without an allowlist should succeed: $out"
  assert_pane_export_precedes_launch "$PANE_LOG" "ship, allowlist absent"
  install_env_probe "$FAKEBIN_DIR" codex
  seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "ship, allowlist absent: the emitted launch failed to run"
  assert_equals 1 "$seen" \
    "a ship worker launched with the ambient environment must start with the compact adviser disabled"
  pass "ship launch with no allowlist starts its agent with the compact-adviser switch on"
}

test_ship_allowlist_enabled() {
  local rec out status seen launch
  rec=$(make_case ship-filtered codex ship-filtered-a1)
  read_case "$rec"
  # An empty file is the strictest opt-in: the launch keeps Firstmate's own
  # operational floor and nothing else, so it is where a floor either holds or
  # is lost.
  : > "$HOME_DIR/config/launch-env-allowlist"
  out=$(run_case_spawn ship-filtered-a1 "$PROJ_DIR" --mode no-mistakes --yolo off)
  status=$?
  expect_code 0 "$status" "ship spawn under an allowlist should succeed: $out"
  assert_pane_export_precedes_launch "$PANE_LOG" "ship, allowlist enabled"
  launch=$(cat "$LAUNCH_LOG")
  assert_contains "$launch" '/usr/bin/env -i' \
    "an enabled allowlist should launch under a cleared environment"
  install_env_probe "$FAKEBIN_DIR" codex
  seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "ship, allowlist enabled: the emitted launch failed to run"
  assert_equals 1 "$seen" \
    "a ship worker launched under the cleared allowlisted environment must still start with the compact adviser disabled"
  pass "ship launch under an enabled allowlist keeps the compact-adviser switch through the cleared environment"
}

# The floor must not depend on the pane export having landed: a pane whose
# export was lost still has to launch its agent with the switch on. Replaying
# the launch alone, with a contrary ambient value, is that case.
test_launch_command_carries_the_switch_without_the_pane_export() {
  local setting rec out status seen launch
  for setting in absent enabled; do
    rec=$(make_case "ship-nopane-$setting" codex "ship-nopane-$setting-a1")
    read_case "$rec"
    [ "$setting" = absent ] || : > "$HOME_DIR/config/launch-env-allowlist"
    out=$(run_case_spawn "ship-nopane-$setting-a1" "$PROJ_DIR" --mode no-mistakes --yolo off)
    status=$?
    expect_code 0 "$status" "allowlist=$setting spawn should succeed: $out"
    install_env_probe "$FAKEBIN_DIR" codex
    launch=$(cat "$LAUNCH_LOG")
    seen=$(env -i HOME="$TMP_ROOT/pane-home" PATH="$FAKEBIN_DIR:$PATH" TERM=xterm \
      TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
      /bin/sh -c "$launch") \
      || fail "allowlist=$setting: the emitted launch failed to run without the pane exports"
    assert_equals 1 "$seen" \
      "allowlist=$setting: the launch command alone must set the compact-adviser switch, overriding a contrary pane value"
  done
  pass "the launch command sets the switch on its own, whichever allowlist posture is in force"
}

test_secondmate_launch() {
  local setting rec sm out status seen
  for setting in absent enabled; do
    rec=$(make_case "secondmate-$setting" codex "sm-$setting")
    read_case "$rec"
    [ "$setting" = absent ] || : > "$HOME_DIR/config/launch-env-allowlist"
    sm="$CASE_DIR/secondmate-home"
    mkdir -p "$sm/bin" "$sm/data"
    printf '# Firstmate\n' > "$sm/AGENTS.md"
    printf '%s\n' "sm-$setting" > "$sm/.fm-secondmate-home"
    printf 'charter for sm-%s\n' "$setting" > "$sm/data/charter.md"
    printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
    git -C "$sm" init -q -b main
    out=$(run_case_spawn "sm-$setting" "$sm" --secondmate)
    status=$?
    expect_code 0 "$status" "secondmate spawn with allowlist=$setting should succeed: $out"
    assert_pane_export_precedes_launch "$PANE_LOG" "secondmate, allowlist $setting"
    install_env_probe "$FAKEBIN_DIR" codex
    seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
      || fail "secondmate, allowlist $setting: the emitted launch failed to run"
    assert_equals 1 "$seen" \
      "a secondmate launched with allowlist=$setting must start with the compact adviser disabled"
  done
  pass "a secondmate launch carries the compact-adviser switch in both allowlist postures"
}

# The steering doorbell names "$FM_TASK_INBOX" rather than a path, so every
# launch must hand its agent the absolute path of the task's own inbox. For a
# secondmate that inbox lives in the launching home's state, not its own. The
# cleared allowlist environment is where an ambient forward would be lost.
test_launch_exports_task_inbox() {
  local kind rec id sm out status seen want
  for kind in ship secondmate; do
    id="inbox-$kind-a1"
    rec=$(make_case "inbox-$kind" codex "$id")
    read_case "$rec"
    : > "$HOME_DIR/config/launch-env-allowlist"
    if [ "$kind" = ship ]; then
      out=$(run_case_spawn "$id" "$PROJ_DIR" --mode no-mistakes --yolo off)
    else
      sm="$CASE_DIR/secondmate-home"
      mkdir -p "$sm/bin" "$sm/data"
      printf '# Firstmate\n' > "$sm/AGENTS.md"
      printf '%s\n' "$id" > "$sm/.fm-secondmate-home"
      printf 'charter for %s\n' "$id" > "$sm/data/charter.md"
      printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
      git -C "$sm" init -q -b main
      out=$(run_case_spawn "$id" "$sm" --secondmate)
    fi
    status=$?
    expect_code 0 "$status" "$kind spawn should succeed: $out"
    install_env_probe "$FAKEBIN_DIR" codex FM_TASK_INBOX
    seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
      || fail "$kind: the emitted launch failed to run"
    want="$(cd "$HOME_DIR/state" && pwd -P)/$id.inbox"
    assert_equals "$want" "$seen" \
      "a $kind agent must start with FM_TASK_INBOX set to its absolute steering inbox"
  done
  pass "ship and secondmate launches export their absolute steering inbox as FM_TASK_INBOX"
}

# --- per-worker browser session ---------------------------------------------
#
# Every local launch must start its agent with CHROME_DEVTOOLS_AXI_SESSION set
# to the task id, so one worker's browser bridge is never shared with another.
# The probe prints what the agent would see; a contrary value in the synthetic
# pane is where an ambient forward, rather than an explicit export, is caught.
SESSION_VAR=CHROME_DEVTOOLS_AXI_SESSION

# launched_session <fakebin> <launch-log> <pane-log> [pane-session] [replay]
# Runs the emitted launch in a synthetic pane and prints the session the agent
# sees. A non-empty pane-session is placed in the pane's own environment. With
# replay=launch-only the pane-side exports are not replayed.
launched_session() {
  local fakebin=$1 launchlog=$2 panelog=$3 pane_session=${4:-} replay=${5:-} launch preamble=
  launch=$(cat "$launchlog")
  [ "$replay" = launch-only ] || preamble=$(grep '^export ' "$panelog")
  install_env_probe "$fakebin" codex "$SESSION_VAR"
  env -i HOME="$TMP_ROOT/pane-home" PATH="$fakebin:$PATH" TERM=xterm \
    TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
    ${pane_session:+CHROME_DEVTOOLS_AXI_SESSION="$pane_session"} \
    /bin/sh -c "$preamble
$launch"
}

# spawn_session_case <name> <id> <kind> [allowlist]
# Spawns <id> as ship, scout, or secondmate in a fresh case and leaves the case
# variables set for launched_session. An allowlist of "enabled" opts the home in
# with an empty file, the strictest posture.
spawn_session_case() {
  local name=$1 id=$2 kind=$3 allowlist=${4:-absent} rec sm out status
  rec=$(make_case "$name" codex "$id")
  read_case "$rec"
  [ "$allowlist" = absent ] || : > "$HOME_DIR/config/launch-env-allowlist"
  case "$kind" in
    ship) out=$(run_case_spawn "$id" "$PROJ_DIR" --mode no-mistakes --yolo off) ;;
    scout) out=$(run_case_spawn "$id" "$PROJ_DIR" --scout) ;;
    secondmate)
      sm="$CASE_DIR/secondmate-home"
      mkdir -p "$sm/bin" "$sm/data"
      printf '# Firstmate\n' > "$sm/AGENTS.md"
      printf '%s\n' "$id" > "$sm/.fm-secondmate-home"
      printf 'charter for %s\n' "$id" > "$sm/data/charter.md"
      printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
      git -C "$sm" init -q -b main
      out=$(run_case_spawn "$id" "$sm" --secondmate)
      ;;
  esac
  status=$?
  expect_code 0 "$status" "$kind spawn of $id should succeed: $out"
}

test_ship_launch_exports_its_task_id_as_the_session() {  # A1
  local seen
  spawn_session_case session-ship browser-ship-a1 ship
  seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "ship: the emitted launch failed to run"
  assert_equals browser-ship-a1 "$seen" \
    "a ship worker must start with CHROME_DEVTOOLS_AXI_SESSION set to its task id"
  pass "a ship launch gives its agent its own browser session named by the task id"
}

test_scout_launch_exports_its_task_id_as_the_session() {  # A2
  local seen
  spawn_session_case session-scout browser-scout-a1 scout
  seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "scout: the emitted launch failed to run"
  assert_equals browser-scout-a1 "$seen" \
    "a scout worker must start with CHROME_DEVTOOLS_AXI_SESSION set to its task id"
  pass "a scout launch gives its agent its own browser session named by the task id"
}

test_secondmate_launch_exports_its_id_as_the_session() {  # A3
  local seen
  spawn_session_case session-secondmate browser-sm-a1 secondmate
  seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "secondmate: the emitted launch failed to run"
  assert_equals browser-sm-a1 "$seen" \
    "a local secondmate must start with CHROME_DEVTOOLS_AXI_SESSION set to its own id"
  pass "a local secondmate launch gives its agent a browser session named by its id"
}

test_launch_overrides_a_session_already_in_the_pane() {  # A4
  local seen
  spawn_session_case session-contrary browser-contrary-a1 ship
  seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG" other-session) \
    || fail "contrary pane: the emitted launch failed to run"
  assert_equals browser-contrary-a1 "$seen" \
    "a session already in the pane must lose to the task id"
  pass "the task-id session overrides a browser session the pane already carried"
}

test_two_workers_get_different_sessions() {  # A6
  local first second
  spawn_session_case session-distinct-one browser-one-a1 ship
  first=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "first worker: the emitted launch failed to run"
  spawn_session_case session-distinct-two browser-two-a1 ship
  second=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "second worker: the emitted launch failed to run"
  assert_not_equals "$first" "$second" "two workers must not share a browser session"
  assert_equals browser-one-a1 "$first" "the first worker keeps its own session"
  assert_equals browser-two-a1 "$second" "the second worker keeps its own session"
  pass "two workers with different task ids launch with different browser sessions"
}

test_session_survives_an_empty_allowlist() {  # A7
  local seen launch
  spawn_session_case session-allowlist browser-allow-a1 ship enabled
  launch=$(cat "$LAUNCH_LOG")
  assert_contains "$launch" '/usr/bin/env -i' \
    "an enabled allowlist should launch under a cleared environment"
  seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG" other-session) \
    || fail "allowlisted ship: the emitted launch failed to run"
  assert_equals browser-allow-a1 "$seen" \
    "the cleared allowlisted environment must still give the agent its task-id session"
  pass "a launch under an empty allowlist still gives its agent the task-id browser session"
}

test_session_does_not_depend_on_the_pane_exports() {  # A8
  local setting seen
  for setting in absent enabled; do
    spawn_session_case "session-nopane-$setting" "browser-nopane-$setting-a1" ship "$setting"
    seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG" other-session launch-only) \
      || fail "allowlist=$setting: the emitted launch failed to run without the pane exports"
    assert_equals "browser-nopane-$setting-a1" "$seen" \
      "allowlist=$setting: the launch command alone must set the task-id session"
  done
  pass "the launch command sets the task-id browser session on its own in both allowlist postures"
}

test_default_named_task_exports_no_session() {  # A14
  local seen launch
  spawn_session_case session-default default ship
  launch=$(cat "$LAUNCH_LOG")
  assert_not_contains "$launch" 'CHROME_DEVTOOLS_AXI_SESSION' \
    "a task named default must not claim the machine-wide default session in its launch"
  seen=$(launched_session "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "default-named task: the emitted launch failed to run"
  assert_equals unset "$seen" \
    "a task named default must start with no Firstmate-exported browser session"
  pass "a task whose id is the default session name exports no browser session of its own"
}

# --- relaunch ---------------------------------------------------------------
#
# bin/fm-control.sh relaunch stops the agent and rebuilds the launch through
# bin/fm-spawn.sh --relaunch, so this drives the operator-facing verb rather
# than the rebuild alone. The stub below models just enough pane lifecycle for
# that transaction: the harness exit command leaves a bare shell behind, and the
# launch literal starts the harness again.
make_relaunch_stub() {  # <case-dir>
  local fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/tmux" <<'SH'
#!/usr/bin/env bash
set -u
D=$FM_FAKE_DIR
case "${1:-}" in
  send-keys)
    shift
    literal=0
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) shift 2 ;;
        -l) literal=1; shift ;;
        *) break ;;
      esac
    done
    payload=${1:-}
    if [ "$literal" = 1 ]; then
      case "$payload" in
        ". '"*"'")
          staged=${payload#". '"}
          staged=${staged%"'"}
          [ ! -f "$staged" ] || payload=$(cat "$staged")
          ;;
      esac
      printf '%s\n' "$payload" >> "$D/literal"
      case "$payload" in
        /exit|/quit) printf 'zsh' > "$D/command" ;;
        *'encode launch-brief'*) printf 'codex' > "$D/command" ;;
      esac
    else
      printf '%s\n' "$payload" >> "$D/keys"
    fi
    exit 0 ;;
  display-message)
    for a in "$@"; do
      case "$a" in
        *cursor_y*) printf '1\n'; exit 0 ;;
        *pane_current_command*) cat "$D/command"; printf '\n'; exit 0 ;;
        *pane_current_path*) cat "$D/cwd"; printf '\n'; exit 0 ;;
      esac
    done
    printf 'fakepane\n'; exit 0 ;;
  capture-pane) printf '╭────╮\n│    │\n╰────╯\n'; exit 0 ;;
  list-windows) [ -f "$D/windows" ] && cat "$D/windows"; exit 0 ;;
esac
exit 0
SH
  chmod +x "$fb/tmux"
  cat > "$fb/sleep" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fb/sleep"
}

# relaunch_case <allowlist-setting> <tag>: builds a recorded ship task, drives
# `fm-control.sh relaunch` against the stub above, and leaves the replacement
# launch in RELAUNCH_LAUNCH, the pane-side exports in RELAUNCH_KEYS, and the
# case's directories in RELAUNCH_DIR and RELAUNCH_HOME_DIR.
relaunch_case() {
  local setting=$1 tag=$2 dir home proj wt id out status
  id="relaunch-$setting-a1"
  dir="$TMP_ROOT/relaunch-$tag-$setting"
  home="$dir/home"
  proj="$dir/proj"
  wt="$dir/wt"
  mkdir -p "$home/state" "$home/data" "$home/config" "$home/projects" "$dir/fake"
  touch "$home/state/.last-watcher-beat"
  [ "$setting" = absent ] || : > "$home/config/launch-env-allowlist"
  make_relaunch_stub "$dir"
  fm_git_worktree "$proj" "$wt" "wt-relaunch-$tag-$setting"
  fm_test_spawn_brief "$home" "$id"
  : > "$dir/fake/literal"
  : > "$dir/fake/keys"
  printf 'codex' > "$dir/fake/command"
  printf '%s\n' "fm-$id" > "$dir/fake/windows"
  printf '%s' "$wt" > "$dir/fake/cwd"
  {
    echo "window=fmses:fm-$id"
    echo "endpoint_task_id=$id"
    echo "worktree=$wt"
    echo "project=$proj"
    echo "harness=codex"
    echo "kind=ship"
    echo "mode=no-mistakes"
    echo "yolo=off"
    echo "tasktmp=$dir/tasktmp"
    echo "model=default"
    echo "effort=default"
  } > "$home/state/$id.meta"

  mkdir -p "$dir/user-home"
  out=$(env PATH="$dir/fakebin:$PATH" FM_HOME="$home" FM_FAKE_DIR="$dir/fake" \
    HOME="$dir/user-home" CLAUDE_CONFIG_DIR='' FM_SPAWN_NO_GUARD=1 \
    FM_CONTROL_POLL=0.01 FM_CONTROL_EXIT_WAIT=0.05 FM_CONTROL_LAUNCH_WAIT=0.05 \
    "$CONTROL" "$id" relaunch --note 'replacement continues the same task' 2>&1)
  status=$?
  expect_code 0 "$status" "relaunch with allowlist=$setting should succeed: $out"
  RELAUNCH_DIR=$dir
  RELAUNCH_KEYS=$(grep '^export ' "$dir/fake/keys")
  RELAUNCH_LAUNCH=$(grep 'encode launch-brief' "$dir/fake/literal" | tail -1)
  [ -n "$RELAUNCH_LAUNCH" ] || fail "relaunch with allowlist=$setting sent no replacement launch command"
}

test_relaunch_rebuilds_the_switch() {
  local setting seen
  for setting in absent enabled; do
    relaunch_case "$setting" switch
    grep -qx 'export COMPACT_ADVISER_DISABLE=1' "$RELAUNCH_DIR/fake/keys" \
      || fail "relaunch with allowlist=$setting did not re-export the compact-adviser switch into the pane"
    install_env_probe "$RELAUNCH_DIR/fakebin" codex
    seen=$(env -i HOME="$RELAUNCH_DIR/user-home" PATH="$RELAUNCH_DIR/fakebin:$PATH" TERM=xterm \
      TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
      /bin/sh -c "$RELAUNCH_KEYS
$RELAUNCH_LAUNCH") \
      || fail "relaunch with allowlist=$setting: the replacement launch failed to run"
    assert_equals 1 "$seen" \
      "a relaunched agent with allowlist=$setting must start with the compact adviser disabled, exactly as a fresh spawn does"
  done
  pass "relaunch rebuilds the compact-adviser switch for the replacement agent in both allowlist postures"
}

test_relaunch_keeps_the_task_id_session() {  # A5
  local setting seen
  for setting in absent enabled; do
    relaunch_case "$setting" session
    install_env_probe "$RELAUNCH_DIR/fakebin" codex "$SESSION_VAR"
    seen=$(env -i HOME="$RELAUNCH_DIR/user-home" PATH="$RELAUNCH_DIR/fakebin:$PATH" TERM=xterm \
      TMUX=synthetic-pane CHROME_DEVTOOLS_AXI_SESSION=other-session \
      /bin/sh -c "$RELAUNCH_KEYS
$RELAUNCH_LAUNCH") \
      || fail "relaunch with allowlist=$setting: the replacement launch failed to run"
    assert_equals "relaunch-$setting-a1" "$seen" \
      "a relaunched agent with allowlist=$setting must start with the same task-id browser session"
  done
  pass "a relaunch gives the replacement agent the same task-id browser session in both allowlist postures"
}

# A command-prefix assignment only covers the first simple command. A raw
# compound launch such as `cd <dir> && <probe>` must still start the probe with
# the switch on, so this drives that escape hatch and executes the pane's
# launch under a contrary ambient value.
test_raw_compound_launch_command_carries_the_switch() {
  local rec out status seen launch probe_dir
  rec=$(make_case raw-compound claude raw-compound-a1)
  read_case "$rec"
  printf '%s\n' '{"rules":[{"when":"current events","use":{"harness":"grok","model":"grok-4","effort":"high"}}],"default":{"harness":"codex","model":"gpt-5","effort":"medium"}}' \
    > "$HOME_DIR/config/crew-dispatch.json"

  probe_dir="$CASE_DIR/agent-cwd"
  mkdir -p "$probe_dir"
  cat > "$probe_dir/probe" <<'SH'
#!/bin/sh
printf '%s\n' "${COMPACT_ADVISER_DISABLE-unset}"
SH
  chmod +x "$probe_dir/probe"

  out=$(run_case_spawn raw-compound-a1 "$PROJ_DIR" --mode no-mistakes --yolo off \
    "cd $probe_dir && ./probe")
  status=$?
  expect_code 0 "$status" "raw compound launch spawn should succeed: $out"
  launch=$(cat "$LAUNCH_LOG")
  [ -n "$launch" ] || fail "raw compound launch spawn sent no launch command"
  seen=$(env -i HOME="$TMP_ROOT/pane-home" PATH="$FAKEBIN_DIR:$PATH" TERM=xterm \
    TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
    /bin/sh -c "$launch") \
    || fail "raw compound launch: the emitted launch failed to run"
  assert_equals 1 "$seen" \
    "a raw compound launch must start its agent with the compact adviser disabled, even after cd"
  pass "a compound raw launch-command still starts its agent with the compact-adviser switch on"
}

# --- browser session name ---------------------------------------------------
#
# fm_browser_session_name is the one rule that says whether a task id names its
# own chrome-devtools-axi session. Launch and cleanup both call it, so these
# cases pin the rule directly: it prints the id and succeeds, or prints nothing
# and fails.
PR_LIB="$ROOT/bin/fm-pr-lib.sh"

# session_name_of <id>: sets SESSION_NAME_OUT and SESSION_NAME_STATUS.
session_name_of() {
  SESSION_NAME_OUT=$(bash -c '. "$1"; fm_browser_session_name "$2"' _ "$PR_LIB" "$1" 2>/dev/null)
  SESSION_NAME_STATUS=$?
}

assert_names_a_session() {  # <id> <label>
  session_name_of "$1"
  assert_equals "$1" "$SESSION_NAME_OUT" "$2: the id itself should be the session name"
  expect_code 0 "$SESSION_NAME_STATUS" "$2: the helper should accept the id"
}

assert_names_no_session() {  # <id> <label>
  session_name_of "$1"
  assert_equals "" "$SESSION_NAME_OUT" "$2: a refused id must print nothing"
  expect_code 1 "$SESSION_NAME_STATUS" "$2: the helper should refuse the id"
}

test_session_name_accepts_a_task_id() {  # U1
  assert_names_a_session fix-a1 "an ordinary task id"
  pass "a creation-valid task id names its own browser session unchanged"
}

test_session_name_refuses_the_default_session() {  # U5
  assert_names_no_session default "the default session name"
  pass "the id default names no per-task session"
}

test_session_name_accepts_dots_underscores_and_hyphens() {  # U2
  assert_names_a_session a.b_c-9 "an id with dot, underscore, and hyphen"
  pass "dots, underscores, and hyphens inside a task id still name a session"
}

test_session_name_accepts_a_64_character_id() {  # U3
  local id
  id=$(printf 'a%.0s' $(seq 1 64))
  assert_names_a_session "$id" "a 64-character id"
  pass "a task id of exactly 64 characters names a session"
}

test_session_name_refuses_a_65_character_id() {  # U4
  local id
  id=$(printf 'a%.0s' $(seq 1 65))
  assert_names_no_session "$id" "a 65-character id"
  pass "a task id of 65 characters names no session"
}

test_session_name_accepts_ids_that_extend_default() {  # U6
  assert_names_a_session default-2 "an id extending default"
  assert_names_a_session my-default "an id ending in default"
  pass "an id that merely contains the word default still names its own session"
}

test_session_name_refuses_an_empty_id() {  # U7
  assert_names_no_session "" "an empty id"
  pass "an empty task id names no session"
}

test_session_name_refuses_a_leading_dot() {  # U8
  assert_names_no_session .hidden "a leading-dot id"
  assert_names_no_session .. "an all-dots id"
  pass "a task id with a leading dot names no session"
}

test_session_name_refuses_characters_the_tool_rejects() {  # U9
  assert_names_no_session "has space" "an id with a space"
  assert_names_no_session 'a/b' "an id with a slash"
  assert_names_no_session 'a;b' "an id with a shell metacharacter"
  pass "a task id with a character outside the tool's session-name set names no session"
}

test_session_name_accepts_a_task_id
test_session_name_refuses_the_default_session
test_session_name_accepts_dots_underscores_and_hyphens
test_session_name_accepts_a_64_character_id
test_session_name_refuses_a_65_character_id
test_session_name_accepts_ids_that_extend_default
test_session_name_refuses_an_empty_id
test_session_name_refuses_a_leading_dot
test_session_name_refuses_characters_the_tool_rejects
test_ship_launch_exports_its_task_id_as_the_session
test_scout_launch_exports_its_task_id_as_the_session
test_secondmate_launch_exports_its_id_as_the_session
test_launch_overrides_a_session_already_in_the_pane
test_two_workers_get_different_sessions
test_session_survives_an_empty_allowlist
test_session_does_not_depend_on_the_pane_exports
test_default_named_task_exports_no_session
test_ship_allowlist_absent
test_ship_allowlist_enabled
test_launch_command_carries_the_switch_without_the_pane_export
test_secondmate_launch
test_launch_exports_task_inbox
test_relaunch_rebuilds_the_switch
test_relaunch_keeps_the_task_id_session
test_raw_compound_launch_command_carries_the_switch
