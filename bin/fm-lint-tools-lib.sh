#!/usr/bin/env bash
# fm-lint-tools-lib.sh - single owner of where firstmate's pinned lint tools live.
#
# Sourced by bin/fm-lint.sh, bin/fm-lint-workflows.sh, and the pinned
# installers. The shared no-mistakes daemon runs commands.lint with its own
# fixed search path, which never includes the PATH a worker or CI stages the
# pinned ShellCheck and actionlint on. Rather than change that daemon, the lint
# entry points prefer one managed per-user directory the daemon can
# already reach through its home directory, and bin/fm-install-lint-tools.sh
# provisions it with the same checksum-pinned builds CI installs.
#
# Functions:
#   fm_lint_tools_dir            print the managed directory: $FM_LINT_TOOLS_DIR,
#                                else ${XDG_CACHE_HOME:-$HOME/.cache}/firstmate/lint-tools;
#                                returns 1 when neither an override nor a home exists
#   fm_lint_tool_version <name> <path>
#                                print the version the tool at <path> reports
#   fm_lint_tool_resolve <name> <pin>
#                                print the tool to use: the managed copy when
#                                it reports <pin>, else the search-path tool,
#                                else the managed copy (so an off-pin build is
#                                named in the refusal); returns 1 when neither
#                                has it
#
# The pinned version is enforced by each lint entry point after resolution, so a
# wrong build found in either place is refused rather than silently used. The
# managed pinned copy wins over an off-pin tool on the search path.

fm_lint_tools_dir() {
  if [ -n "${FM_LINT_TOOLS_DIR:-}" ]; then
    printf '%s\n' "$FM_LINT_TOOLS_DIR"
  elif [ -n "${XDG_CACHE_HOME:-}" ]; then
    printf '%s\n' "$XDG_CACHE_HOME/firstmate/lint-tools"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.cache/firstmate/lint-tools"
  else
    return 1
  fi
}

fm_lint_tool_version() {
  case $1 in
    shellcheck) "$2" --version 2>/dev/null | awk '/^version:/ {print $2; exit}' ;;
    *) "$2" -version 2>/dev/null | awk 'NR==1 {print; exit}' ;;
  esac
}

fm_lint_tool_resolve() {
  local name=$1 pin=$2 managed= found
  local dir
  if dir=$(fm_lint_tools_dir) && [ -f "$dir/$name" ] && [ -x "$dir/$name" ]; then
    managed=$dir/$name
    if [ "$(fm_lint_tool_version "$name" "$managed")" = "$pin" ]; then
      printf '%s\n' "$managed"
      return 0
    fi
  fi
  if found=$(command -v "$name" 2>/dev/null) && [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  if [ -n "$managed" ]; then
    printf '%s\n' "$managed"
    return 0
  fi
  return 1
}
