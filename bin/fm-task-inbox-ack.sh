#!/usr/bin/env bash
set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/fm-task-inbox-lib.sh"

[ "$#" -eq 3 ] || {
  echo "usage: fm-task-inbox-ack.sh <state-dir> <task-id> <record-name>" >&2
  exit 2
}
fm_task_inbox_ack "$1" "$2" "$3"
