#!/usr/bin/env bash
# fm-install-lint-tools.sh - provision firstmate's pinned lint tools.
#
# Installs the pinned ShellCheck and actionlint into the managed per-user tool
# directory that bin/fm-lint-tools-lib.sh owns, using the same checksum-verified
# installers CI runs (bin/fm-install-shellcheck.sh and
# bin/fm-install-actionlint.sh). bin/fm-lint.sh and bin/fm-lint-workflows.sh
# fall back to that directory when a tool is not on PATH, which is how the
# shared no-mistakes daemon's fixed search path finds them without any change
# to the daemon. A tool already at its pinned version is skipped, so repeating
# the command downloads nothing. It never starts, stops, or configures the
# daemon.
#
# Usage:
#   fm-install-lint-tools.sh            install whatever is missing or off-pin
#   fm-install-lint-tools.sh --check    report each tool, change nothing; exit 1
#                                       when either is missing or off-pin
#   fm-install-lint-tools.sh --help     print this usage
#
# The directory is $FM_LINT_TOOLS_DIR, else
# ${XDG_CACHE_HOME:-$HOME/.cache}/firstmate/lint-tools.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SELF_DIR/fm-install-lint-tools.sh"
# shellcheck source=bin/fm-lint-tools-lib.sh
. "$SELF_DIR/fm-lint-tools-lib.sh"

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$SELF"
}

CHECK=0
case "${1:-}" in
  '') ;;
  --check) CHECK=1 ;;
  --help|-h) usage; exit 0 ;;
  *)
    printf 'fm-install-lint-tools.sh: unknown argument: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac
[ "$#" -le 1 ] || {
  printf 'fm-install-lint-tools.sh: too many arguments\n' >&2
  usage >&2
  exit 2
}

DIR=$(fm_lint_tools_dir) || {
  printf 'fm-install-lint-tools.sh: no managed directory; set FM_LINT_TOOLS_DIR or HOME.\n' >&2
  exit 1
}

# probe <tool>: print the managed binary's own reported version, or nothing.
probe() {
  [ -f "$DIR/$1" ] && [ -x "$DIR/$1" ] || return 0
  case "$1" in
    shellcheck) "$DIR/shellcheck" --version 2>/dev/null | awk '/^version:/ {print $2; exit}' ;;
    actionlint) "$DIR/actionlint" -version 2>/dev/null | awk 'NR==1 {print; exit}' ;;
  esac
}

STATUS=0
provision() {  # <tool> <pin> <installer>
  local tool=$1 pin=$2 installer=$3 have
  have=$(probe "$tool")
  if [ "$have" = "$pin" ]; then
    printf 'fm-install-lint-tools.sh: %s %s ok in %s\n' "$tool" "$pin" "$DIR"
    return 0
  fi
  if [ -z "$have" ]; then
    printf 'fm-install-lint-tools.sh: %s missing from %s (pinned %s)\n' "$tool" "$DIR" "$pin" >&2
  else
    printf 'fm-install-lint-tools.sh: %s %s in %s is not the pinned %s\n' "$tool" "$have" "$DIR" "$pin" >&2
  fi
  if [ "$CHECK" -eq 1 ]; then
    STATUS=1
    return 0
  fi
  if ! "$installer" "$DIR" >/dev/null; then
    STATUS=1
    return 0
  fi
  have=$(probe "$tool")
  if [ "$have" = "$pin" ]; then
    printf 'fm-install-lint-tools.sh: installed %s %s into %s\n' "$tool" "$pin" "$DIR"
  else
    printf 'fm-install-lint-tools.sh: %s reports %s after install, expected %s\n' "$tool" "${have:-nothing}" "$pin" >&2
    STATUS=1
  fi
}

SC_PIN=$("$SELF_DIR/fm-lint.sh" --required-version) || exit 1
AL_PIN=$("$SELF_DIR/fm-lint-workflows.sh" --required-version) || exit 1
provision shellcheck "$SC_PIN" "$SELF_DIR/fm-install-shellcheck.sh"
provision actionlint "$AL_PIN" "$SELF_DIR/fm-install-actionlint.sh"
exit "$STATUS"
