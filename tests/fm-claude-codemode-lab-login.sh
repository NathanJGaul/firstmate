#!/usr/bin/env bash
# Prepares the THROWAWAY Claude config directory that
# tests/fm-claude-codemode-live-e2e.test.sh runs against. Run it by hand, once,
# in a real terminal (it is interactive: a browser sign-in, then one short
# interactive Claude session):
#
#   tests/fm-claude-codemode-lab-login.sh [<lab-config-dir>]
#
# The default directory is ~/.cache/fm-codemode-lab/config. The script signs in
# ONLY that directory, by pointing CLAUDE_CONFIG_DIR at it for every step. It
# never reads, copies, or writes the real ~/.claude or the invoking
# CLAUDE_CONFIG_DIR, and it refuses either as the lab directory. The only file
# it reads back is the lab directory's own acceptance key.
#
# Three things need a person, because Firstmate's key plane cannot answer them
# and the live guard must never manufacture a consent:
#   1. the browser sign-in (claude auth login),
#   2. the first-run onboarding and the once-per-machine bypass-permissions
#      confirmation, and
#   3. the Code Mode confirmation, whose cursor starts on "No, start without it"
#      (choose "Yes").
# Steps 2 and 3 happen in the one interactive session the script opens; exit it
# with /exit once the Code Mode banner shows.
set -eu

LAB=${1:-$HOME/.cache/fm-codemode-lab/config}
case "$LAB" in
/*) ;;
*)
  echo "error: the lab config directory must be an absolute path, got '$LAB'" >&2
  exit 1
  ;;
esac
real_of() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
# Refuse a real store before any filesystem change is made.
for forbidden in "$HOME" "$HOME/.claude" "${CLAUDE_CONFIG_DIR:-}"; do
  [ -n "$forbidden" ] || continue
  if [ "$(real_of "$LAB")" = "$(real_of "$forbidden")" ]; then
    echo "error: '$LAB' is a real Claude store or home directory, not a throwaway lab directory" >&2
    exit 1
  fi
done
mkdir -p "$LAB"
chmod 700 "$LAB"
LAB_REAL=$(cd "$LAB" && pwd -P)

printf 'fm-codemode-lab\n' >"$LAB_REAL/.fm-codemode-lab"
run_claude() {
  env -u CLAUDECODE -u ANTHROPIC_API_KEY -u CLAUDE_CODE_OAUTH_TOKEN \
    CLAUDE_CONFIG_DIR="$LAB_REAL" "$@"
}

echo "== step 1 of 2: browser sign-in, into $LAB_REAL only"
run_claude claude auth login
run_claude claude auth status >/dev/null || {
  echo "error: the lab directory is not signed in after the login" >&2
  exit 1
}

echo
echo "== step 2 of 2: one interactive session in Code Mode"
echo "Answer the onboarding and the bypass-permissions confirmation, choose Yes on the"
echo "Code Mode confirmation, wait for the Code Mode banner, then type /exit."
run_claude env CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1 claude --model haiku --dangerously-skip-permissions || true

if ! jq -e '.codeModeCaveatsAcceptedV1 == true' "$LAB_REAL/.claude.json" >/dev/null 2>&1; then
  echo "error: the Code Mode confirmation was not accepted in $LAB_REAL; run this script again and choose Yes" >&2
  exit 1
fi
echo "ready: $LAB_REAL is signed in and has accepted the Code Mode confirmation"
