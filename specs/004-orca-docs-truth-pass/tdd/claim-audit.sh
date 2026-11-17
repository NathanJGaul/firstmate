#!/usr/bin/env bash
# claim-audit.sh - the claim audit for specs/004-orca-docs-truth-pass.
#
# Feature evidence, not a repository test: it is not registered in tests/, is not
# run by CI, and pins behaviors of this one documentation change (see
# research.md R5). Each behavior id on tdd/test-list.md has one function here.
#
# Usage: specs/004-orca-docs-truth-pass/tdd/claim-audit.sh <id>... | all
#   ids: A1 to A16 (acceptance), U1 to U32 (unit); an A id runs its units too.
# Env:   BASE=<ref> the base commit that "changed" is measured from
#        (default: the merge base of HEAD and origin/main).
# Exit:  0 when every selected check passes, 1 when any fails, 2 on misuse.
# Needs: git and a grep with PCRE lookahead support (-P).
set -u

ROOT=$(git rev-parse --show-toplevel) || exit 2
cd "$ROOT" || exit 2
BASE=${BASE:-$(git merge-base HEAD origin/main 2>/dev/null || echo main)}

O=docs/orca-backend.md
AC=docs/agent-control.md
RB=docs/verification/runtime-backends.md
CT=bin/fm-claude-trust.sh
SK=.agents/skills/stuck-crewmate-recovery/SKILL.md
FEATURE=specs/004-orca-docs-truth-pass

fails=0
checks=0

# body <file>[#<second-level heading>]: the file, or one "## " section of it.
body() {
  local f=${1%%#*} h=''
  case "$1" in *'#'*) h=${1#*#} ;; esac
  if [ -n "$h" ]; then
    awk -v h="## $h" '$0 == h { p = 1; next } /^## / { p = 0 } p' "$f"
  else
    cat "$f"
  fi
}

# has_line <src> <term>...: some single line of <src> matches every PCRE term.
has_line() {
  local src=$1 re='' t
  shift
  for t in "$@"; do re="$re(?=.*$t)"; done
  body "$src" | grep -Pq "^${re}"
}

# ok <id> <description> <command...>: run the command, print and count the result.
ok() {
  local id=$1 desc=$2
  shift 2
  checks=$((checks + 1))
  if "$@"; then
    printf 'ok   %-4s %s\n' "$id" "$desc"
  else
    printf 'FAIL %-4s %s\n' "$id" "$desc"
    fails=$((fails + 1))
  fi
}
yes_line() { ok "$1" "$2" has_line "${@:3}"; }
absent() { ! has_line "$@"; }
not_line() { ok "$1" "$2" absent "${@:3}"; }

added() { git diff "$BASE" -- "$1" | grep -E '^\+[^+]' | sed 's/^+//'; }
removed() { git diff "$BASE" -- "$1" | grep -E '^-[^-]' | sed 's/^-//'; }
count() { grep -c '' || true; }

# --- stale statements (contract C1), each worded as the shape that must be gone ---
stale_orca_doc() {
  not_line S1 "$O no longer calls Orca macOS-only or an experimental macOS backend" "$O" 'Orca is (an experimental )?macOS'
  not_line S2 "$O no longer says to open the Orca app to watch a terminal" "$O" 'Open the Orca app to watch'
  not_line S3 "$O no longer says there is no CLI version marker" "$O" '(?i)no stable CLI version'
  not_line S4 "$O no longer says there is no native busy signal" "$O" '(?i)no native Orca busy signal'
  not_line S5 "$O no longer says Escape is the unsupported key" "$O" 'Escape is (not|unsupported)'
  not_line S7 "$O no longer calls the worktree shape unverified" "$O" '(?i)worktree shape is unverified'
  not_line S8 "$O no longer says only result.terminal is verified" "$O" '(?i)(reuses only the verified|Only the verified terminal-handle)'
}

# --- docs/orca-backend.md ---------------------------------------------------------
u1() { yes_line U1 "$O describes Orca on macOS and on Linux" "$O" 'macOS' 'Linux'; }
u2() { yes_line U2 "$O names the headless runtime and readiness, not the desktop app" "$O" '(?i)headless' '(?i)desktop' '(?i)ready|readiness'; }
u3() {
  yes_line U3 "$O keeps the macOS app path, labeled macOS" "$O" 'macOS' '/Applications/Orca\.app'
  yes_line U3 "$O keeps the Homebrew install, labeled macOS" "$O" 'macOS' 'brew install orca'
}
u4() { yes_line U4 "$O says the CLI must be on the PATH of the firstmate shell" "$O" '\bPATH\b' '\borca\b'; }
u5() { yes_line U5 "$O points headless operators at fm-peek" "$O" '(?i)headless' 'fm-peek'; }
u6() {
  yes_line U6 "$O names orca --version" "$O" 'orca --version'
  yes_line U6 "$O says status reports capabilities" "$O" '(?i)capabilit' 'status'
}
u7() {
  yes_line U7 "$O says Orca exposes native agent state" "$O" '(?i)native' '(?i)agent[ -]state'
  yes_line U7 "$O says firstmate does not use the native signal" "$O" '(?i)native' '(?i)not use'
}
u8() { yes_line U8 "$O says the adapter delivers Enter and Ctrl+C but not Escape or Ctrl+U" "$O" 'Enter' 'Ctrl.C' 'Escape' 'Ctrl\+U'; }
u9() {
  yes_line U9 "$O attributes the missing keys to the adapter" "$O" 'Escape' '(?i)adapter'
  yes_line U9 "$O says the passthrough is not exercised live" "$O" '(?i)(not|never)( yet)?( been)? exercised' '(?i)live'
}
u10() { yes_line U10 "$O says Orca worktrees are linked and the trust check accepts them" "$O" '(?i)linked' '(?i)trust' '(?i)accept'; }
u11() { yes_line U11 "$O says startupTerminal is not adopted and firstmate creates its own terminal" "$O" 'startupTerminal' '(?i)(not|never) adopt' '(?i)creat'; }
u12() {
  yes_line U12 "$O puts long or high-value ships on Herdr" "$O" 'Herdr' '(?i)high-value' '(?i)ship'
  yes_line U12 "$O keeps scouts and short ships on Orca" "$O" '(?i)scout' '(?i)short'
}
u13() {
  yes_line U13 "$O says a folder-registered project, including firstmate, cannot host Orca work" "$O" '(?i)folder' '(?i)firstmate repo' '(?i)cannot host'
  yes_line U13 "$O names the per-task backend override" "$O" '--backend' '(?i)per-task|override'
}
u14() {
  yes_line U14 "$O says away and quiet modes are refused" "$O" '(?i)away' '(?i)quiet' '(?i)refus'
  yes_line U14 "$O says the primary needs Herdr or tmux" "$O" '(?i)primary' 'Herdr' 'tmux'
}
u15() { yes_line U15 "$O says interrupt, exit, and relaunch refuse on Orca" "$O" 'interrupt' '\bexit\b' 'relaunch' '(?i)refus'; }
u16() { stale_orca_doc; }
u17() {
  yes_line U17 "$O keeps secondmate spawns unsupported" "$O" '(?i)secondmate' '(?i)unsupported|not support'
  yes_line U17 "$O keeps explicit-only selection" "$O" '(?i)explicit-only|never auto-detected'
  yes_line U17 "$O keeps the never-raw-delete cleanup rule" "$O" '(?i)never raw-deletes'
}

# --- docs/agent-control.md --------------------------------------------------------
u18() { not_line U18 "$AC no longer says Orca's API exposes only an interrupt and an Enter" "$AC" '(?i)exposes only an interrupt and an Enter'; }
u19() {
  yes_line U19 "$AC says the adapter does not deliver Escape or Ctrl+U today" "$AC" '(?i)adapter' 'Escape' 'Ctrl\+U' '(?i)(not|does not) deliver'
  yes_line U19 "$AC points at the Orca backend document" "$AC" 'orca-backend\.md'
}
u20() {
  yes_line U20 "$AC keeps the recovery-grade classifier requirement" "$AC" 'recovery-grade agent-state classifier'
  yes_line U20 "$AC keeps zellij, orca, and cmux refused for exit and relaunch" "$AC" 'zellij, orca, and cmux are refused'
}
u21() { ok U21 "$AC keeps the Orca capability matrix row byte-identical" grep -Fxq '| orca | no | yes | yes | no | no |' "$AC"; }

# --- the recovery skill -----------------------------------------------------------
skill_one_line() {
  [ "$(added "$SK" | count)" -eq 1 ] && [ "$(removed "$SK" | count)" -eq 0 ] \
    && added "$SK" | grep -Pq '^(?=.*(?i:orca))(?=.*interrupt)(?=.*\bexit\b)(?=.*relaunch)(?=.*(?i:refus))'
}
u22() { ok U22 "$SK gains exactly one added line saying interrupt, exit, and relaunch refuse on Orca" skill_one_line; }

# --- docs/verification/runtime-backends.md, Orca section --------------------------
rb="$RB#Orca"
u24() {
  yes_line U24 "Orca section labels the existing evidence macOS 1.4.116" "$rb" 'macOS' '1\.4\.116'
  yes_line U24 "Orca section keeps the response-shape evidence" "$rb" 'result\.terminal\.handle'
}
u25() {
  yes_line U25 "Orca section has a dated Linux 1.4.261 entry" "$rb" 'Linux' '1\.4\.261' '2026-11-17'
  yes_line U25 "Orca section records orca --version" "$rb" 'orca --version'
  yes_line U25 "Orca section records the headless install mode" "$rb" 'unsupported-headless-serve'
}
u26() {
  yes_line U26 "Orca section records the linked-worktree shape" "$rb" '(?i)linked' '(?i)worktree'
  yes_line U26 "Orca section records the startupTerminal response shape" "$rb" 'startupTerminal'
  yes_line U26 "Orca section records the native agent-state surfaces" "$rb" 'worktree ps'
  yes_line U26 "Orca section records the folder-registered repository kind" "$rb" '(?i)folder' 'kind'
}
u27() { yes_line U27 "Orca section marks Escape passthrough not exercised live" "$rb" 'Escape' '(?i)not exercised'; }
u28() {
  yes_line U28 "Orca section names the fake-Orca regression suite" "$rb" 'tests/fm-backend-orca\.test\.sh'
  yes_line U28 "Orca section says no live Orca lane exists" "$rb" '(?i)no live' '(?i)orca'
}

# --- bin/fm-claude-trust.sh, comment text only ------------------------------------
stale_trust() {
  not_line S9 "$CT no longer calls Orca's worktree shape UNVERIFIED" "$CT" 'UNVERIFIED' '(?i)orca'
  not_line S9 "$CT no longer calls Orca macOS-only" "$CT" '(?i)macOS-only'
  not_line S9 "$CT no longer says Orca was not installed where it was written" "$CT" '(?i)not installed'
}
u29() {
  yes_line U29 "$CT says Orca's CLI-created worktrees are linked" "$CT" '(?i)orca' '(?i)linked' '(?i)(verified|observed)'
  yes_line U29 "$CT points at the verification record" "$CT" 'runtime-backends\.md'
}
u30() { yes_line U30 "$CT says a folder-registered project has no git worktree for the structural test" "$CT" '(?i)folder' '(?i)worktree'; }
u31() { yes_line U31 "$CT keeps the structural-not-path-prefix rationale" "$CT" '(?i)structural' '(?i)path prefix'; }
trust_comment_only() { [ -z "$(git diff "$BASE" -- "$CT" | grep -E '^[+-][^+-]' | grep -Ev '^[+-][[:space:]]*(#|$)')" ]; }
u32() { ok U32 "$CT changed comment lines only" trust_comment_only; }

# --- cross-cutting ----------------------------------------------------------------
allowed_files() {
  local f bad=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      "$O" | "$AC" | "$RB" | "$CT" | "$SK" | docs/documentation-audiences.json | "$FEATURE"/*) ;;
      *) printf '  unexpected changed file: %s\n' "$f"; bad=1 ;;
    esac
  done < <({ git diff --name-only "$BASE"; git ls-files --others --exclude-standard; } | sort -u)
  [ "$bad" -eq 0 ]
}
style_ok() {
  local f bad=0 line
  for f in "$O" "$AC" "$RB" "$SK"; do
    while IFS= read -r line; do
      case "$line" in *—*) printf '  em dash added in %s: %s\n' "$f" "$line"; bad=1 ;; esac
      case "$line" in '|'*) continue ;; esac
      if printf '%s\n' "$line" | grep -Eq '[a-z0-9)`][.!?]  *[A-Z]'; then
        printf '  two sentences on one line in %s: %s\n' "$f" "$line"; bad=1
      fi
    done < <(added "$f")
  done
  while IFS= read -r f; do
    if grep -q '—' "$f"; then printf '  em dash in %s\n' "$f"; bad=1; fi
  done < <(find "$FEATURE" -name '*.md')
  [ "$bad" -eq 0 ]
}
a15() { ok A15 "only the five named files, the inventory, and the feature artifacts changed" allowed_files; }
a16() { ok A16 "changed Markdown has one sentence per line and no em dash" style_ok; }

# --- acceptance behaviors: each runs the units that serve it ----------------------
a1() { u1; u2; u3; u4; u5; not_line S1 "$O not macOS-only" "$O" 'Orca is (an experimental )?macOS'; not_line S2 "$O no open-the-app instruction" "$O" 'Open the Orca app to watch'; }
a2() { u6; not_line S3 "$O no missing-version claim" "$O" '(?i)no stable CLI version'; }
a3() { u7; not_line S4 "$O no missing-busy-signal claim" "$O" '(?i)no native Orca busy signal'; }
a4() { u8; u9; not_line S5 "$O Escape not the unsupported key" "$O" 'Escape is (not|unsupported)'; }
a5() { u10; not_line S7 "$O worktree shape not unverified" "$O" '(?i)worktree shape is unverified'; }
a6() { u11; not_line S8 "$O not only result.terminal verified" "$O" '(?i)(reuses only the verified|Only the verified terminal-handle)'; }
a7() { u12; u13; u14; u15; }
a8() { u18; u19; }
a9() { u20; u21; }
a10() { u22; }
a11() { u24; }
a12() { u25; u26; u27; u28; }
a13() { u29; u30; u31; stale_trust; }
a14() { u32; }

run_id() {
  case "$1" in
    A[1-9] | A1[0-6] | U[1-9] | U[1-3][0-9]) "$(printf '%s' "$1" | tr 'AU' 'au')" ;;
    all)
      local i
      for i in $(seq 1 16); do run_id "A$i"; done
      run_id U16
      run_id U17
      ;;
    *) printf 'unknown behavior id: %s\n' "$1" >&2; exit 2 ;;
  esac
}

[ "$#" -gt 0 ] || { printf 'usage: %s <id>... | all\n' "$0" >&2; exit 2; }
for id in "$@"; do
  run_id "$id"
done
printf 'claim-audit: %d checks, %d failed (base %s)\n' "$checks" "$fails" "$(git rev-parse --short "$BASE")"
[ "$fails" -eq 0 ]
