#!/usr/bin/env bash
# fm-lint-tools-lib.sh - single owner of where firstmate's pinned lint tools live.
#
# Sourced by bin/fm-lint.sh, bin/fm-lint-workflows.sh, and the pinned
# installers. The shared no-mistakes daemon runs commands.lint with its own
# fixed search path, which never includes the PATH a worker or CI stages the
# pinned ShellCheck and actionlint on. Rather than change that daemon, the lint
# entry points fall back to one managed per-user directory the daemon can
# already reach through its home directory, and bin/fm-install-lint-tools.sh
# provisions it with the same checksum-pinned builds CI installs.
#
# Functions:
#   fm_lint_tools_dir            print the managed directory: $FM_LINT_TOOLS_DIR,
#                                else ${XDG_CACHE_HOME:-$HOME/.cache}/firstmate/lint-tools;
#                                returns 1 when neither an override nor a home exists
#   fm_lint_tool_resolve <name>  print the tool to use: the search path first,
#                                then an executable file in the managed
#                                directory; returns 1 when neither has it
#
# The pinned version is enforced by each lint entry point after resolution, so a
# wrong build found in either place is refused rather than silently used.

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

fm_lint_tool_resolve() {
  local name=$1 found dir
  if found=$(command -v "$name" 2>/dev/null) && [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  dir=$(fm_lint_tools_dir) || return 1
  if [ -f "$dir/$name" ] && [ -x "$dir/$name" ]; then
    printf '%s\n' "$dir/$name"
    return 0
  fi
  return 1
}
