#!/usr/bin/env bash
# Managed pinned lint tools for the no-mistakes pipeline.
#
# The shared no-mistakes daemon runs commands.lint (bin/fm-lint.sh) with its own
# fixed search path, so the pinned ShellCheck and actionlint that workers and CI
# put on their own PATH are invisible to it. bin/fm-lint-tools-lib.sh owns one
# per-user managed directory that bin/fm-lint.sh and bin/fm-lint-workflows.sh
# fall back to, bin/fm-install-lint-tools.sh provisions it, and these cases pin
# the lookup order, the version refusal, the provisioning contract, and the
# resolution from a clean `env -i` environment that mimics the daemon.
# Every case sets FM_LINT_TOOLS_DIR or a temporary HOME, so a developer machine
# that is already provisioned cannot change a verdict.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LINT="$ROOT/bin/fm-lint.sh"
LINT_WF="$ROOT/bin/fm-lint-workflows.sh"
LIB="$ROOT/bin/fm-lint-tools-lib.sh"
PROVISION="$ROOT/bin/fm-install-lint-tools.sh"
SC_INSTALLER="$ROOT/bin/fm-install-shellcheck.sh"
AL_INSTALLER="$ROOT/bin/fm-install-actionlint.sh"
SC_PIN=$("$LINT" --required-version)
AL_PIN=$("$LINT_WF" --required-version)

# Official sha256 values from the pinned release assets: shellcheck v0.11.0
# linux x86_64 .tar.xz and actionlint 1.7.12 linux amd64 .tar.gz.
SC_SHA_LINUX_AMD64=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
AL_SHA_LINUX_AMD64=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8

# Driver for a library call under a clean environment: source the library, then
# run the named function with its arguments.
# shellcheck disable=SC2016
LIB_DRIVER='. "$1"; shift; "$@"'

# write_tool <dir> <shellcheck|actionlint> <version> [marker-file]: a tiny fake
# tool that reports <version> the way the real one does and, when it is run for
# real, records its own path in the marker file.
write_tool() {
  local dir=$1 name=$2 version=$3 marker=${4:-}
  mkdir -p "$dir"
  case "$name" in
    shellcheck)
      cat > "$dir/shellcheck" <<SH
#!/usr/bin/env bash
case "\${1:-}" in
  --version) printf 'ShellCheck - shell script analysis tool\nversion: $version\n'; exit 0 ;;
esac
[ -z "$marker" ] || printf '%s\n' "\$0" >> "$marker"
exit 0
SH
      ;;
    actionlint)
      cat > "$dir/actionlint" <<SH
#!/usr/bin/env bash
case "\${1:-}" in
  -version) printf '$version\ninstalled by test\n'; exit 0 ;;
esac
[ -z "$marker" ] || printf '%s\n' "\$0" >> "$marker"
exit 0
SH
      ;;
  esac
  chmod +x "$dir/$name"
}

# A search path of symlinks to every system tool except ShellCheck and
# actionlint, so a host that ships either cannot satisfy a lookup the way the
# daemon's own search path cannot. Built once per run because it holds a link
# per system executable.
build_daemon_path() {
  local dir=$1/daemon-bin src name
  mkdir -p "$dir"
  for src in /usr/bin/* /bin/*; do
    name=${src##*/}
    case "$name" in shellcheck|actionlint) continue ;; esac
    [ -x "$src" ] && [ ! -d "$src" ] || continue
    [ -e "$dir/$name" ] || ln -s "$src" "$dir/$name"
  done
  printf '%s\n' "$dir"
}
DAEMON_BIN=$(build_daemon_path "$(fm_test_tmproot fm-lint-tools-daemon-bin)")

test_dir_honors_the_override() {
  local out
  out=$(env -i FM_LINT_TOOLS_DIR=/somewhere/tools HOME=/h bash -c "$LIB_DRIVER" _ "$LIB" fm_lint_tools_dir) \
    || fail "override lookup failed"
  assert_equals "/somewhere/tools" "$out" "FM_LINT_TOOLS_DIR was not honored"
  pass "managed directory honors FM_LINT_TOOLS_DIR"
}

test_dir_default_follows_xdg_then_home() {
  local out
  out=$(env -i XDG_CACHE_HOME=/xdg HOME=/h bash -c "$LIB_DRIVER" _ "$LIB" fm_lint_tools_dir) \
    || fail "xdg lookup failed"
  assert_equals "/xdg/firstmate/lint-tools" "$out" "XDG_CACHE_HOME was not used"
  out=$(env -i HOME=/h bash -c "$LIB_DRIVER" _ "$LIB" fm_lint_tools_dir) || fail "home lookup failed"
  assert_equals "/h/.cache/firstmate/lint-tools" "$out" "HOME/.cache was not the default"
  pass "managed directory defaults under XDG_CACHE_HOME then HOME/.cache"
}

test_dir_without_a_home_is_absent_not_an_error() {
  local tmp rc=0 out
  tmp=$(fm_test_tmproot fm-lint-tools-nohome)
  out=$(env -i PATH="$DAEMON_BIN" bash -c "$LIB_DRIVER" _ "$LIB" fm_lint_tools_dir 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail "a missing home still produced a directory: $out"
  rc=0
  out=$(env -i PATH="$DAEMON_BIN" bash -c "$LIB_DRIVER" _ "$LIB" fm_lint_tool_resolve shellcheck 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "resolution without a home expected rc 1, got $rc: $out"
  assert_equals "" "$out" "resolution without a home printed output"
  pass "no home and no override reads as an absent directory"
}

test_resolve_ignores_a_non_executable_managed_file() {
  local tmp rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-nonexec)
  mkdir -p "$tmp/tools"
  : > "$tmp/tools/shellcheck"
  env -i FM_LINT_TOOLS_DIR="$tmp/tools" PATH="$DAEMON_BIN" \
    bash -c "$LIB_DRIVER" _ "$LIB" fm_lint_tool_resolve shellcheck >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "a non-executable managed file was resolved (rc=$rc)"
  pass "a non-executable managed file is ignored"
}

test_clean_env_resolves_the_default_managed_directory() {
  local tmp home out rc=0 marker
  tmp=$(fm_test_tmproot fm-lint-tools-clean)
  home="$tmp/home"
  marker="$tmp/ran"
  write_tool "$home/.cache/firstmate/lint-tools" shellcheck "$SC_PIN" "$marker"
  write_tool "$home/.cache/firstmate/lint-tools" actionlint "$AL_PIN" "$marker"
  out=$(env -i HOME="$home" PATH="$DAEMON_BIN" "$LINT" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "lint from a clean environment failed (rc=$rc)"$'\n'"$out"
  assert_contains "$out" "ShellCheck $SC_PIN (pinned $SC_PIN)" "the pinned ShellCheck was not resolved"
  assert_contains "$out" "actionlint $AL_PIN (pinned $AL_PIN)" "the pinned actionlint was not resolved"
  assert_contains "$out" "workflow files valid" "the workflow lint did not run"
  grep -q "$home/.cache/firstmate/lint-tools/actionlint" "$marker" \
    || fail "the managed actionlint did not lint the workflows"
  pass "a clean daemon-like environment resolves both pinned tools from the default directory"
}

test_search_path_wins_over_the_managed_directory() {
  local tmp out rc=0 marker target
  tmp=$(fm_test_tmproot fm-lint-tools-order)
  marker="$tmp/ran"
  write_tool "$tmp/pathbin" shellcheck "$SC_PIN" "$marker"
  write_tool "$tmp/pathbin" actionlint "$AL_PIN" "$marker"
  write_tool "$tmp/tools" shellcheck "$SC_PIN" "$marker"
  write_tool "$tmp/tools" actionlint "$AL_PIN" "$marker"
  target="$tmp/probe.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$target"
  out=$(env -i FM_LINT_TOOLS_DIR="$tmp/tools" PATH="$tmp/pathbin:$DAEMON_BIN" "$LINT" "$target" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "lint with both locations failed (rc=$rc)"$'\n'"$out"
  grep -q "$tmp/pathbin/shellcheck" "$marker" || fail "the search-path ShellCheck did not run"
  grep -q "$tmp/tools/shellcheck" "$marker" && fail "the managed ShellCheck ran despite a search-path one"
  : > "$marker"
  rc=0
  mkdir -p "$tmp/wf/.github/workflows"
  printf 'name: t\non: push\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' \
    > "$tmp/wf/.github/workflows/t.yml"
  env -i FM_LINT_TOOLS_DIR="$tmp/tools" PATH="$tmp/pathbin:$DAEMON_BIN" \
    "$LINT_WF" --root "$tmp/wf" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || fail "workflow lint with both locations failed (rc=$rc)"
  grep -q "$tmp/pathbin/actionlint" "$marker" || fail "the search-path actionlint did not run"
  grep -q "$tmp/tools/actionlint" "$marker" && fail "the managed actionlint ran despite a search-path one"
  pass "a tool on the search path wins over the managed directory"
}

test_off_pin_managed_tools_are_refused() {
  local tmp out rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-offpin)
  write_tool "$tmp/tools" shellcheck "0.10.0"
  write_tool "$tmp/tools" actionlint "1.7.0"
  printf '#!/usr/bin/env bash\ntrue\n' > "$tmp/probe.sh"
  out=$(env -i FM_LINT_TOOLS_DIR="$tmp/tools" PATH="$DAEMON_BIN" "$LINT" "$tmp/probe.sh" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "off-pin ShellCheck expected rc 1, got $rc"$'\n'"$out"
  assert_contains "$out" "ShellCheck $SC_PIN required for CI parity, found 0.10.0" "off-pin ShellCheck was not refused"
  rc=0
  mkdir -p "$tmp/wf/.github/workflows"
  printf 'name: t\non: push\njobs: {}\n' > "$tmp/wf/.github/workflows/t.yml"
  out=$(env -i FM_LINT_TOOLS_DIR="$tmp/tools" PATH="$DAEMON_BIN" "$LINT_WF" --root "$tmp/wf" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "off-pin actionlint expected rc 1, got $rc"$'\n'"$out"
  assert_contains "$out" "actionlint $AL_PIN required for CI parity, found 1.7.0" "off-pin actionlint was not refused"
  pass "an off-pin managed tool is refused naming the pin"
}

# stub_downloads <fakebin>: replace everything the pinned installers use to
# reach the network or unpack an archive, so a provisioning run is offline and
# deterministic. curl logs each URL to $CURL_LOG; sha256sum answers with the
# published digest of the archive it is asked about unless SHA_BAD=1; tar drops
# a fake tool that reports the pinned version where the real archive would.
# The stubs read the pins and digests from FM_STUB_* words that stub_env passes.
stub_downloads() {
  local fakebin=$1
  mkdir -p "$fakebin"
  cat > "$fakebin/uname" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in -m) echo x86_64 ;; *) echo Linux ;; esac
SH
  cat > "$fakebin/curl" <<'SH'
#!/usr/bin/env bash
out=
url=
while [ "$#" -gt 0 ]; do
  case "$1" in -o) out=$2; shift 2 ;; -*) shift ;; *) url=$1; shift ;; esac
done
[ -z "${CURL_LOG:-}" ] || printf '%s\n' "$url" >> "$CURL_LOG"
: > "$out"
SH
  cat > "$fakebin/sha256sum" <<'SH'
#!/usr/bin/env bash
if [ "${SHA_BAD:-}" = 1 ]; then
  printf '%s  %s\n' 0000000000000000000000000000000000000000000000000000000000000000 "$1"
  exit 0
fi
case "$1" in
  *shellcheck*) printf '%s  %s\n' "$FM_STUB_SC_SHA" "$1" ;;
  *) printf '%s  %s\n' "$FM_STUB_AL_SHA" "$1" ;;
esac
SH
  cat > "$fakebin/tar" <<'SH'
#!/usr/bin/env bash
dest=
archive=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -C) dest=$2; shift 2 ;;
    -x*) archive=$2; shift 2 ;;
    *) shift ;;
  esac
done
case "$archive" in
  *shellcheck*)
    mkdir -p "$dest/shellcheck-v$FM_STUB_SC_PIN"
    {
      printf '#!/usr/bin/env bash\n'
      printf 'printf "ShellCheck - shell script analysis tool\\nversion: %%s\\n" "%s"\n' "$FM_STUB_SC_PIN"
    } > "$dest/shellcheck-v$FM_STUB_SC_PIN/shellcheck"
    chmod +x "$dest/shellcheck-v$FM_STUB_SC_PIN/shellcheck"
    ;;
  *)
    {
      printf '#!/usr/bin/env bash\n'
      printf 'printf "%%s\\ninstalled by test\\n" "%s"\n' "$FM_STUB_AL_PIN"
    } > "$dest/actionlint"
    chmod +x "$dest/actionlint"
    ;;
esac
SH
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/sleep"
  chmod +x "$fakebin"/*
}

# stub_env prints the words every provisioning run is given on top of env -i.
stub_env() {
  printf '%s\n' "FM_STUB_SC_PIN=$SC_PIN" "FM_STUB_AL_PIN=$AL_PIN" \
    "FM_STUB_SC_SHA=$SC_SHA_LINUX_AMD64" "FM_STUB_AL_SHA=$AL_SHA_LINUX_AMD64"
}

curl_count() {
  if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi
}

# provision_env <tmp>: sets FAKEBIN, TOOLS, and the shared env words for a run.
provision_world() {
  local tmp=$1
  FAKEBIN="$tmp/fakebin"
  TOOLS="$tmp/tools"
  stub_downloads "$FAKEBIN"
  : > "$tmp/curl.log"
}

run_provision() {  # <tmp> <args...>
  local tmp=$1
  shift
  # shellcheck disable=SC2046
  env -i $(stub_env) HOME="$tmp/home" CURL_LOG="$tmp/curl.log" SHA_BAD="${SHA_BAD:-}" FM_LINT_TOOLS_DIR="$TOOLS" \
    PATH="$FAKEBIN:$DAEMON_BIN" "$PROVISION" "$@"
}

test_provisioning_installs_both_pinned_tools() {
  local tmp out rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-prov)
  provision_world "$tmp"
  out=$(run_provision "$tmp" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "provisioning failed (rc=$rc)"$'\n'"$out"
  [ -x "$TOOLS/shellcheck" ] && [ -x "$TOOLS/actionlint" ] || fail "provisioning left a tool missing"$'\n'"$out"
  [ "$("$TOOLS/shellcheck" --version | awk '/^version:/ {print $2}')" = "$SC_PIN" ] || fail "installed ShellCheck is off-pin"
  [ "$("$TOOLS/actionlint" -version | head -1)" = "$AL_PIN" ] || fail "installed actionlint is off-pin"
  grep -q "shellcheck-v$SC_PIN.linux.x86_64.tar.xz" "$tmp/curl.log" || fail "the pinned ShellCheck archive was not fetched"
  grep -q "actionlint_${AL_PIN}_linux_amd64.tar.gz" "$tmp/curl.log" || fail "the pinned actionlint archive was not fetched"
  pass "provisioning installs both pinned tools through the installers"
}

test_second_provisioning_downloads_nothing() {
  local tmp out rc=0 before
  tmp=$(fm_test_tmproot fm-lint-tools-idem)
  provision_world "$tmp"
  run_provision "$tmp" >/dev/null 2>&1 || fail "first provisioning failed"
  before=$(curl_count "$tmp/curl.log")
  out=$(run_provision "$tmp" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "second provisioning failed (rc=$rc)"$'\n'"$out"
  assert_equals "$before" "$(curl_count "$tmp/curl.log")" "a second provisioning run downloaded again"
  pass "a second provisioning run downloads nothing"
}

test_an_already_pinned_tool_is_skipped() {
  local tmp rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-skip)
  provision_world "$tmp"
  write_tool "$TOOLS" shellcheck "$SC_PIN"
  run_provision "$tmp" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || fail "provisioning with one tool present failed (rc=$rc)"
  assert_equals "1" "$(curl_count "$tmp/curl.log")" "provisioning fetched more than the one missing tool"
  grep -q actionlint "$tmp/curl.log" || fail "the missing tool was not the one fetched"
  pass "provisioning skips a tool that is already at its pin"
}

test_a_checksum_mismatch_installs_nothing() {
  local tmp out rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-badsum)
  provision_world "$tmp"
  out=$(SHA_BAD=1 run_provision "$tmp" 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail "a checksum mismatch still exited 0"$'\n'"$out"
  assert_contains "$out" "checksum mismatch" "the mismatch was not reported"
  [ ! -e "$TOOLS/shellcheck" ] && [ ! -e "$TOOLS/actionlint" ] || fail "a tool was installed despite a checksum mismatch"
  pass "a checksum mismatch exits non-zero and installs nothing"
}

test_check_reports_without_changing_anything() {
  local tmp out rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-check)
  provision_world "$tmp"
  out=$(run_provision "$tmp" --check 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "--check on an empty directory expected rc 1, got $rc"$'\n'"$out"
  assert_contains "$out" "shellcheck" "--check did not name ShellCheck"
  assert_contains "$out" "actionlint" "--check did not name actionlint"
  [ ! -e "$TOOLS" ] || fail "--check created the managed directory"
  assert_equals "0" "$(curl_count "$tmp/curl.log")" "--check downloaded something"
  write_tool "$TOOLS" shellcheck "$SC_PIN"
  write_tool "$TOOLS" actionlint "1.7.0"
  rc=0
  out=$(run_provision "$tmp" --check 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "--check with an off-pin tool expected rc 1, got $rc"$'\n'"$out"
  assert_contains "$out" "1.7.0" "--check did not report the off-pin version"
  write_tool "$TOOLS" actionlint "$AL_PIN"
  rc=0
  out=$(run_provision "$tmp" --check 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "--check with both pinned expected rc 0, got $rc"$'\n'"$out"
  assert_equals "0" "$(curl_count "$tmp/curl.log")" "--check downloaded something"
  pass "--check reports each tool and changes nothing"
}

test_an_unknown_argument_exits_2_with_usage() {
  local tmp out rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-usage)
  provision_world "$tmp"
  out=$(run_provision "$tmp" --nope 2>&1) || rc=$?
  [ "$rc" -eq 2 ] || fail "an unknown argument expected rc 2, got $rc"$'\n'"$out"
  assert_contains "$out" "Usage" "the usage text was not printed"
  assert_equals "0" "$(curl_count "$tmp/curl.log")" "a refused argument downloaded something"
  pass "an unknown argument exits 2 with usage"
}

test_provisioning_never_touches_the_daemon() {
  local tmp
  tmp=$(fm_test_tmproot fm-lint-tools-daemon)
  provision_world "$tmp"
  printf '#!/usr/bin/env bash\necho "$*" >> "%s"\nexit 1\n' "$tmp/no-mistakes.log" > "$FAKEBIN/no-mistakes"
  chmod +x "$FAKEBIN/no-mistakes"
  run_provision "$tmp" >/dev/null 2>&1 || fail "provisioning failed"
  run_provision "$tmp" --check >/dev/null 2>&1 || fail "--check failed"
  [ ! -e "$tmp/no-mistakes.log" ] || fail "provisioning invoked no-mistakes: $(cat "$tmp/no-mistakes.log")"
  pass "provisioning never invokes the no-mistakes daemon"
}

test_installers_default_to_the_managed_directory() {
  local tmp
  tmp=$(fm_test_tmproot fm-lint-tools-default)
  provision_world "$tmp"
  # shellcheck disable=SC2046
  env -i $(stub_env) HOME="$tmp/home" CURL_LOG="$tmp/curl.log" FM_LINT_TOOLS_DIR="$TOOLS" \
    PATH="$FAKEBIN:$DAEMON_BIN" "$SC_INSTALLER" >/dev/null 2>&1 || fail "ShellCheck installer with no destination failed"
  # shellcheck disable=SC2046
  env -i $(stub_env) HOME="$tmp/home" CURL_LOG="$tmp/curl.log" FM_LINT_TOOLS_DIR="$TOOLS" \
    PATH="$FAKEBIN:$DAEMON_BIN" "$AL_INSTALLER" >/dev/null 2>&1 || fail "actionlint installer with no destination failed"
  [ -x "$TOOLS/shellcheck" ] && [ -x "$TOOLS/actionlint" ] || fail "an installer ignored the managed directory"
  pass "each installer defaults to the managed directory"
}

test_installers_honor_an_explicit_destination() {
  local tmp
  tmp=$(fm_test_tmproot fm-lint-tools-explicit)
  provision_world "$tmp"
  # shellcheck disable=SC2046
  env -i $(stub_env) HOME="$tmp/home" CURL_LOG="$tmp/curl.log" FM_LINT_TOOLS_DIR="$TOOLS" \
    PATH="$FAKEBIN:$DAEMON_BIN" "$SC_INSTALLER" "$tmp/elsewhere" >/dev/null 2>&1 || fail "ShellCheck installer failed"
  # shellcheck disable=SC2046
  env -i $(stub_env) HOME="$tmp/home" CURL_LOG="$tmp/curl.log" FM_LINT_TOOLS_DIR="$TOOLS" \
    PATH="$FAKEBIN:$DAEMON_BIN" "$AL_INSTALLER" "$tmp/elsewhere" >/dev/null 2>&1 || fail "actionlint installer failed"
  [ -x "$tmp/elsewhere/shellcheck" ] && [ -x "$tmp/elsewhere/actionlint" ] || fail "an installer ignored its explicit destination"
  [ ! -e "$TOOLS" ] || fail "an installer wrote the managed directory despite an explicit destination"
  pass "each installer keeps honoring an explicit destination"
}

test_missing_tools_name_the_provisioning_command() {
  local tmp out rc=0
  tmp=$(fm_test_tmproot fm-lint-tools-msg)
  printf '#!/usr/bin/env bash\ntrue\n' > "$tmp/probe.sh"
  out=$(env -i FM_LINT_TOOLS_DIR="$tmp/empty" PATH="$DAEMON_BIN" "$LINT" "$tmp/probe.sh" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "missing ShellCheck expected rc 1, got $rc"$'\n'"$out"
  assert_contains "$out" "fm-install-lint-tools.sh" "the ShellCheck message did not name the provisioning command"
  assert_contains "$out" "$tmp/empty" "the ShellCheck message did not name the managed directory"
  assert_contains "$out" "fm-install-shellcheck.sh" "the ShellCheck message lost the pinned installer"
  mkdir -p "$tmp/wf/.github/workflows"
  printf 'name: t\non: push\njobs: {}\n' > "$tmp/wf/.github/workflows/t.yml"
  rc=0
  out=$(env -i FM_LINT_TOOLS_DIR="$tmp/empty" PATH="$DAEMON_BIN" "$LINT_WF" --root "$tmp/wf" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "missing actionlint expected rc 1, got $rc"$'\n'"$out"
  assert_contains "$out" "fm-install-lint-tools.sh" "the actionlint message did not name the provisioning command"
  assert_contains "$out" "$tmp/empty" "the actionlint message did not name the managed directory"
  assert_contains "$out" "fm-install-actionlint.sh" "the actionlint message lost the pinned installer"
  pass "a missing tool names the provisioning command and the managed directory"
}

test_dir_honors_the_override
test_dir_default_follows_xdg_then_home
test_dir_without_a_home_is_absent_not_an_error
test_resolve_ignores_a_non_executable_managed_file
test_clean_env_resolves_the_default_managed_directory
test_search_path_wins_over_the_managed_directory
test_off_pin_managed_tools_are_refused
test_provisioning_installs_both_pinned_tools
test_second_provisioning_downloads_nothing
test_an_already_pinned_tool_is_skipped
test_a_checksum_mismatch_installs_nothing
test_check_reports_without_changing_anything
test_an_unknown_argument_exits_2_with_usage
test_provisioning_never_touches_the_daemon
test_installers_default_to_the_managed_directory
test_installers_honor_an_explicit_destination
test_missing_tools_name_the_provisioning_command
