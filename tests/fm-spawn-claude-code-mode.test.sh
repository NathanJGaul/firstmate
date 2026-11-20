#!/usr/bin/env bash
# Behavior tests for the Code Mode pilot launch knob (config/claude-code-mode,
# bin/fm-claude-code-mode-lib.sh, bin/fm-spawn.sh).
#
# Each case drives the real fm-spawn.sh through the shared fake tmux, which
# records the launch command, then runs that captured command in a synthetic pane
# the way the destination shell would, with a fake claude that records whether
# CLAUDE_CODE_EXPERIMENTAL_CODE_MODE reached it. Assertions read the launch line
# and the worker's observed environment, never the script source.
# tests/fm-claude-codemode-live-e2e.test.sh proves the same against the real
# interactive Claude Code.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

TMP_ROOT=$(fm_test_tmproot fm-spawn-claude-code-mode)
unset LAVISH_AXI_HOST ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_EXPERIMENTAL_CODE_MODE

VAR=CLAUDE_CODE_EXPERIMENTAL_CODE_MODE
UNSET_FORM="-u GEMINI_CLI -u $VAR CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false"
SET_FORM="-u GEMINI_CLI $VAR=1 CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false"

# new_case <name> [harness]: an isolated firstmate home, project, and worktree
# with a fake claude that records the Code Mode variable it was launched with.
# Its auth status answers from the selected root's stored login, like the real
# runner, so a worker account pin can be exercised.
new_case() {
  CASE="$TMP_ROOT/$1"
  HOME_DIR="$CASE/home"
  PROJ="$CASE/project"
  WT="$CASE/wt"
  FAKEBIN=$(fm_test_make_spawn_fakebin "$CASE/fake")
  cat > "$FAKEBIN/claude" <<SH
#!/usr/bin/env bash
if [ "\${1:-}" = auth ] && [ "\${2:-}" = status ]; then
  [ -f "\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/.credentials.json" ]
  exit
fi
printf '%s\n' "\${$VAR-unset}" > '$CASE/claude-env'
SH
  chmod +x "$FAKEBIN/claude"
  fm_test_spawn_home "$HOME_DIR" "${2:-claude}"
  fm_git_worktree "$PROJ" "$WT" "wt-$1"
  mkdir -p "$HOME_DIR/user-home"
  : > "$CASE/launch.log"
  rm -f "$CASE/claude-env"
}

# store_accepts <dir> [json]: the Claude config store a worker would read.
store_accepts() {
  local body=${2-}
  [ -n "$body" ] || body='{"codeModeCaveatsAcceptedV1":true}'
  mkdir -p "$1"
  printf '%s\n' "$body" > "$1/.claude.json"
}

# spawn <kind: ship|scout> <id> [fm-spawn args...]; output in OUT, status in RC.
spawn() {
  local kind=$1 id=$2 extra=()
  shift 2
  fm_test_spawn_brief "$HOME_DIR" "$id"
  : > "$CASE/launch.log"
  if [ "$kind" = ship ]; then
    extra=(--mode no-mistakes --yolo off)
  else
    extra=(--scout)
  fi
  OUT=$(FM_FAKE_LAUNCH_LOG="$CASE/launch.log" fm_test_run_spawn "$HOME_DIR" "$WT" "$FAKEBIN" "$id" "$PROJ" "${extra[@]}" "$@")
  RC=$?
  LAUNCH=$(cat "$CASE/launch.log")
}

# pane [VAR=val ...]: run the captured launch the way the pane shell would and
# print what the fake claude saw for the Code Mode variable.
pane() {
  rm -f "$CASE/claude-env"
  fm_eval_launch "$LAUNCH" "$WT" "$FAKEBIN" "$@" >/dev/null 2>&1 || true
  [ -f "$CASE/claude-env" ] || fail "the launch never reached the fake claude: $LAUNCH"
  cat "$CASE/claude-env"
}

skip_lines() {  # count of Code Mode skip notes in OUT
  printf '%s\n' "$OUT" | grep -c 'Code Mode' || true
}

test_absent_knob_unsets_the_variable_for_scouts_and_ships() {
  local kind
  for kind in scout ship; do
    new_case "absent-$kind"
    store_accepts "$HOME_DIR/user-home"
    spawn "$kind" "cm-absent-$kind"
    expect_code 0 "$RC" "claude $kind spawn without the knob should succeed"$'\n'"$OUT"
    assert_contains "$LAUNCH" "$UNSET_FORM" "$kind launch must unset the Code Mode variable when the knob is absent"
    assert_not_contains "$LAUNCH" "$VAR=1" "$kind launch must not assign the variable when the knob is absent"
    [ "$(skip_lines)" = 0 ] || fail "an absent knob requested nothing, so nothing should be reported skipped: $OUT"
    [ "$(pane "$VAR=1")" = unset ] || fail "a stray $VAR in the invoking environment reached a $kind worker"
  done
  pass "an absent config/claude-code-mode unsets the variable for scouts and ships, whatever the environment holds"
}

test_scouts_knob_enables_only_scouts_with_recorded_acceptance() {
  new_case scouts-on
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  store_accepts "$HOME_DIR/user-home"
  spawn scout cm-scout-on
  expect_code 0 "$RC" "a scout spawn under the scouts knob should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "$SET_FORM" "the scout launch line must carry the assignment"
  assert_not_contains "$LAUNCH" "-u $VAR" "an enabled scout launch must not also unset the variable"
  [ "$(skip_lines)" = 0 ] || fail "an enabled scout launch must not report a skip: $OUT"
  [ "$(pane)" = 1 ] || fail "the scout worker did not receive $VAR=1 from the launch line"

  new_case scouts-ship
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  store_accepts "$HOME_DIR/user-home"
  spawn ship cm-ship-off
  expect_code 0 "$RC" "a ship spawn under the scouts knob should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "$UNSET_FORM" "the ship launch must keep the unset form under scouts"
  assert_not_contains "$LAUNCH" "$VAR=1" "a ship launch must never carry the assignment"
  [ "$(pane "$VAR=1")" = unset ] || fail "a ship worker saw $VAR under the scouts knob"
  pass "the scouts knob enables Code Mode for scouts only, and ships stay explicitly off"
}

test_scouts_knob_never_reaches_a_secondmate() {
  local sm id=cm-sm-off
  new_case scouts-secondmate
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  store_accepts "$HOME_DIR/user-home"
  sm="$CASE/secondmate-home"
  mkdir -p "$sm/bin" "$sm/data"
  printf '# Firstmate\n' > "$sm/AGENTS.md"
  printf '%s\n' "$id" > "$sm/.fm-secondmate-home"
  printf 'charter for %s\n' "$id" > "$sm/data/charter.md"
  printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
  git -C "$sm" init -q -b main
  : > "$CASE/launch.log"
  OUT=$(FM_FAKE_LAUNCH_LOG="$CASE/launch.log" fm_test_run_spawn "$HOME_DIR" "$WT" "$FAKEBIN" "$id" "$sm" --secondmate)
  RC=$?
  LAUNCH=$(cat "$CASE/launch.log")
  expect_code 0 "$RC" "a claude secondmate spawn under the scouts knob should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "$UNSET_FORM" "a secondmate launch must unset the Code Mode variable"
  assert_not_contains "$LAUNCH" "$VAR=1" "a secondmate launch must never carry the assignment"
  [ "$(pane "$VAR=1")" = unset ] || fail "a secondmate saw $VAR"
  pass "a Claude secondmate is launched with Code Mode explicitly off under the scouts knob"
}

test_launch_env_allowlist_does_not_decide() {
  new_case allow-scout
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  printf 'FM_TEST_UNRELATED\n' > "$HOME_DIR/config/launch-env-allowlist"
  store_accepts "$HOME_DIR/user-home"
  spawn scout cm-allow-scout
  expect_code 0 "$RC" "a scout spawn with an allowlist should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "/usr/bin/env -i" "the allowlist wrapper must be in force for this case"
  [ "$(pane)" = 1 ] || fail "an allowlist that does not list $VAR stripped the scout's assignment"

  new_case allow-ship-listed
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  printf '%s\n' "$VAR" > "$HOME_DIR/config/launch-env-allowlist"
  store_accepts "$HOME_DIR/user-home"
  spawn ship cm-allow-ship
  expect_code 0 "$RC" "a ship spawn with the variable allowlisted should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "/usr/bin/env -i" "the allowlist wrapper must be in force for this case"
  [ "$(pane "$VAR=1")" = unset ] || fail "allowlisting $VAR let it reach a ship worker"
  pass "the launch-env allowlist neither strips the scout's assignment nor lets a stray value reach a ship"
}

test_invalid_knob_refuses_before_any_record() {
  local body id n=0
  for body in maybe workers 'scouts ships' ''; do
    n=$((n + 1))
    id="cm-bad-$n"
    new_case "bad-$n"
    printf '%s\n' "$body" > "$HOME_DIR/config/claude-code-mode"
    spawn scout "$id"
    expect_code 1 "$RC" "config/claude-code-mode holding '$body' must refuse the spawn"
    assert_contains "$OUT" "config/claude-code-mode" "the refusal must name the file"
    assert_contains "$OUT" "off" "the refusal must list off as an accepted value"
    assert_contains "$OUT" "scouts" "the refusal must list scouts as an accepted value"
    [ ! -s "$CASE/launch.log" ] || fail "a refused spawn must launch nothing"
    assert_absent "$HOME_DIR/state/$id.meta" "the refusal must happen before the task record exists"
  done
  new_case bad-dir
  mkdir "$HOME_DIR/config/claude-code-mode"
  spawn ship cm-bad-dir
  expect_code 1 "$RC" "an unreadable config/claude-code-mode must refuse the spawn"
  assert_contains "$OUT" "config/claude-code-mode must be a readable regular file" "the refusal must say the file is unreadable"
  assert_absent "$HOME_DIR/state/cm-bad-dir.meta" "the refusal must happen before the task record exists"
  pass "an unrecognized or unreadable config/claude-code-mode refuses every spawn before any record exists"
}

test_unaccepted_dialog_skips_with_one_explanatory_line() {
  local variant
  for variant in no-store no-key false-key unparsable; do
    new_case "skip-$variant"
    printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
    case "$variant" in
    no-store) ;;
    no-key) store_accepts "$HOME_DIR/user-home" '{"projects":{}}' ;;
    false-key) store_accepts "$HOME_DIR/user-home" '{"codeModeCaveatsAcceptedV1":false}' ;;
    unparsable) store_accepts "$HOME_DIR/user-home" 'not json' ;;
    esac
    spawn scout "cm-skip-$variant"
    # An unparsable store makes the trust pre-registration refuse for its own
    # reason, which is outside this behavior; every other variant must spawn.
    [ "$variant" = unparsable ] && continue
    expect_code 0 "$RC" "a skipped Code Mode launch must not fail the spawn ($variant)"$'\n'"$OUT"
    assert_contains "$OUT" "Code Mode" "the spawn output must say Code Mode was skipped ($variant)"
    assert_contains "$OUT" "$HOME_DIR/user-home" "the note must name the config directory ($variant)"
    [ "$(skip_lines)" = 1 ] || fail "exactly one explanatory line is expected ($variant): $OUT"
    assert_contains "$LAUNCH" "$UNSET_FORM" "a skipped launch must carry the unset form ($variant)"
    assert_not_contains "$LAUNCH" "$VAR=1" "a skipped launch must not assign the variable ($variant)"
    [ "$(pane "$VAR=1")" = unset ] || fail "a skipped launch still reached the worker with $VAR ($variant)"
  done
  pass "a scout whose config directory has not accepted the Code Mode dialog launches without it and says why once"
}

test_pinned_account_root_decides_acceptance() {
  new_case pin-accepted
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  printf '%s\n' "$CASE/work" > "$HOME_DIR/config/claude-account"
  mkdir -p "$CASE/work"
  printf '{}\n' > "$CASE/work/.credentials.json"
  store_accepts "$CASE/work"
  spawn scout cm-pin-accepted
  expect_code 0 "$RC" "a pinned scout spawn should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "$VAR=1" "acceptance recorded in the pinned root must enable Code Mode"

  new_case pin-ambient-only
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  printf '%s\n' "$CASE/work" > "$HOME_DIR/config/claude-account"
  mkdir -p "$CASE/work"
  printf '{}\n' > "$CASE/work/.credentials.json"
  store_accepts "$HOME_DIR/user-home"
  spawn scout cm-pin-ambient
  expect_code 0 "$RC" "a pinned scout spawn should succeed"$'\n'"$OUT"
  assert_not_contains "$LAUNCH" "$VAR=1" "acceptance in the ambient store must not enable Code Mode for a pinned worker"
  assert_contains "$(printf '%s\n' "$OUT" | grep 'Code Mode skipped')" "$CASE/work" "the skip note must name the pinned root the worker reads"
  pass "a pinned worker's own config root, not the ambient one, decides whether Code Mode starts"
}

test_auto_permission_mode_keeps_scouts_off_with_a_reason() {
  new_case auto-mode
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  printf 'auto\n' > "$HOME_DIR/config/claude-permission-mode"
  store_accepts "$HOME_DIR/user-home"
  spawn scout cm-auto
  expect_code 0 "$RC" "a scout spawn under auto permission mode should succeed"$'\n'"$OUT"
  assert_contains "$LAUNCH" "$UNSET_FORM" "a scout under auto mode must unset the variable"
  assert_not_contains "$LAUNCH" "$VAR=1" "a scout under auto mode must not enable Code Mode"
  assert_contains "$OUT" "claude-permission-mode" "the note must name the permission mode that forced it off"
  [ "$(skip_lines)" = 1 ] || fail "exactly one explanatory line is expected: $OUT"
  pass "claude-permission-mode=auto keeps scouts out of Code Mode and says why"
}

test_other_harnesses_and_raw_commands_are_untouched() {
  new_case codex-scout codex
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  store_accepts "$HOME_DIR/user-home"
  spawn scout cm-codex --harness codex
  expect_code 0 "$RC" "a codex scout spawn under the scouts knob should succeed"$'\n'"$OUT"
  assert_not_contains "$LAUNCH" "$VAR" "a non-Claude launch must not mention the Code Mode variable"
  [ "$(skip_lines)" = 0 ] || fail "a non-Claude launch requested nothing: $OUT"

  new_case raw-scout claude
  printf 'scouts\n' > "$HOME_DIR/config/claude-code-mode"
  store_accepts "$HOME_DIR/user-home"
  spawn scout cm-raw "claude --raw-flag"
  expect_code 0 "$RC" "a raw-command scout spawn should succeed"$'\n'"$OUT"
  assert_not_contains "$LAUNCH" "$VAR" "a raw launch command is launched verbatim"
  pass "non-Claude harnesses and raw launch commands are launched exactly as before"
}

test_library_parses_the_knob_and_reads_the_store_without_writing() {
  local dir out rc before after
  dir="$TMP_ROOT/lib"
  mkdir -p "$dir/config" "$dir/store"
  # shellcheck source=bin/fm-claude-code-mode-lib.sh
  . "$ROOT/bin/fm-claude-code-mode-lib.sh"

  [ "$(fm_claude_code_mode_setting "$dir/config")" = off ] || fail "an absent file must resolve to off"
  printf '  scouts \n' > "$dir/config/claude-code-mode"
  [ "$(fm_claude_code_mode_setting "$dir/config")" = scouts ] || fail "scouts must resolve with whitespace trimmed"
  printf 'off\n' > "$dir/config/claude-code-mode"
  [ "$(fm_claude_code_mode_setting "$dir/config")" = off ] || fail "off must resolve to off"
  printf 'ships\n' > "$dir/config/claude-code-mode"
  out=$(fm_claude_code_mode_setting "$dir/config" 2>&1); rc=$?
  expect_code 1 "$rc" "an unknown token must be refused"
  assert_contains "$out" "holds 'ships'" "the refusal must quote the offending token"

  printf '{"codeModeCaveatsAcceptedV1":true,"other":1}\n' > "$dir/store/.claude.json"
  before=$(cksum < "$dir/store/.claude.json")
  fm_claude_code_mode_accepted "$dir/store" || fail "a boolean true must read as accepted"
  after=$(cksum < "$dir/store/.claude.json")
  [ "$before" = "$after" ] || fail "the acceptance check wrote the store"
  for body in '{"codeModeCaveatsAcceptedV1":false}' '{"codeModeCaveatsAcceptedV1":"true"}' '{}' '[]' 'garbage' ''; do
    printf '%s\n' "$body" > "$dir/store/.claude.json"
    fm_claude_code_mode_accepted "$dir/store" && fail "'$body' must not read as accepted"
  done
  rm "$dir/store/.claude.json"
  fm_claude_code_mode_accepted "$dir/store" && fail "an absent store must not read as accepted"
  pass "the library resolves the knob strictly and reads acceptance without ever writing the store"
}

test_knob_is_not_inherited_into_secondmate_homes() {
  local list
  list=$(bash -c '. "$1/bin/fm-config-inherit-lib.sh"; printf "%s\n" "$FM_INHERITABLE_CONFIG"' _ "$ROOT")
  assert_not_contains "$list" "claude-code-mode" "the Code Mode knob must stay a per-home choice"
  pass "config/claude-code-mode is not inherited into secondmate homes"
}

# engine_turn <dir>: one real engine turn with the Code Mode variable set in the
# host's environment, run in its own subshell with the engine libraries sourced.
engine_turn() (
  export FM_ROOT="$ROOT" FM_HOME="$1/home" STATE="$1/home/state"
  export FM_SUPERVISION_ENGINE_CLAUDE_BIN="$1/engine" "$VAR=1"
  # shellcheck source=bin/fm-wake-lib.sh
  . "$ROOT/bin/fm-wake-lib.sh"
  # shellcheck source=bin/fm-timeout-lib.sh
  . "$ROOT/bin/fm-timeout-lib.sh"
  # shellcheck source=bin/fm-supervision-engine-lib.sh
  . "$ROOT/bin/fm-supervision-engine-lib.sh"
  fm_supervision_engine_turn claude haiku "$1/prompt" "$1/message" "00000000-0000-4000-8000-000000000000" new 30 "$1/result" "$1/errors"
)

test_supervision_engine_never_inherits_the_variable() {
  local eng out rc
  eng="$TMP_ROOT/engine"
  mkdir -p "$eng/home/state"
  cat > "$eng/engine" <<SH
#!/usr/bin/env bash
printf '%s\\n' "\${$VAR-unset}" > '$eng/engine-env'
printf '{"type":"result"}\\n'
SH
  chmod +x "$eng/engine"
  : > "$eng/prompt"
  : > "$eng/message"
  out=$(engine_turn "$eng" 2>&1); rc=$?
  expect_code 0 "$rc" "the stub engine turn should complete: $out $(cat "$eng/errors" 2>/dev/null)"
  [ "$(cat "$eng/engine-env" 2>/dev/null)" = unset ] || fail "the supervision engine inherited $VAR from the host's environment"
  pass "the supervision host's print-mode engine never inherits the Code Mode variable"
}

test_absent_knob_unsets_the_variable_for_scouts_and_ships
test_scouts_knob_enables_only_scouts_with_recorded_acceptance
test_scouts_knob_never_reaches_a_secondmate
test_launch_env_allowlist_does_not_decide
test_invalid_knob_refuses_before_any_record
test_unaccepted_dialog_skips_with_one_explanatory_line
test_pinned_account_root_decides_acceptance
test_auto_permission_mode_keeps_scouts_off_with_a_reason
test_other_harnesses_and_raw_commands_are_untouched
test_supervision_engine_never_inherits_the_variable
test_library_parses_the_knob_and_reads_the_store_without_writing
test_knob_is_not_inherited_into_secondmate_homes

echo "# all fm-spawn-claude-code-mode tests passed"
