#!/usr/bin/env bash
# bin/backends/orca.sh - the Orca terminal session-provider adapter.
#
# Orca owns both the task worktree and the terminal endpoint. Escape and Ctrl+U
# are delivered as raw control bytes through `terminal send` without --enter,
# which Orca writes to the terminal verbatim, gated on the runtime's reported
# capability (fm_backend_orca_control_bytes_ready).
#
# Text sends use Orca's delivery receipts when the runtime lists the
# terminal.prompt-delivery.v1 capability: one `terminal send --enter
# --wait-submit`, replayed by request id, with the composer as the last word.
# A terminal the runtime says cannot take input is reported as terminal-gone
# (verdict on stdout, exit 1). An agent parked on a permission or trust prompt is
# refused by the runtime (agent_prompt_blocked) and reported as prompt-blocked
# the same way: nothing is typed, replayed, or Entered. Without the capability the verified literal-send
# and Enter loop runs unchanged. See fm_backend_orca_send_text_submit.
#
# A task whose agent died or whose terminal is gone is reclaimed by closing the
# dead terminal and creating one fresh terminal by the recorded worktree id
# (fm_backend_orca_reclaim_terminal); a wedged agent is stopped by closing its
# terminal, and the close receipt (fm_backend_orca_close_terminal) is the stop
# proof. Nothing here ever removes a worktree.
#
# Target string shape: the Orca terminal id accepted by `orca terminal ...`.

# Shared composer-content classifier (empty|pending|unknown, and the fleet-wide
# dead-shell-vs-agent-composer rule). Owned by bin/fm-composer-lib.sh, reused by
# every backend so the decision cannot drift.
# shellcheck source=bin/fm-composer-lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../fm-composer-lib.sh"

# Backend-neutral harness-process identity (agent|shell|other), the same
# classifier the tmux and Herdr adapters use, so a harness one backend reads as
# alive can never read as an agent-free pane on another. Owned by
# bin/fm-agent-process-lib.sh; the Orca process classifier below is its caller.
# shellcheck source=bin/fm-agent-process-lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../fm-agent-process-lib.sh"

# fm_backend_orca_tool_check: make the `orca` CLI runnable by name, or refuse.
# Orca's own terminals put its CLI shim directory on PATH, but a restarted
# primary, a daemon, or a worker usually runs outside one, so the CLI is looked
# for in order: PATH, then $ORCA_CLI_BIN_DIR (the variable Orca's terminals
# export), then ~/.orca/cli/bin (where the Linux headless runtime writes its
# shim). A hit off PATH is prepended to this shell's PATH so every later bare
# `orca` call in the same shell uses it; an entry point that runs this inside a
# command substitution must therefore call it again in its own shell.
fm_backend_orca_tool_check() {
  local dir
  command -v orca >/dev/null 2>&1 && return 0
  for dir in "${ORCA_CLI_BIN_DIR:-}" "${HOME:+$HOME/.orca/cli/bin}"; do
    [ -n "$dir" ] && [ -f "$dir/orca" ] && [ -x "$dir/orca" ] || continue
    PATH="$dir${PATH:+:$PATH}"
    return 0
  done
  echo "error: backend=orca selected but the 'orca' CLI is not installed or not reachable: it is not on PATH, not in \$ORCA_CLI_BIN_DIR (${ORCA_CLI_BIN_DIR:-unset}), and not in ~/.orca/cli/bin. Install Orca and start it once so it writes its CLI shim, then put ~/.orca/cli/bin on PATH or export ORCA_CLI_BIN_DIR" >&2
  return 1
}

# The lowest Orca runtime this adapter is proven against, and the capability
# its status reports on every runtime that delivered raw control bytes in the
# live lab (tests/fm-backend-orca-smoke.test.sh, docs/verification/runtime-backends.md).
# Orca names no capability for control-byte passthrough itself, so
# terminal.ordered-input.v1 (ordered terminal input) is the closest marker the
# lab saw; a runtime that does not report it keeps today's behavior and does
# not receive Escape or Ctrl+U.
FM_ORCA_MIN_APP_VERSION=1.4.261
FM_ORCA_CONTROL_BYTES_CAPABILITY=terminal.ordered-input.v1

# Facts fm_backend_orca_status_read records for the calling shell: the
# appVersion exactly as reported (empty when none), the space-separated
# capability list, and 1 when a readable appVersion is below the floor.
FM_ORCA_APP_VERSION=
FM_ORCA_CAPABILITIES=
FM_ORCA_BELOW_FLOOR=0

# fm_backend_orca_status_read: read `orca status --json` once, require a ready
# and reachable runtime, and record the version and capability facts above.
# It does not enforce the floor; callers decide what a missing capability or an
# old version means. It sets variables, so call it directly, never inside a
# command substitution whose result the caller needs.
fm_backend_orca_status_read() {
  fm_backend_orca_tool_check || return 1
  local out facts
  out=$(orca status --json 2>/dev/null) || {
    echo "error: backend=orca selected but 'orca status --json' failed; start Orca and wait for the runtime to be ready" >&2
    return 1
  }
  # shellcheck disable=SC2016  # Single quotes are deliberate: ${...} belongs to the Node snippet.
  facts=$(printf '%s' "$out" | node -e '
const fs = require("fs");
let data;
try {
  data = JSON.parse(fs.readFileSync(0, "utf8"));
} catch (err) {
  console.error("error: invalid Orca status JSON: " + err.message);
  process.exit(1);
}
if (data.ok === false) {
  const msg = data.error && (data.error.message || data.error.code);
  console.error("error: Orca runtime is not ready" + (msg ? ": " + msg : ""));
  process.exit(1);
}
const r = data.result || {};
const runtime = r.runtime || {};
const reachable = runtime.reachable ?? r.runtimeReachable;
const state = runtime.state || r.runtimeState || "";
if (!(reachable === true && state === "ready")) {
  console.error(`error: backend=orca requires a ready Orca runtime (reachable=${String(reachable)}, state=${state || "unknown"})`);
  process.exit(1);
}
const version = String(runtime.appVersion ?? r.appVersion ?? "");
const caps = Array.isArray(runtime.capabilities ?? r.capabilities)
  ? (runtime.capabilities ?? r.capabilities).filter((c) => typeof c === "string" && c && !/\s/.test(c)) : [];
const parse = (v) => { const m = /^v?(\d+)\.(\d+)\.(\d+)/.exec(v); return m ? [+m[1], +m[2], +m[3]] : null; };
const have = parse(version);
const floor = parse(process.argv[1]);
let below = 0;
if (have && floor) {
  for (let i = 0; i < 3; i++) {
    if (have[i] !== floor[i]) { below = have[i] < floor[i] ? 1 : 0; break; }
  }
}
process.stdout.write(version.replace(/[\r\n]/g, " ") + "\n" + caps.join(" ") + "\n" + below + "\n");
' "$FM_ORCA_MIN_APP_VERSION") || return 1
  {
    IFS= read -r FM_ORCA_APP_VERSION
    IFS= read -r FM_ORCA_CAPABILITIES
    IFS= read -r FM_ORCA_BELOW_FLOOR
  } <<<"$facts"
  return 0
}

# fm_backend_orca_runtime_check: the spawn-time gate. The runtime must be ready,
# and a runtime that reports a version below the tested floor is refused. A
# runtime that reports no readable version is not refused, because nothing
# proves it old, but it then reports no capability either, so no capability
# gated feature is enabled for it.
fm_backend_orca_runtime_check() {
  fm_backend_orca_status_read || return 1
  if [ "$FM_ORCA_BELOW_FLOOR" = 1 ]; then
    echo "error: backend=orca requires Orca $FM_ORCA_MIN_APP_VERSION or newer, the lowest runtime proven against this adapter, but the runtime reports appVersion=$FM_ORCA_APP_VERSION. Update Orca, or run this task on another backend with the per-task option --backend <name>" >&2
    return 1
  fi
}

# fm_backend_orca_control_bytes_ready: whether this runtime may be sent a raw
# control byte (Escape, Ctrl+U). Reads the status fresh on every call, so a
# long-lived caller never acts on a stale capability list. Refuses, naming the
# capability and the version, when the status cannot be read or does not report
# the capability, so the caller sends nothing.
fm_backend_orca_control_bytes_ready() {  # <key-name>
  local key=$1
  fm_backend_orca_status_read || return 1
  case " $FM_ORCA_CAPABILITIES " in
    *" $FM_ORCA_CONTROL_BYTES_CAPABILITY "*) return 0 ;;
  esac
  echo "error: cannot send $key to Orca: the runtime (appVersion=${FM_ORCA_APP_VERSION:-unknown}) does not report the $FM_ORCA_CONTROL_BYTES_CAPABILITY capability that Escape and Ctrl+U delivery is gated on; nothing was sent" >&2
  return 1
}

fm_backend_orca_json_get() {  # <field> [<worktree-id>] ; fields: worktree-id worktree-path terminal-handle worktree-terminal-handle listed-terminal-handle repo-id repo-kind
  # Terminal handles are accepted only from known terminal result shapes:
  # result.terminal or a root terminal object with .handle, plus, for
  # worktree-terminal-handle only, the result.startupTerminal that Orca 1.4.261
  # returns from worktree create (read from the runtime's response builder, so
  # proven against the fake only), taken after result.terminal and only when
  # Orca does not report it spawned:false. Undocumented result.id and
  # result.worktree.terminal shapes are ignored until a real Orca smoke run
  # proves them.
  # listed-terminal-handle reads a `terminal list --worktree` result, the shape
  # observed live on Orca 1.4.261: result.terminals[] rows. It takes the first
  # row with a string handle that is not orphaned, is not reported unwritable,
  # and, when the row names its worktree, names <worktree-id>.
  local field=$1 want_worktree=${2:-}
  node -e '
const fs = require("fs");
const field = process.argv[1];
const wantWorktree = process.argv[2] || "";
const data = JSON.parse(fs.readFileSync(0, "utf8"));
if (data.ok === false) {
  const msg = data.error && (data.error.message || data.error.code);
  if (msg) console.error(msg);
  process.exit(2);
}
const r = data.result || {};
const wt = r.worktree || r.item || r;
const explicitTerm = r.terminal || null;
const startupTerm = (r.startupTerminal && r.startupTerminal.spawned !== false) ? r.startupTerminal : null;
const repo = r.repo || r.repository || r;
function scalar(v) {
  return (typeof v === "string" || typeof v === "number") ? String(v) : "";
}
function handle(obj) {
  if (!obj) return "";
  if (typeof obj === "string" || typeof obj === "number") return String(obj);
  return scalar(obj.handle) || "";
}
let v = "";
if (field === "worktree-id") v = wt.id || wt.worktreeId || r.worktreeId || "";
if (field === "worktree-path") v = wt.path || (wt.git && wt.git.path) || r.path || "";
if (field === "terminal-handle") v = handle(explicitTerm || r) || "";
if (field === "worktree-terminal-handle") v = handle(explicitTerm) || handle(startupTerm) || "";
if (field === "listed-terminal-handle") {
  const rows = Array.isArray(r.terminals) ? r.terminals : [];
  const row = rows.find((t) => t && typeof t.handle === "string" && t.handle !== ""
    && t.orphaned !== true && t.writable !== false
    && (t.worktreeId === undefined || t.worktreeId === null || t.worktreeId === wantWorktree));
  v = row ? row.handle : "";
}
if (field === "repo-id") v = repo.id || repo.repoId || r.repoId || "";
if (field === "repo-kind") v = scalar(repo.kind);
if (!v) process.exit(1);
process.stdout.write(String(v));
' "$field" "$want_worktree"
}

fm_backend_orca_json_ok() {
  node -e '
const fs = require("fs");
const input = fs.readFileSync(0, "utf8").trim();
if (!input) process.exit(0);
let data;
try {
  data = JSON.parse(input);
} catch (err) {
  console.error("invalid Orca JSON: " + err.message);
  process.exit(2);
}
if (data.ok === false) {
  const msg = data.error && (data.error.message || data.error.code);
  if (msg) console.error(msg);
  process.exit(2);
}
'
}

fm_backend_orca_run_json() {
  local out
  out=$("$@") || return 1
  printf '%s' "$out" | fm_backend_orca_json_ok
}

fm_backend_orca_repo_ensure() {  # <project-path>
  local project=$1 out repo_id kind
  fm_backend_orca_tool_check || return 1
  out=$(orca repo show --repo "path:$project" --json 2>/dev/null || true)
  if repo_id=$(printf '%s' "$out" | fm_backend_orca_json_get repo-id 2>/dev/null); then
    # Orca registers some projects as a folder rather than a git repository, and
    # a folder cannot host the linked worktrees this backend creates. Refuse
    # before anything is created, and leave the registration as the operator set
    # it: the way out is a different backend for this one task.
    kind=$(printf '%s' "$out" | fm_backend_orca_json_get repo-kind 2>/dev/null || true)
    if [ "$kind" = folder ]; then
      echo "error: backend=orca cannot host work for $project: Orca holds it as a folder, not a git repository. Run this task on another backend with the per-task option --backend <name>; Firstmate leaves the Orca registration unchanged" >&2
      return 1
    fi
    printf '%s' "$repo_id"
    return 0
  fi
  # Orca would hold a non-git path as a folder, and adding it would change the
  # operator's registration, so refuse before the add.
  if ! git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: backend=orca cannot host work for $project: it is not a git repository, so Orca would hold it as a folder. Run this task on another backend with the per-task option --backend <name>; Firstmate leaves the Orca registration unchanged" >&2
    return 1
  fi
  out=$(orca repo add --path "$project" --json) || return 1
  repo_id=$(printf '%s' "$out" | fm_backend_orca_json_get repo-id) || {
    echo "error: orca repo add did not return a repo id for $project" >&2
    return 1
  }
  printf '%s' "$repo_id"
}

# fm_backend_orca_worktree_create: create the task's Orca worktree. An optional
# <branch> names the git branch the worktree starts on (Orca uses it exactly as
# given, with no user prefix, and gives a name that is already taken a numeric
# suffix, so the caller must read the branch back) and an optional <base-branch>
# is the ref it starts from. With neither, the call is the plain create Orca
# names its own branch for.
fm_backend_orca_worktree_create() {  # <project-path> <name> [<branch> [<base-branch>]]
  local project=$1 name=$2 branch=${3:-} base=${4:-} repo_id out wt_id wt_path terminal
  local create_args=()
  # The repo step below runs in a command substitution, so a CLI resolved there
  # would not reach this shell's own `orca worktree create`.
  fm_backend_orca_tool_check || return 1
  repo_id=$(fm_backend_orca_repo_ensure "$project") || return 1
  create_args=(--repo "id:$repo_id" --name "$name")
  [ -z "$branch" ] || create_args+=(--branch "$branch")
  [ -z "$base" ] || create_args+=(--base-branch "$base")
  out=$(orca worktree create "${create_args[@]}" --no-parent --setup skip --json) || {
    # Orca prints its refusal as JSON on stdout, which the substitution above
    # swallowed, so name the reason it gave (an unknown base ref, for one).
    printf '%s' "$out" | fm_backend_orca_json_get worktree-id >/dev/null || true
    echo "error: orca worktree create failed for $name" >&2
    return 1
  }
  wt_id=$(printf '%s' "$out" | fm_backend_orca_json_get worktree-id) || {
    echo "error: orca worktree create did not return a worktree id for $name" >&2
    return 1
  }
  terminal=$(printf '%s' "$out" | fm_backend_orca_json_get worktree-terminal-handle 2>/dev/null || true)
  # Orca 1.4.261's Linux headless runtime names no terminal in the response
  # although it already started one, so a terminal the response does not name
  # is looked for in the worktree's own terminal list before one is created.
  [ -n "$terminal" ] || terminal=$(fm_backend_orca_terminal_list_adopt "$wt_id")
  wt_path=$(printf '%s' "$out" | fm_backend_orca_json_get worktree-path) || {
    echo "error: orca worktree create did not return a path for $name" >&2
    [ -z "$terminal" ] || fm_backend_orca_kill "$terminal" >/dev/null 2>&1 || true
    if fm_backend_orca_remove_worktree "$wt_id" >/dev/null; then
      return 1
    fi
    if [ -n "$terminal" ]; then
      printf '%s\t\t%s' "$wt_id" "$terminal"
    else
      printf '%s\t' "$wt_id"
    fi
    return 2
  }
  # The terminal Orca started with the worktree is the task's one terminal, so
  # title it the way `terminal create --title` would have. The title is
  # cosmetic and the terminal is already adopted, so a failed rename never
  # fails the spawn.
  [ -z "$terminal" ] || fm_backend_orca_terminal_rename "$terminal" "$name" >/dev/null 2>&1 || true
  printf '%s\t%s' "$wt_id" "$wt_path"
  [ -z "$terminal" ] || printf '\t%s' "$terminal"
}

# fm_backend_orca_terminal_list_adopt: print the handle of the terminal Orca
# already started for <worktree-id>, or nothing. It never fails: a list that
# cannot be read means "no terminal found", so the caller creates one exactly
# as it did before this lookup existed. Only a row of this worktree's own list
# is ever returned, so a task can never adopt, title, or close another
# worktree's terminal.
fm_backend_orca_terminal_list_adopt() {  # <worktree-id>
  local worktree_id=$1 out
  out=$(orca terminal list --worktree "id:$worktree_id" --json 2>/dev/null) || return 0
  printf '%s' "$out" | fm_backend_orca_json_get listed-terminal-handle "$worktree_id" 2>/dev/null || true
}

fm_backend_orca_terminal_rename() {  # <terminal-id> <title>
  local terminal=$1 title=$2
  fm_backend_orca_tool_check || return 1
  fm_backend_orca_run_json orca terminal rename --terminal "$terminal" --title "$title" --json
}

fm_backend_orca_terminal_create() {  # <worktree-id> <title>
  local worktree_id=$1 title=$2 out terminal
  fm_backend_orca_tool_check || return 1
  out=$(orca terminal create --worktree "id:$worktree_id" --title "$title" --json) || return 1
  terminal=$(printf '%s' "$out" | fm_backend_orca_json_get terminal-handle) || {
    echo "error: orca terminal create did not return a terminal handle for $title" >&2
    return 1
  }
  printf '%s' "$terminal"
}

fm_backend_orca_send_text_line() {  # <terminal-id> <text>
  local terminal=$1 text=$2
  fm_backend_orca_tool_check || return 1
  fm_backend_orca_run_json orca terminal send --terminal "$terminal" --text "$text" --enter --json
}

fm_backend_orca_send_literal() {  # <terminal-id> <text>
  local terminal=$1 text=$2
  fm_backend_orca_tool_check || return 1
  fm_backend_orca_run_json orca terminal send --terminal "$terminal" --text "$text" --json
}

# fm_backend_orca_remove_worktree: release one Orca worktree. --force is the
# existing dirty-worktree removal; Orca documents that it never forces branch
# deletion. --delete-branch asks Orca to also delete the branch it named for
# the worktree, and Orca keeps any branch whose changes it cannot prove
# merged, so an unlanded branch is never lost. The adapter never deletes a
# branch itself and never passes a forced branch option.
fm_backend_orca_remove_worktree() {  # <worktree-id>
  local worktree_id=${1:-}
  [ -n "$worktree_id" ] || { echo "error: missing Orca worktree id; cannot remove worktree" >&2; return 1; }
  fm_backend_orca_tool_check || return 1
  fm_backend_orca_run_json orca worktree rm --worktree "id:$worktree_id" --force --delete-branch --json
}

fm_backend_orca_worktree_path() {
  local worktree_id=${1:-} out path
  [ -n "$worktree_id" ] || { echo "error: missing Orca worktree id; cannot resolve worktree path" >&2; return 1; }
  fm_backend_orca_tool_check || return 1
  out=$(orca worktree show --worktree "id:$worktree_id" --json) || return 1
  path=$(printf '%s' "$out" | fm_backend_orca_json_get worktree-path) || {
    echo "error: orca worktree show did not return a path for $worktree_id" >&2
    return 1
  }
  printf '%s' "$path"
}

fm_backend_orca_capture() {  # <terminal-id> <lines>
  local terminal=$1 lines=${2:-40} out
  fm_backend_orca_tool_check || return 1
  out=$(orca terminal read --terminal "$terminal" --limit "$lines" --json) || return 1
  fm_backend_orca_json_text "$out"
}

# fm_backend_orca_endpoint_state: one READ-ONLY presence read of a recorded
# terminal, printing exactly one of
#   present    - the runtime answered and the terminal is connected and writable.
#   missing    - the runtime positively says the terminal is gone: connected and
#                writable are both false (an exited shell or a closed terminal,
#                each with an exitCause), or it answers terminal_handle_stale for
#                a handle it does not know.
#   unreadable - anything else: no CLI, a stopped runtime, invalid JSON, another
#                error code, or a record that contradicts itself.
# It is a single `terminal show`, never a `terminal read`: `read` answers ok:true
# with status:"exited" for an exited or closed terminal, which is why the old
# presence check counted a dead terminal as alive, and it also pulls scrollback
# this check does not need. `show` carries no status field, so a `status` that
# does appear must agree with the record or the answer is unreadable. Only a
# positive answer from the runtime proves absence; a failed read never does.
# The CLI's exit status is ignored on purpose: Orca prints its ok:false JSON and
# exits 1 for a stale handle, so the JSON decides. The terminal is always named
# explicitly, so an inherited ORCA_TERMINAL_HANDLE can never redirect the read.
fm_backend_orca_endpoint_state() {  # <terminal-id>
  local terminal=$1 out verdict
  fm_backend_orca_tool_check || { printf 'unreadable'; return 0; }
  out=$(orca terminal show --terminal "$terminal" --json 2>/dev/null) || true
  verdict=$(printf '%s' "$out" | node -e '
const fs = require("fs");
const want = process.argv[1];
let data;
try {
  data = JSON.parse(fs.readFileSync(0, "utf8"));
} catch (err) {
  process.stdout.write("unreadable");
  process.exit(0);
}
function out(v) { process.stdout.write(v); process.exit(0); }
if (!data || typeof data !== "object") out("unreadable");
if (data.ok === false) {
  out(data.error && data.error.code === "terminal_handle_stale" ? "missing" : "unreadable");
}
const t = data.ok === true && data.result ? data.result.terminal : null;
if (!t || typeof t !== "object" || t.handle !== want) out("unreadable");
const status = t.status;
if (t.connected === true && t.writable === true) out(status === undefined || status === "running" ? "present" : "unreadable");
if (t.connected === false && t.writable === false) out(status === undefined || status === "exited" ? "missing" : "unreadable");
out("unreadable");
' "$terminal" 2>/dev/null) || verdict=
  case "$verdict" in
    present|missing) printf '%s' "$verdict" ;;
    *) printf 'unreadable' ;;
  esac
}

# fm_backend_orca_process_scan: one READ-ONLY scan of the local process table
# for the processes of one Orca terminal, as raw rows for
# fm_backend_orca_process_state to classify. Every process an Orca terminal
# starts carries ORCA_TERMINAL_HANDLE=<handle> in its environment (the PTY shell
# and everything below it), so the process table answers what runs in the
# terminal without asking Orca. Orca's own agent state cannot: `worktree ps`,
# `terminal show`, and `agent list|show` keep reporting an agent as present with
# its last state for as long as the terminal's shell lives, including after the
# agent was killed with SIGKILL (docs/verification/runtime-backends.md), so no
# native state is read here and no `orca` call is made.
#
# The first output line is "<status> <unreadable-count>", status being
#   ok          - the table was listed.
#   unsupported - the host has no process table at all (no /proc: macOS).
#   unreadable  - the table exists but cannot be listed.
# <unreadable-count> counts processes the scan could not place in the tree or
# classify (a stat, a command line, or an environment that failed for a reason
# other than vanishing or a refused read), which a negative verdict must not be
# built over. Each following
# line is one process as tab-separated "pid comm argv0 args", control characters
# in a field replaced by a space so one process is always one row.
#
# A process is listed when its environment holds the EXACT entry (so term_1
# never matches term_10) or when any ancestor's does: a harness launched through
# a launcher that re-executes it with a cleaned environment no longer carries the
# handle itself but still descends from the shell that does, and missing it would
# read the terminal as agent-free. The parent links come from every process's
# world-readable stat, whoever owns it, so a descendant below a process whose
# environment is hidden (a setcap helper, a sandbox) is still found; only a
# process of the current user can be a carrier, because only its environment is
# read, and the runtime's terminal processes are that user's. An own process
# whose environment is refused (EACCES or EPERM, as `systemd --user` is on a
# normal desktop) is opaque: it can be reached through the tree but cannot be
# shown to be a carrier, and is not tallied, since tallying it would make every
# negative verdict unreachable. A zombie, the scanner's own pid (a caller running
# inside the terminal being classified carries the handle too), and a process that
# vanishes while the table is read are not running processes and are dropped.
# The table location is $FM_ORCA_PROC_ROOT (default /proc) and the owning uid
# $FM_ORCA_PROC_UID (default the caller's), both only so tests can lay out a fake
# table.
fm_backend_orca_process_scan() {  # <terminal-id>
  local terminal=$1
  node -e '
const fs = require("fs");
const path = require("path");
const root = process.argv[1];
const want = "ORCA_TERMINAL_HANDLE=" + process.argv[2];
const uid = process.argv[3] === "" ? process.getuid() : Number(process.argv[3]);
const gone = (e) => e && (e.code === "ENOENT" || e.code === "ESRCH");
let names;
try {
  names = fs.readdirSync(root);
} catch (e) {
  process.stdout.write((e && e.code === "ENOENT" ? "unsupported" : "unreadable") + " 0\n");
  process.exit(0);
}
let unreadable = 0;
const procs = new Map();
const carriers = [];
const denied = (e) => e && (e.code === "EACCES" || e.code === "EPERM");
for (const n of names) {
  if (!/^[0-9]+$/.test(n)) continue;
  const pid = Number(n);
  if (pid === process.pid) continue;
  const dir = path.join(root, n);
  let st;
  try { st = fs.statSync(dir); } catch (e) { continue; }
  const own = st.uid === uid;
  let stat;
  try { stat = fs.readFileSync(path.join(dir, "stat"), "latin1"); } catch (e) { if (own && !gone(e)) unreadable++; continue; }
  const close = stat.lastIndexOf(")");
  const rest = close < 0 ? [] : stat.slice(close + 1).trim().split(/\s+/);
  const ppid = Number(rest[1]);
  if (!/^[A-Za-z]$/.test(rest[0] || "") || !Number.isInteger(ppid)) { if (own) unreadable++; continue; }
  if (rest[0] === "Z" || rest[0] === "X" || rest[0] === "x") continue;
  if (own) {
    let env = null;
    try { env = fs.readFileSync(path.join(dir, "environ")); } catch (e) {
      if (gone(e)) continue;
      if (!denied(e)) unreadable++;
    }
    if (env && env.toString("latin1").split("\0").indexOf(want) >= 0) carriers.push(pid);
  }
  procs.set(pid, { ppid, dir });
}
const children = new Map();
for (const [pid, p] of procs) {
  if (!children.has(p.ppid)) children.set(p.ppid, []);
  children.get(p.ppid).push(pid);
}
const kept = new Set(carriers);
const queue = carriers.slice();
while (queue.length) {
  for (const c of children.get(queue.shift()) || []) {
    if (!kept.has(c)) { kept.add(c); queue.push(c); }
  }
}
const clean = (s) => s.replace(/[\u0000-\u001f\u007f]/g, " ");
const rows = [];
for (const pid of Array.from(kept).sort((a, b) => a - b)) {
  const dir = procs.get(pid).dir;
  let comm, cmdline;
  try {
    comm = fs.readFileSync(path.join(dir, "comm"), "utf8").replace(/\n$/, "");
    cmdline = fs.readFileSync(path.join(dir, "cmdline"), "utf8");
  } catch (e) { if (!gone(e)) unreadable++; continue; }
  const parts = cmdline.split("\0");
  if (parts.length && parts[parts.length - 1] === "") parts.pop();
  rows.push([pid, clean(comm), clean(parts[0] || ""), clean(parts.join(" ")).slice(0, 4096)].join("\t"));
}
process.stdout.write("ok " + unreadable + "\n" + rows.map((r) => r + "\n").join(""));
' "${FM_ORCA_PROC_ROOT:-/proc}" "$terminal" "${FM_ORCA_PROC_UID:-}" 2>/dev/null
}

# fm_backend_orca_process_state_sample: one instantaneous reading of the
# terminal's processes, for fm_backend_orca_process_state, which owns the
# contract. Each listed process is classified by the shared
# fm_agent_process_classify (kernel name, argv[0], and the node-bundle harness
# rules); the Gemini rule reads a live process by pid, so the pid is passed only
# when the table is the real /proc, never for a fake one.
fm_backend_orca_process_state_sample() {  # <terminal-id>
  local out header status unreadable row pid rest comm argv0 args pidarg
  local shells=0 others=0 rows=0
  out=$(fm_backend_orca_process_scan "$1") || { printf 'unreadable'; return 0; }
  header=${out%%$'\n'*}
  status=${header%% *}
  unreadable=${header#* }
  case "$status" in
    ok) ;;
    unsupported) printf 'unsupported'; return 0 ;;
    *) printf 'unreadable'; return 0 ;;
  esac
  case "$unreadable" in ''|*[!0-9]*) printf 'unreadable'; return 0 ;; esac
  case "${FM_ORCA_PROC_ROOT:-/proc}" in /proc) pidarg=1 ;; *) pidarg= ;; esac
  case "$out" in
    *$'\n'*) rest=${out#*$'\n'} ;;
    *) rest= ;;
  esac
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    rows=$((rows + 1))
    pid=${row%%$'\t'*}
    row=${row#*$'\t'}
    comm=${row%%$'\t'*}
    row=${row#*$'\t'}
    argv0=${row%%$'\t'*}
    args=${row#*$'\t'}
    case "$(fm_agent_process_classify "$comm" "$argv0" "$args" "${pidarg:+$pid}")" in
      agent) printf 'agent'; return 0 ;;
      shell) shells=$((shells + 1)) ;;
      *) others=$((others + 1)) ;;
    esac
  done <<EOF
$rest
EOF
  # No harness was found. Positive evidence needs no further proof, but every
  # negative reading must not have been built over a process the scan could not
  # read, since that process might be the agent.
  [ "$unreadable" -eq 0 ] || { printf 'unreadable'; return 0; }
  [ "$rows" -gt 0 ] || { printf 'none'; return 0; }
  if [ "$others" -eq 0 ]; then printf 'shell'; else printf 'other'; fi
}

# fm_backend_orca_process_state: what runs in one Orca terminal on THIS host,
# from the process table alone, printed as exactly one of
#   agent       - a listed process is a verified harness.
#   shell       - at least one process was listed and every one is a shell:
#                 positive proof the terminal is agent-free.
#   other       - something was listed that is neither (an editor, a tool, a
#                 stranger's node): not a shell-only terminal.
#   none        - no process on this host carries the handle. A live local
#                 terminal always has at least its shell carrying it, so this
#                 means the runtime is not on this host or its processes are not
#                 visible, never that the terminal is empty.
#   unsupported - this host has no process table.
#   unreadable  - the table could not be listed, or a process of the current
#                 user could not be read and no harness was found.
# `other` alone is resampled for a bounded settle (FM_BACKEND_ORCA_PROCESS_SETTLE_POLLS
# samples, default 5, 0.1s apart) and the first non-`other` reading wins: an
# idle shell transiently hosts prompt helpers, the same shape the Herdr adapter
# settles. Only an exhausted window keeps `other`.
fm_backend_orca_process_state() {  # <terminal-id>
  local attempt=0 max=${FM_BACKEND_ORCA_PROCESS_SETTLE_POLLS:-5} verdict
  case "$max" in ''|*[!0-9]*) max=5 ;; esac
  while :; do
    verdict=$(fm_backend_orca_process_state_sample "$1")
    [ "$verdict" = other ] || break
    attempt=$((attempt + 1))
    [ "$attempt" -lt "$max" ] || break
    sleep 0.1
  done
  printf '%s' "$verdict"
}

# fm_backend_orca_runtime_is_local: whether the `orca` calls this adapter makes
# address the runtime on this host. The CLI addresses a paired remote runtime
# when ORCA_ENVIRONMENT, ORCA_PAIRING_CODE, or ORCA_REMOTE_PAIRING is set (the
# adapter never passes --environment), and a process table only proves anything
# about the machine it is read on. Any non-empty value counts as remote, even
# one that might name this host: a false `unverified` only declines to act.
fm_backend_orca_runtime_is_local() {
  [ -z "${ORCA_ENVIRONMENT:-}" ] && [ -z "${ORCA_PAIRING_CODE:-}" ] && [ -z "${ORCA_REMOTE_PAIRING:-}" ]
}

# fm_backend_orca_agent_state: the recovery-grade verdict for an Orca endpoint
# (the contract is fm_backend_agent_state's in bin/fm-backend.sh). Endpoint
# presence comes first and keeps its own verdicts: an authoritatively absent
# terminal is `missing` and a failed or self-contradicting read is `unreadable`,
# neither reading the process table. For a present terminal the verdict is
# proven at process level on this host only, never from Orca's native agent
# state, which keeps reporting an exited agent as present:
#   alive      - a verified harness process runs in the terminal.
#   dead       - only shells do (the terminal is present, the agent is gone).
#   ambiguous  - something runs that is neither a harness nor a shell.
#   unverified - the runtime may be on another host, this host has no process
#                table, or no local process carries the handle.
#   unreadable - the process table could not be read.
# `dead` and `missing` license recovery; this slice leaves the control plane
# refusing exit, relaunch, and reclaim (fm_control_backend_state_verified).
fm_backend_orca_agent_state() {  # <terminal-id>
  case "$(fm_backend_orca_endpoint_state "$1")" in
    present) ;;
    missing) printf 'missing'; return 0 ;;
    *) printf 'unreadable'; return 0 ;;
  esac
  fm_backend_orca_runtime_is_local || { printf 'unverified'; return 0; }
  case "$(fm_backend_orca_process_state "$1")" in
    agent) printf 'alive' ;;
    shell) printf 'dead' ;;
    other) printf 'ambiguous' ;;
    unreadable) printf 'unreadable' ;;
    *) printf 'unverified' ;;
  esac
}

fm_backend_orca_json_text() {  # <json>
  printf '%s' "$1" | node -e '
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(0, "utf8"));
if (data.ok === false) {
  const msg = data.error && (data.error.message || data.error.code);
  if (msg) console.error(msg);
  process.exit(2);
}
const r = data.result || {};
if (r.terminal && Array.isArray(r.terminal.tail)) {
  process.stdout.write(r.terminal.tail.join("\n"));
} else if (Array.isArray(r.tail)) {
  process.stdout.write(r.tail.join("\n"));
} else {
  process.stdout.write(r.text || r.output || r.content || r.preview || "");
}
'
}

# fm_backend_orca_composer_capture: the orca composer screen - one bounded
# tail read of the live terminal. Deliberately NOT the old 200-line
# backward-paged read: the composer is bottom-anchored, and paging back into
# scrollback is what let a stale startup banner (codex's bordered
# "permissions" box) compete with - and once outrank - the live composer.
fm_backend_orca_composer_capture() {  # <terminal-id> [expected-label]
  fm_backend_orca_capture "$1" "$FM_COMPOSER_CAPTURE_LINES"
}

# fm_backend_orca_composer_caps: static capability facts, not logic (see the
# capability model in bin/fm-composer-lib.sh). Orca's `terminal read` returns
# plain text; whether it can emit ANSI is unverified (orca is not installed
# on the verification machine), so styled stays 0 - the conservative
# degradation - until a live capture proves otherwise.
fm_backend_orca_composer_caps() {
  printf 'styled=0\ncursor=0\nidentity=0\nrows=%s\n' "$FM_COMPOSER_CAPTURE_LINES"
}

# fm_backend_orca_composer_state: thin adapter - capture plus capabilities in,
# shared verdict out. Every shape (bordered boxes AND the borderless bare-glyph
# row this adapter never learned, which left every claude/codex/pi/muse steer
# unconfirmed) lives in bin/fm-composer-lib.sh.
fm_backend_orca_composer_state() {  # <terminal-id> [expected-label] -> empty|pending|pending-unproven|unknown
  local cap verdict
  cap=$(fm_backend_orca_composer_capture "$1") || { printf 'unknown'; return 0; }
  verdict=$(fm_composer_classify_screen "$(fm_backend_orca_composer_caps)" "$cap")
  [ "$verdict" != need-identity ] || verdict=unknown
  printf '%s' "$verdict"
}

fm_backend_orca_send_key() {  # <terminal-id> <key>
  local terminal=$1 key=$2
  fm_backend_orca_tool_check || return 1
  case "$key" in
    C-c|ctrl+c|Ctrl-c|Ctrl-C)
      fm_backend_orca_run_json orca terminal send --terminal "$terminal" --interrupt --json
      ;;
    Enter|enter)
      fm_backend_orca_run_json orca terminal send --terminal "$terminal" --text "" --enter --json
      ;;
    # Text sent without --enter is written to the terminal verbatim, so one
    # control byte is one key press. Never --enter (it would submit) and never
    # --interrupt (that is Ctrl+C).
    Escape|escape|Esc|esc)
      fm_backend_orca_control_bytes_ready Escape || return 1
      fm_backend_orca_send_literal "$terminal" $'\x1b'
      ;;
    C-u|ctrl+u|Ctrl-u|Ctrl-U)
      fm_backend_orca_control_bytes_ready C-u || return 1
      fm_backend_orca_send_literal "$terminal" $'\x15'
      ;;
    *)
      echo "error: unsupported Orca key '$key'" >&2
      return 1
      ;;
  esac
}

# fm_backend_orca_has_capability: whether the running Orca runtime lists the
# named capability in `orca status --json` (result.runtime.capabilities, an
# array of exact names). Anything short of a positive answer - a failed call,
# invalid JSON, no list, a different name - is "not supported", so a feature
# gated on it degrades to the verified path and never fails a send. The list is
# read per call on purpose: a runtime restarted under a new version must not be
# judged by an earlier read.
fm_backend_orca_has_capability() {  # <capability>
  local out
  out=$(orca status --json 2>/dev/null) || return 1
  printf '%s' "$out" | node -e '
const fs = require("fs");
let data;
try {
  data = JSON.parse(fs.readFileSync(0, "utf8"));
} catch (err) {
  process.exit(1);
}
const caps = data && data.result && data.result.runtime && data.result.runtime.capabilities;
process.exit(Array.isArray(caps) && caps.includes(process.argv[1]) ? 0 : 1);
' "$1"
}

# fm_backend_orca_receipt_class: read one `orca terminal send --enter
# --wait-submit` answer on stdin and print "<class><TAB><detail>". The classes:
#   started      the receipt's stages include turn_started: the agent began a turn
#   accepted     input accepted by a recognized agent, no turn observed yet, and a
#                request id to replay (detail = the id)
#   unsupported  input accepted but the runtime cannot observe delivery (a plain
#                shell, an unrecognized agent, an old host, or no replayable id)
#   gone         the runtime says this endpoint cannot take input: terminal_not_writable
#                (closed, or its process exited) or terminal_handle_stale (a handle it
#                does not know). Only those two codes, both seen on Orca 1.4.261
#                (docs/verification/runtime-backends.md); detail = the code
#   blocked      the runtime refused the send because the agent is showing a
#                permission or trust prompt (agent_prompt_blocked, seen on Orca
#                1.4.261): nothing was typed, and the terminal is alive; detail = the code
#   failed       anything else, including input the runtime did not accept and an
#                answer that is not JSON (detail = the code or a short reason)
fm_backend_orca_receipt_class() {
  node -e '
const fs = require("fs");
const out = (cls, detail) => process.stdout.write(cls + "\t" + (detail || ""));
const GONE = new Set(["terminal_not_writable", "terminal_handle_stale"]);
const BLOCKED = "agent_prompt_blocked";
let data;
try {
  data = JSON.parse(fs.readFileSync(0, "utf8"));
} catch (err) {
  out("failed", "invalid-json");
  process.exit(0);
}
if (!data || typeof data !== "object") {
  out("failed", "invalid-json");
  process.exit(0);
}
if (data.ok === false) {
  const code = data.error && data.error.code;
  out(GONE.has(code) ? "gone" : code === BLOCKED ? "blocked" : "failed", code || "error");
  process.exit(0);
}
const r = data.result || {};
const send = r.send || {};
if (send.accepted !== true) {
  out("failed", "not-accepted");
  process.exit(0);
}
const prompt = send.prompt || null;
const mutation = r.mutation || {};
const id = (prompt && prompt.requestId) || mutation.requestId || "";
const stages = prompt && Array.isArray(prompt.stages) ? prompt.stages : [];
if (stages.includes("turn_started")) {
  out("started", id);
} else if (prompt && prompt.observation === "supported" && id) {
  out("accepted", id);
} else {
  out("unsupported", id);
}
' 2>/dev/null
}

# fm_backend_orca_send_text_submit: type <text> once and report the shared
# proof-carrying verdict (empty = delivered, pending = typed but unconfirmed,
# send-failed, unknown). The runtime's delivery receipts are used when it lists
# terminal.prompt-delivery.v1; otherwise (and whenever the status cannot be
# read) the literal-send-then-Enter loop below runs exactly as before.
fm_backend_orca_send_text_submit() {  # <terminal-id> <text> <retries> <enter-sleep> <settle>
  fm_backend_orca_tool_check || { printf 'send-failed'; return 0; }
  if fm_backend_orca_has_capability terminal.prompt-delivery.v1; then
    fm_backend_orca_send_text_receipt "$@"
  else
    fm_backend_orca_send_text_literal "$@"
  fi
}

# fm_backend_orca_send_text_literal: the verified loop for a runtime without
# receipts. Type the text once, then drive the shared verify-and-retry-Enter loop
# (bin/fm-composer-lib.sh: fm_composer_submit_retry_core) against the shared
# composer verdict, so a slash-command popup placeholder fill gets the required
# second Enter without duplicating text.
fm_backend_orca_send_text_literal() {  # <terminal-id> <text> <retries> <enter-sleep> <settle>
  local terminal=$1 text=$2 retries=$3 sleep_s=$4 settle=$5
  fm_backend_orca_send_literal "$terminal" "$text" || { printf 'send-failed'; return 0; }
  sleep "$settle"
  fm_composer_submit_retry_core fm_backend_orca_send_key fm_backend_orca_composer_state \
    "$terminal" "$retries" "$sleep_s"
}

# fm_backend_orca_composer_finish: the verdict once the receipts cannot settle a
# send but the input was accepted. An empty composer means the text left it; a
# proven pending composer means an Enter was swallowed, so Enter alone is
# retried through the shared core (the text is never typed again, since a receipt
# replay never presses Enter and retyping would duplicate it); anything the
# screen cannot prove stays "pending", the typed-but-unconfirmed verdict, because
# Orca did accept the input and a resend would duplicate it.
fm_backend_orca_composer_finish() {  # <terminal-id> <retries> <enter-sleep>
  local terminal=$1 retries=$2 sleep_s=$3 state
  state=$(fm_backend_orca_composer_state "$terminal")
  if fm_composer_blocking_dialog_noted >/dev/null; then
    printf 'unknown'
    return 0
  fi
  case "$state" in
    empty) printf 'empty' ;;
    pending|pending-unproven)
      fm_composer_submit_retry_core fm_backend_orca_send_key fm_backend_orca_composer_state \
        "$terminal" "$retries" "$sleep_s"
      ;;
    *) printf 'pending' ;;
  esac
}

# fm_backend_orca_send_text_receipt: one `terminal send --text --enter
# --wait-submit`, then a replay by request id (never a resend) for as long as the
# receipt shows input accepted and no turn yet, within the caller's <retries>
# observations. A receipt the runtime cannot observe (a plain shell, an
# unrecognized agent) falls to the composer; a terminal the runtime reports as
# unable to take input prints terminal-gone, names it on stderr, and exits 1 so
# every caller reads a failed send (the ring and fm-send alone read the word). A
# runtime refusal because a permission or trust prompt is showing prints
# prompt-blocked and exits 1 the same way, on the first send or any replay: the
# terminal is alive, nothing was delivered, and pressing Enter would answer the
# prompt's default, so it is never retried or Entered here.
# FM_ORCA_SUBMIT_WAIT sets the per-observation wait in seconds (default 2).
fm_backend_orca_send_text_receipt() {  # <terminal-id> <text> <retries> <enter-sleep> <settle>
  local terminal=$1 text=$2 retries=$3 sleep_s=$4 settle=$5 wait=${FM_ORCA_SUBMIT_WAIT:-2}
  local out cls detail req='' i=0 line
  case "$wait" in ''|*[!0-9]*) wait=2 ;; esac
  case "$retries" in ''|*[!0-9]*|0) retries=1 ;; esac
  while :; do
    if [ -n "$req" ]; then
      out=$(orca terminal send --terminal "$terminal" --text "$text" --enter --wait-submit "$wait" --retry-request "$req" --json 2>/dev/null) || true
    else
      out=$(orca terminal send --terminal "$terminal" --text "$text" --enter --wait-submit "$wait" --json 2>/dev/null) || true
    fi
    line=$(printf '%s' "$out" | fm_backend_orca_receipt_class)
    cls=${line%%$'\t'*}
    detail=${line#*$'\t'}
    case "$cls" in
      started)
        printf 'empty'
        return 0
        ;;
      gone)
        echo "error: Orca terminal $terminal is gone ($detail): nothing was delivered" >&2
        printf 'terminal-gone'
        return 1
        ;;
      blocked)
        echo "error: Orca terminal $terminal is showing a permission or trust prompt ($detail): nothing was delivered; answer the prompt in the terminal, then resend" >&2
        printf 'prompt-blocked'
        return 1
        ;;
      unsupported)
        sleep "$settle"
        fm_backend_orca_composer_finish "$terminal" "$retries" "$sleep_s"
        return 0
        ;;
      accepted)
        i=$((i + 1))
        if [ "$i" -ge "$retries" ]; then
          sleep "$settle"
          fm_backend_orca_composer_finish "$terminal" "$retries" "$sleep_s"
          return 0
        fi
        req=$detail
        ;;
      *)
        # failed: the runtime's own message is the cause worth showing.
        [ -z "$out" ] || printf '%s' "$out" | fm_backend_orca_json_ok || true
        echo "error: Orca terminal send to $terminal failed ($detail)" >&2
        printf 'send-failed'
        return 0
        ;;
    esac
  done
}

# fm_backend_orca_kill: close one recorded task terminal. A missing CLI is a
# close that was never even attempted, not an endpoint proven gone - with no
# CLI there is no read that could show the terminal absent - so it reports the
# failure its tool check already named instead of a success. The close call
# itself stays best-effort: whether an accepted-then-failed close left the
# terminal alive is not yet decidable without a presence re-read proven
# against the real Orca binary (docs/verification/runtime-backends.md
# "Endpoint close").
fm_backend_orca_kill() {  # <terminal-id>
  fm_backend_orca_tool_check || return 1
  orca terminal close --terminal "$1" --json >/dev/null 2>&1 || true
}


# fm_backend_orca_close_terminal: close one task terminal and read the runtime's
# receipt, printing exactly one verdict and returning 0 only for `killed`:
#   killed     - the runtime answered ok with result.close.ptyKilled true for
#                this handle: the PTY and every process in it are gone. This is
#                the one verdict that is stop proof, because it is the runtime's
#                own statement about the PTY rather than a read that could race.
#   gone       - the runtime does not know the handle (terminal_handle_stale):
#                nothing was killed, and nothing was there to kill.
#   unkilled   - the runtime answered ok but killed nothing (ptyKilled false),
#                as it does for a terminal that was already closed.
#   unreadable - no CLI, no answer, invalid JSON, another error, or a receipt
#                that names another handle or has no close record.
# The terminal is always named explicitly and never closed by worktree, so a
# close can never reach another terminal of the task's worktree. The CLI's exit
# status is ignored because Orca prints its ok:false JSON and exits 1.
# fm_backend_orca_kill keeps its own best-effort contract for teardown.
fm_backend_orca_close_terminal() {  # <terminal-id>
  local terminal=${1:-} out verdict
  [ -n "$terminal" ] || { printf 'unreadable'; return 1; }
  fm_backend_orca_tool_check || { printf 'unreadable'; return 1; }
  out=$(orca terminal close --terminal "$terminal" --json 2>/dev/null) || true
  verdict=$(printf '%s' "$out" | node -e '
const fs = require("fs");
const want = process.argv[1];
let data;
try {
  data = JSON.parse(fs.readFileSync(0, "utf8"));
} catch (err) {
  process.stdout.write("unreadable");
  process.exit(0);
}
function out(v) { process.stdout.write(v); process.exit(0); }
if (!data || typeof data !== "object") out("unreadable");
if (data.ok === false) out(data.error && data.error.code === "terminal_handle_stale" ? "gone" : "unreadable");
const c = data.ok === true && data.result ? data.result.close : null;
if (!c || typeof c !== "object" || c.handle !== want) out("unreadable");
if (c.ptyKilled === true) out("killed");
if (c.ptyKilled === false) out("unkilled");
out("unreadable");
' "$terminal" 2>/dev/null) || verdict=
  case "$verdict" in
    killed|gone|unkilled) ;;
    *) verdict=unreadable ;;
  esac
  printf '%s' "$verdict"
  [ "$verdict" = killed ]
}

# fm_backend_orca_terminal_handles: the live terminals of one worktree, read from
# `terminal list --worktree id:<worktree-id>`. Prints `ok` and then one handle
# per line (an orphaned row, or a row the runtime reports unwritable, is not
# live), or prints `unreadable` and returns 1 when the list cannot be read.
fm_backend_orca_terminal_handles() {  # <worktree-id>
  local worktree_id=${1:-} out
  [ -n "$worktree_id" ] || { printf 'unreadable'; return 1; }
  fm_backend_orca_tool_check || { printf 'unreadable'; return 1; }
  out=$(orca terminal list --worktree "id:$worktree_id" --json 2>/dev/null) || true
  printf '%s' "$out" | node -e '
const fs = require("fs");
let data;
try {
  data = JSON.parse(fs.readFileSync(0, "utf8"));
} catch (err) {
  process.stdout.write("unreadable");
  process.exit(1);
}
const rows = data && data.ok === true && data.result && Array.isArray(data.result.terminals) ? data.result.terminals : null;
if (!rows) {
  process.stdout.write("unreadable");
  process.exit(1);
}
const live = rows.filter((t) => t && typeof t.handle === "string" && t.handle !== "" && t.orphaned !== true && t.writable !== false);
process.stdout.write("ok\n" + live.map((t) => t.handle + "\n").join(""));
' 2>/dev/null || { printf 'unreadable'; return 1; }
}

# fm_backend_orca_absence_verdict: the Orca arm of the control plane's endpoint
# absence proof (bin/fm-control-lib.sh's fm_control_endpoint_absence_verdict owns
# the verdict vocabulary). Prints "<verdict>\t<reason>", the reason empty except
# on `unproven`. A terminal is GONE only when all of these hold: the runtime this
# seat addresses is on this host, it positively reads the terminal missing, and
# no process on this host still carries the terminal's handle. The last clause
# is what keeps a stale handle after a runtime restart - Orca's terminal
# processes survive a restart - from licensing a second agent beside a live one.
# A host with no process table accepts the runtime's own answer, the only
# evidence available there.
fm_backend_orca_absence_verdict() {  # <terminal-id>
  local terminal=${1:-}
  fm_backend_orca_runtime_is_local || {
    printf 'unproven\tthe runtime this seat addresses may be on another host (ORCA_ENVIRONMENT, ORCA_PAIRING_CODE, or ORCA_REMOTE_PAIRING is set), so neither its answer about a terminal handle nor this host'"'"'s process table proves anything about that terminal'
    return 0
  }
  case "$(fm_backend_orca_endpoint_state "$terminal")" in
    present)
      case "$(fm_backend_orca_agent_state "$terminal")" in
        dead) printf 'dead\t' ;;
        alive) printf 'alive\t' ;;
        *) printf 'unproven\tthe terminal is present but no process on this host proves it agent-free' ;;
      esac
      ;;
    missing)
      case "$(fm_backend_orca_process_state "$terminal")" in
        none|unsupported) printf 'gone\t' ;;
        agent) printf 'alive\t' ;;
        shell|other) printf 'unproven\tthe runtime reports the terminal gone, but a process on this host still carries its handle, so the terminal may be alive under a runtime that lost track of it' ;;
        *) printf 'unproven\tthe runtime reports the terminal gone, but this host'"'"'s process table could not be read to confirm that nothing still carries its handle' ;;
      esac
      ;;
    *) printf 'unproven\tthe runtime'"'"'s answer about the terminal could not be read' ;;
  esac
}

# fm_backend_orca_reclaim_terminal: replace a task's gone terminal with exactly
# one fresh one inside the task's own worktree, and print the new handle. The
# caller has already proven the old terminal gone (the absence verdict); this
# closes it anyway so that a tab Orca still shows for an exited shell does not
# survive beside the replacement, requires it to read missing, creates one
# terminal by the recorded worktree id (never by path or name), and requires the
# new handle to read present and to be listed for that worktree while the old one
# is not. A replacement that cannot be confirmed is closed again, never left
# behind. Another terminal of the same worktree is never closed or adopted. It
# never removes a worktree and never closes by worktree.
fm_backend_orca_reclaim_terminal() {  # <worktree-id> <old-terminal> <title>
  local worktree_id=${1:-} old=${2:-} title=${3:-} new listing
  [ -n "$worktree_id" ] && [ -n "$old" ] && [ -n "$title" ] || {
    echo "error: a reclaim needs the recorded worktree id, the old terminal, and a title" >&2
    return 1
  }
  fm_backend_orca_tool_check || return 1
  fm_backend_orca_close_terminal "$old" >/dev/null || true
  if [ "$(fm_backend_orca_endpoint_state "$old")" != missing ]; then
    echo "error: terminal $old does not read missing after it was closed; refusing to create a second terminal for $title beside it" >&2
    return 1
  fi
  new=$(fm_backend_orca_terminal_create "$worktree_id" "$title") || return 1
  listing=$(fm_backend_orca_terminal_handles "$worktree_id" 2>/dev/null) || listing=
  if [ "$(fm_backend_orca_endpoint_state "$new")" != present ] \
    || ! printf '%s\n' "$listing" | grep -Fxq -- "$new" \
    || printf '%s\n' "$listing" | grep -Fxq -- "$old"; then
    fm_backend_orca_kill "$new" >/dev/null 2>&1 || true
    echo "error: the replacement terminal $new for $title could not be confirmed present and listed for its worktree while $old is not; closed it again and kept the previous record" >&2
    return 1
  fi
  printf '%s' "$new"
}
