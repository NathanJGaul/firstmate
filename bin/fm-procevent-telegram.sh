#!/usr/bin/env bash
# Outbound Telegram long-poll adapter for bin/fm-procevent.sh.
#
# Usage:
#   fm-procevent-telegram.sh poll
#   fm-procevent-telegram.sh source-id
#   fm-procevent-telegram.sh classify <result-file>
#   fm-procevent-telegram.sh silent <result-file>
#   fm-procevent-telegram.sh terminal <result-file>
#
# Poll output is a bounded result document. The generic process-event runner owns
# isolation, durable capture, wake publication, and restart recovery.
set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TELEGRAM="$SCRIPT_DIR/fm-telegram.py"

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

result_field() {
  local file=$1 field=$2
  awk -v prefix="$field=" '$0 == "" { exit } index($0, prefix) == 1 { count++; value=substr($0, length(prefix)+1) } END { if (count != 1) exit 1; print value }' "$file"
}

validate_result() {
  local file=$1 schema status
  schema=$(result_field "$file" schema 2>/dev/null || true)
  status=$(result_field "$file" status 2>/dev/null || true)
  [ "$schema" = fm-telegram-result.v1 ] || return 1
  case "$status" in
    ok|error) printf '%s\n' "$status" ;;
    *) return 1 ;;
  esac
}

cmd_poll() {
  [ "$#" -eq 0 ] || usage
  exec "$TELEGRAM" poll --once --event
}

cmd_classify() {
  local file=${1-} status
  [ -f "$file" ] && [ ! -L "$file" ] || die "result file does not exist: ${file-}"
  status=$(validate_result "$file" 2>/dev/null) || { printf 'error\n'; return 0; }
  printf '%s\n' "$status"
}

cmd_silent() {
  local file=${1-} status
  [ -f "$file" ] && [ ! -L "$file" ] || die "result file does not exist: ${file-}"
  status=$(validate_result "$file" 2>/dev/null) || return 1
  [ "$status" = ok ]
}

cmd_terminal() {
  local file=${1-}
  [ -f "$file" ] && [ ! -L "$file" ] || die "result file does not exist: ${file-}"
  return 1
}

case "${1-}" in
  poll) shift; cmd_poll "$@" ;;
  source-id) [ "$#" -eq 1 ] || usage; printf 'telegram-bot\n' ;;
  classify) shift; [ "$#" -eq 1 ] || usage; cmd_classify "$@" ;;
  silent) shift; [ "$#" -eq 1 ] || usage; cmd_silent "$@" ;;
  terminal) shift; [ "$#" -eq 1 ] || usage; cmd_terminal "$@" ;;
  '') usage ;;
  -h|--help|help) usage ;;
  *) die "unknown command: $1" ;;
esac
