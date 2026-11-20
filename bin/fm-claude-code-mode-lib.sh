#!/usr/bin/env bash
# fm-claude-code-mode-lib.sh - the single owner of the Code Mode pilot's two
# mechanics: how config/claude-code-mode is parsed, and how the first-run
# confirmation dialog's acceptance is read from the Claude config store.
#
# docs/configuration.md "Claude Code Mode" owns the operator-facing contract.
# Sourced by bin/fm-spawn.sh, which owns the launch-line splice.
#
# Code Mode is Claude Code's experimental mode in which the model writes
# JavaScript that calls the session's tools. It is switched on only by
# CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1 in an interactive session, and only on
# Claude Code 2.1.323 or later (an older client silently ignores the variable).
# Its first launch per Claude config directory shows a confirmation dialog whose
# cursor sits on "No, start without it"; Firstmate's key plane cannot select
# "Yes", a decline is not remembered, and a worker would sit on it unseen. A
# person accepts it once, and Claude Code stores the answer as
# codeModeCaveatsAcceptedV1 in <config dir>/.claude.json.
#
# Neither function here ever writes: the acceptance is a human consent, so
# Firstmate only reads it, exactly as bin/fm-claude-trust.sh refuses to
# manufacture the external-imports consent.

# fm_claude_code_mode_setting <config-dir>
# Prints `off` (absent file) or the file's whitespace-trimmed token, which must
# be `off` or `scouts`. A directory, an unreadable file, or any other token
# prints the refusal to stderr and returns 1.
fm_claude_code_mode_setting() {
  local file=$1/claude-code-mode token
  [ -e "$file" ] || [ -L "$file" ] || {
    printf 'off\n'
    return 0
  }
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: config/claude-code-mode must be a readable regular file holding one of: off, scouts" >&2
    return 1
  fi
  token=$(tr -d '[:space:]' <"$file" || true)
  case "$token" in
  off | scouts) printf '%s\n' "$token" ;;
  *)
    echo "error: config/claude-code-mode holds '$token'; accepted values are: off (Code Mode never starts, the default when the file is absent), scouts (scout launches start in Code Mode where the config directory has accepted its confirmation)" >&2
    return 1
    ;;
  esac
}

# fm_claude_code_mode_accepted <config-dir>
# Returns 0 only when <config-dir>/.claude.json is a readable JSON object whose
# codeModeCaveatsAcceptedV1 is the boolean true. An absent, unreadable, or
# unparsable store, or any other value, is not accepted.
fm_claude_code_mode_accepted() {
  local store=$1/.claude.json
  [ -f "$store" ] && [ -r "$store" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e 'type == "object" and .codeModeCaveatsAcceptedV1 == true' "$store" >/dev/null 2>&1
}
