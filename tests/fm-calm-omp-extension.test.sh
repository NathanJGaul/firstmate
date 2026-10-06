#!/usr/bin/env bash
# Portable OMP Calm extension contract checks. The fake API models only the
# documented extension registration calls used by the extension.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT=${ROOT:?}
TMP_ROOT=$(fm_test_tmproot fm-calm-omp-extension)
EXTENSION="$ROOT/.omp/extensions/fm-calm.ts"

command -v node >/dev/null 2>&1 || { echo "skip: node not found for the OMP Calm extension checks"; exit 0; }

run_node() { node --input-type=module <"$1"; }

test_calm_command_enables_shared_preference_without_transcript_row() {
  local home out
  home="$TMP_ROOT/home-a1"
  mkdir -p "$home/config"
  cat >"$TMP_ROOT/a1.mjs" <<JS
import { readFileSync, existsSync } from "node:fs";
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href);
const commands = new Map();
const notifications = [];
let sentMessages = 0;
const pi = {
  on() {},
  registerCommand(name, command) { commands.set(name, command); },
  sendUserMessage() { sentMessages += 1; },
};
extension.default(pi);
if (!commands.has("calm")) throw new Error("the OMP extension did not register /calm");
await commands.get("calm").handler("", { ui: { notify(message, level) { notifications.push({ message, level }); } } });
const preference = readFileSync(${home@Q} + "/config/calm", "utf8");
if (preference !== "on\\n") throw new Error("/calm did not persist the shared on preference");
if (sentMessages !== 0) throw new Error("/calm sent a transcript row");
if (notifications.length !== 1 || notifications[0].level !== "info") throw new Error("/calm did not report the enabled state");
console.log("a1-ok " + notifications[0].message);
JS
  out=$(run_node "$TMP_ROOT/a1.mjs" 2>&1) || fail "A1 /calm command: $out"
  assert_contains "$out" "a1-ok" "A1 /calm command did not complete"
  pass "OMP /calm enables the shared preference without sending a model message"
}

test_calm_session_restores_shared_preference() {
  local home out
  home="$TMP_ROOT/home-a2"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a2.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a2");
const events = new Map();
const working = [];
const pi = {
  on(name, handler) { events.set(name, handler); },
  registerCommand() {},
};
extension.default(pi);
if (!events.has("session_start") || !events.has("agent_start")) throw new Error("session lifecycle was not registered");
const intervals = [];
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 12 });
const context = { ui: { setWorkingMessage(message) { working.push(message); } }, setInterval(callback) { intervals.push(callback); return callback; }, clearTimer() {} };
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
const active = working.at(-1);
if (typeof active !== "string" || !active.includes("╲")) throw new Error("agent_start did not render active Calm presentation");
const visibleWidth = (message) => Math.max(...message.split("\\n").map((row) => Array.from(row.replaceAll(/\\x1b\\[[0-9;]*m/g, "")).length));
if (visibleWidth(active) > 10) throw new Error("active Calm presentation exceeded the available width");
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 30 });
intervals[0]();
const resized = working.at(-1);
if (typeof resized !== "string" || visibleWidth(resized) > 28 || resized === active) throw new Error("active Calm presentation did not follow a resize");
console.log("a2-ok");
JS
  out=$(run_node "$TMP_ROOT/a2.mjs" 2>&1) || fail "A2 session restoration: $out"
  assert_contains "$out" "a2-ok" "A2 session restoration did not complete"
  pass "OMP session start restores the shared Calm preference before presentation"
}

test_omp_working_ship_projection_bounds() {
  local out
  cat >"$TMP_ROOT/u2.mjs" <<JS
import { pathToFileURL } from "node:url";
const presentation = await import(pathToFileURL(${ROOT@Q} + "/.omp/extensions/lib/fm-calm-omp-presentation.ts").href);
const stripAnsi = (text) => text.replaceAll(/\\x1b\\[[0-9;]*m/g, "");
const check = (condition, message) => { if (!condition) throw new Error(message); };
const sprite = presentation.createCalmWorkingShipSprite();
for (const width of [0, 1, 2, 3, 4, 5, 9, 40, 121]) {
  const rows = presentation.renderCalmWorkingShip(sprite, width);
  check(rows.length === (width === 0 ? 0 : width >= 5 ? 2 : 1), "unexpected row count at width " + width);
  for (const row of rows) check(Array.from(stripAnsi(row)).length <= width, "row overflowed width " + width);
  sprite.tick();
}
console.log("u2-ok");
JS
  out=$(run_node "$TMP_ROOT/u2.mjs" 2>&1) || fail "U2 working projection: $out"
  assert_contains "$out" "u2-ok" "U2 working projection did not complete"
  pass "OMP working projection reuses the shared sprite and respects narrow and wide bounds"
}

test_omp_working_ship_projection_bounds

test_omp_supported_rows_leave_native_tools_untouched() {
  local home out
  home="$TMP_ROOT/home-a6"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a6.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a6");
const renderers = new Map();
let inspectedNativeTools = false;
let registeredTools = 0;
const events = new Map();
const commands = new Map();
const pi = {
  on(name, handler) { events.set(name, handler); },
  registerCommand(name, command) { commands.set(name, command); },
  registerMessageRenderer(name, renderer) { renderers.set(name, renderer); },
  getAllTools() { inspectedNativeTools = true; return [{ name: "read", description: "native read", parameters: { type: "object" }, sourceInfo: { source: "builtin" } }]; },
  registerTool() { registeredTools += 1; },
};
extension.default(pi);
await events.get("session_start")({}, { ui: { setWorkingMessage() {} } });
if (!renderers.has("firstmate-synthetic-input-presentation")) throw new Error("legacy custom-message renderer was not registered");
const renderSynthetic = () => renderers.get("firstmate-synthetic-input-presentation")({ content: "internal", customType: "firstmate-synthetic-input-presentation" }, {}, {});
const hidden = renderSynthetic();
if (!hidden || hidden.render(80).length !== 0) throw new Error("Calm-on legacy custom row was not hidden");
await commands.get("calm").handler("", { ui: { notify() {} } });
if (hidden.render(80).length !== 0) throw new Error("an already-mounted synthetic row unexpectedly changed without host remount");
if (renderSynthetic() !== undefined) throw new Error("a newly rendered synthetic row did not restore ordinary rendering");
if (inspectedNativeTools || registeredTools !== 0) throw new Error("Calm claimed native tool presentation without a supported renderer seam");
console.log("a6-ok");
JS
  out=$(run_node "$TMP_ROOT/a6.mjs" 2>&1) || fail "A6 supported rows: $out"
  assert_contains "$out" "a6-ok" "A6 supported rows did not complete"
  pass "OMP hides supported legacy rows and leaves native tools untouched"
}

test_omp_supported_rows_leave_native_tools_untouched

test_calm_toggle_off_restores_stock_and_clears_timer() {
  local home out
  home="$TMP_ROOT/home-a3"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a3.mjs" <<JS
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a3");
const events = new Map();
const commands = new Map();
const messages = [];
const cleared = [];
const timers = [];
const context = { ui: { setWorkingMessage(message) { messages.push(message); }, notify() {} }, setInterval(callback) { const timer = { callback }; timers.push(timer); return timer; }, clearTimer(timer) { cleared.push(timer); } };
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand(name, command) { commands.set(name, command); }, registerMessageRenderer() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (timers.length !== 1) throw new Error("active run did not create a managed timer");
await commands.get("calm").handler("", context);
if (readFileSync(${home@Q} + "/config/calm", "utf8") !== "off\\n") throw new Error("active toggle off did not persist");
if (messages.at(-1) !== undefined) throw new Error("active toggle off did not restore the stock working row");
if (cleared.length !== 1) throw new Error("active toggle off did not clear the managed timer");
await events.get("agent_end")({}, context);
await commands.get("calm").handler("", context);
await commands.get("calm").handler("", context);
console.log("a3-ok");
JS
  out=$(run_node "$TMP_ROOT/a3.mjs" 2>&1) || fail "A3 toggle off: $out"
  assert_contains "$out" "a3-ok" "A3 toggle off did not complete"
  pass "OMP Calm off persists and restores the stock working row"
}

test_calm_write_failure_preserves_active_state() {
  local home out
  home="$TMP_ROOT/home-a4"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a4.mjs" <<JS
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
process.env.FM_CONFIG_OVERRIDE = "/proc/1/status";
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a4");
const commands = new Map();
const notifications = [];
const pi = { on() {}, registerCommand(name, command) { commands.set(name, command); } };
extension.default(pi);
await commands.get("calm").handler("", { ui: { notify(message, level) { notifications.push({ message, level }); } } });
if (notifications.length !== 1 || notifications[0].level !== "warning") throw new Error("failed write was not reported as warning");
if (readFileSync(${home@Q} + "/config/calm", "utf8") !== "on\\n") throw new Error("failed write changed the existing preference");
console.log("a4-ok");
JS
  out=$(run_node "$TMP_ROOT/a4.mjs" 2>&1) || fail "A4 failed write: $out"
  assert_contains "$out" "a4-ok" "A4 failed write did not complete"
  pass "OMP preference write failures preserve active state and report a warning"
}

test_calm_working_timer_is_managed_across_settle_and_shutdown() {
  local home out
  home="$TMP_ROOT/home-a5"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a5.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a5");
const events = new Map();
const intervals = [];
const cleared = [];
const messages = [];
const context = { ui: { setWorkingMessage(message) { messages.push(message); } }, setInterval(callback) { const timer = { callback }; intervals.push(timer); return timer; }, clearTimer(timer) { cleared.push(timer); } };
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {}, registerMessageRenderer() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (intervals.length !== 1) throw new Error("agent_start did not create one managed timer");
const first = messages.at(-1);
intervals[0].callback();
if (messages.at(-1) === first) throw new Error("managed timer did not advance the working frame");
await events.get("agent_end")({ willContinue: true }, context);
if (cleared.length !== 0 || messages.at(-1) === undefined) throw new Error("continuing agent_end interrupted the working presentation");
await events.get("agent_end")({}, context);
if (cleared.length !== 1 || messages.at(-1) !== undefined) throw new Error("terminal agent_end did not clean up the working presentation");
await events.get("agent_start")({}, context);
await events.get("session_shutdown")({}, context);
if (cleared.length !== 2 || messages.at(-1) !== undefined) throw new Error("session_shutdown did not clean up the working presentation");
console.log("a5-ok");
JS
  out=$(run_node "$TMP_ROOT/a5.mjs" 2>&1) || fail "A5 managed timer: $out"
  assert_contains "$out" "a5-ok" "A5 managed timer did not complete"
  pass "OMP Calm owns one managed animation timer and cleans it up on settle and shutdown"
}

test_calm_off_keeps_ordinary_working_surface() {
  local home out
  home="$TMP_ROOT/home-a7"
  mkdir -p "$home/config"
  printf 'off\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a7.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a7");
const events = new Map();
let workingLabel = "foreign extension label";
let setWorkingMessageCalls = 0;
const intervals = [];
const context = { ui: { setWorkingMessage(message) { setWorkingMessageCalls += 1; workingLabel = message ?? "OMP default"; } }, setInterval(callback) { intervals.push(callback); return callback; }, clearTimer() {} };
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (intervals.length !== 0) throw new Error("Calm off created a working timer");
if (setWorkingMessageCalls !== 0 || workingLabel !== "foreign extension label") throw new Error("Calm off replaced the stock working row");
console.log("a7-ok");
JS
  out=$(run_node "$TMP_ROOT/a7.mjs" 2>&1) || fail "A7 Calm off: $out"
  assert_contains "$out" "a7-ok" "A7 Calm off did not complete"
  pass "OMP Calm off leaves the ordinary working surface untouched"
}

test_calm_working_message_restore_is_retryable() {
  local home out
  home="$TMP_ROOT/home-a8"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a8.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a8");
const events = new Map();
const commands = new Map();
const messages = [];
const notifications = [];
const timers = [];
const cleared = [];
let failStockRestore = true;
const context = {
  ui: {
    setWorkingMessage(message) {
      if (message === undefined && failStockRestore) throw new Error("restore failed");
      messages.push(message);
    },
    notify(message, level) { notifications.push({ message, level }); },
  },
  setInterval(callback) { const timer = { callback }; timers.push(timer); return timer; },
  clearTimer(timer) { cleared.push(timer); },
};
const pi = {
  on(name, handler) { events.set(name, handler); },
  registerCommand(name, command) { commands.set(name, command); },
  registerMessageRenderer() {},
};
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (timers.length !== 1) throw new Error("active run did not create a managed timer");
await events.get("agent_end")({}, context);
if (cleared.length !== 0) throw new Error("timer was cleared before failed stock restoration could succeed");
await commands.get("calm").handler("", context);
if (notifications.at(-1)?.level !== "warning" || !notifications.at(-1)?.message.includes("presentation update pending")) {
  throw new Error("toggle off reported success after stock restoration failed");
}
if (cleared.length !== 0) throw new Error("failed stock restoration discarded the timer handle");
failStockRestore = false;
timers[0].callback();
if (cleared.length !== 1 || messages.at(-1) !== undefined) throw new Error("failed stock restoration was not retried by the retained timer");
console.log("a8-ok");
JS
  out=$(run_node "$TMP_ROOT/a8.mjs" 2>&1) || fail "A8 working-message restoration: $out"
  assert_contains "$out" "a8-ok" "A8 working-message restoration did not complete"
  pass "OMP retries failed stock restoration and reports incomplete toggle cleanup"
}

test_calm_frame_update_failure_is_retryable() {
  local home out
  home="$TMP_ROOT/home-a12"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a12.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a12");
const events = new Map();
const timers = [];
const cleared = [];
const diagnostics = [];
const previousError = console.error;
console.error = (message) => diagnostics.push(String(message));
let frameWrites = 0;
let failFrame = false;
const context = {
  ui: {
    setWorkingMessage(message) {
      if (typeof message === "string") {
        frameWrites += 1;
        if (failFrame) throw new Error("frame failed");
      }
    },
  },
  setInterval(callback) { const timer = { callback }; timers.push(timer); return timer; },
  clearTimer(timer) { cleared.push(timer); },
};
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {}, registerMessageRenderer() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (frameWrites !== 1 || timers.length !== 1) throw new Error("active run did not render its first frame");
failFrame = true;
timers[0].callback();
timers[0].callback();
if (cleared.length !== 0) throw new Error("frame failure discarded the managed timer");
failFrame = false;
timers[0].callback();
console.error = previousError;
if (frameWrites !== 4 || cleared.length !== 0) throw new Error("frame update did not retry through the retained timer");
if (diagnostics.filter((line) => line.includes("working-message") && line.includes("frame failed")).length !== 1) {
  throw new Error("repeated frame failures were not diagnosed once");
}
console.log("a12-ok");
JS
  out=$(run_node "$TMP_ROOT/a12.mjs" 2>&1) || fail "A12 frame update retry: $out"
  assert_contains "$out" "a12-ok" "A12 frame update retry did not complete"
  pass "OMP retries failed working-message frames without dropping the timer"
}

test_calm_pending_agent_start_retries_after_timer_clear_failure() {
  local home out
  home="$TMP_ROOT/home-a13"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a13.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a13");
const events = new Map();
const intervals = [];
const cleared = [];
const messages = [];
let clearAttempts = 0;
const context = {
  ui: { setWorkingMessage(message) { messages.push(message); } },
  setInterval(callback) { const timer = { callback }; intervals.push(timer); return timer; },
  clearTimer(timer) {
    cleared.push(timer);
    clearAttempts += 1;
    if (clearAttempts < 3) throw new Error("clear is still failing");
  },
};
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {}, registerMessageRenderer() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
await events.get("agent_end")({}, context);
if (intervals.length !== 1 || cleared.length !== 1 || messages.at(-1) !== undefined) {
  throw new Error("terminal cleanup did not retain the failed timer cleanup state");
}
await events.get("agent_start")({}, context);
if (intervals.length !== 1) throw new Error("next agent_start was not held for cleanup retry");
intervals[0].callback();
if (cleared.length !== 3 || intervals.length !== 2 || typeof messages.at(-1) !== "string") {
  throw new Error("pending agent_start did not resume after timer cleanup");
}
console.log("a13-ok");
JS
  out=$(run_node "$TMP_ROOT/a13.mjs" 2>&1) || fail "A13 pending agent start: $out"
  assert_contains "$out" "a13-ok" "A13 pending agent start did not complete"
  pass "OMP resumes a pending run after retained timer cleanup succeeds"
}

test_calm_pending_agent_start_survives_presentation_toggle() {
  local home out
  home="$TMP_ROOT/home-a15"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a15.mjs" <<JS
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a15");
const events = new Map();
const commands = new Map();
const intervals = [];
const messages = [];
let clearAttempts = 0;
const context = {
  ui: { setWorkingMessage(message) { messages.push(message); }, notify() {} },
  setInterval(callback) { const timer = { callback }; intervals.push(timer); return timer; },
  clearTimer() {
    clearAttempts += 1;
    if (clearAttempts < 3) throw new Error("clear is still failing");
  },
};
const pi = {
  on(name, handler) { events.set(name, handler); },
  registerCommand(name, command) { commands.set(name, command); },
  registerMessageRenderer() {},
};
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
await events.get("agent_end")({}, context);
await events.get("agent_start")({}, context);
if (intervals.length !== 1 || clearAttempts !== 2) throw new Error("the next agent start was not held for deferred cleanup");
await commands.get("calm").handler("", context);
await commands.get("calm").handler("", context);
if (readFileSync(${home@Q} + "/config/calm", "utf8") !== "on\\n") throw new Error("presentation toggles did not restore the active preference");
if (clearAttempts !== 3 || intervals.length !== 2 || typeof messages.at(-1) !== "string") {
  throw new Error("pending agent start was lost across Calm presentation toggles");
}
console.log("a15-ok");
JS
  out=$(run_node "$TMP_ROOT/a15.mjs" 2>&1) || fail "A15 pending toggle recovery: $out"
  assert_contains "$out" "a15-ok" "A15 pending toggle recovery did not complete"
  pass "OMP preserves a pending run across Calm presentation toggles"
}

test_calm_unusable_width_leaves_stock_working_surface() {
  local home out
  home="$TMP_ROOT/home-a14"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a14.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 2 });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a14");
const diagnostics = [];
const previousError = console.error;
console.error = (message) => diagnostics.push(String(message));
const events = new Map();
const messages = [];
const intervals = [];
const context = {
  ui: { setWorkingMessage(message) { messages.push(message); } },
  setInterval(callback) { intervals.push(callback); return callback; },
  clearTimer() {},
};
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {}, registerMessageRenderer() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (messages.length !== 0 || intervals.length !== 1) throw new Error("too-narrow Calm replaced the stock working surface or lost its retry timer");
if (!diagnostics.some((line) => line.includes("working-message width") && line.includes("too narrow"))) {
  throw new Error("too-narrow Calm width was not diagnosed");
}
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
intervals[0]();
if (typeof messages.at(-1) !== "string" || !messages.at(-1).includes("╲")) {
  throw new Error("Calm did not recover when a usable width returned");
}
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 2 });
intervals[0]();
if (messages.at(-1) !== undefined || intervals.length !== 1) {
  throw new Error("an active Calm run did not preserve its retry timer at an unusable width");
}
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
intervals[0]();
console.error = previousError;
if (typeof messages.at(-1) !== "string" || !messages.at(-1).includes("╲")) {
  throw new Error("an active Calm run did not recover after a temporary narrow width");
}
console.log("a14-ok");
JS
  out=$(run_node "$TMP_ROOT/a14.mjs" 2>&1) || fail "A14 unusable width: $out"
  assert_contains "$out" "a14-ok" "A14 unusable width did not complete"
  pass "OMP leaves the stock working surface when no usable width exists"
}

test_omp_adapter_failures_are_isolated_and_diagnosed() {
  local home out
  home="$TMP_ROOT/home-a9"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a9.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
Object.defineProperty(process.stdout, "columns", { configurable: true, value: undefined });
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a9");
const diagnostics = [];
const previousError = console.error;
console.error = (message) => diagnostics.push(String(message));
const commands = new Map();
const events = new Map();
extension.default({ on(name, handler) { events.set(name, handler); }, registerCommand(name, command) { commands.set(name, command); } });
const context = { ui: { setWorkingMessage() {} } };
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
await commands.get("calm").handler("", context);
console.error = previousError;
if (!commands.has("calm")) throw new Error("preference command was lost with unsupported OMP seams");
for (const name of ["legacy custom-message renderer", "generic transcript-row renderer", "working-message timer", "working-message width", "notification"]) {
  if (!diagnostics.some((line) => line.includes(name))) throw new Error("missing diagnostic for " + name);
}
console.log("a9-ok " + diagnostics.length);
JS
  out=$(run_node "$TMP_ROOT/a9.mjs" 2>&1) || fail "A9 adapter diagnostics: $out"
  assert_contains "$out" "a9-ok" "A9 adapter diagnostics did not complete"
  pass "OMP reports each unsupported Calm seam independently while retaining /calm"
}

test_omp_adapter_invocation_failures_are_isolated() {
  local home out
  home="$TMP_ROOT/home-a10"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a10.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extensionUrl = pathToFileURL(${EXTENSION@Q}).href;
Object.defineProperty(process.stdout, "columns", { configurable: true, value: 40 });
const diagnostics = [];
const previousError = console.error;
console.error = (message) => diagnostics.push(String(message));
const load = async (name, context, start = true, toggle = false, end = false) => {
  const events = new Map();
  const commands = new Map();
  const extension = await import(extensionUrl + "?a10-" + name);
  extension.default({ on(event, handler) { events.set(event, handler); }, registerCommand(command, definition) { commands.set(command, definition); } });
  await events.get("session_start")({}, context);
  if (start) await events.get("agent_start")({}, context);
  if (end) await events.get("agent_end")({}, context);
  if (toggle) await commands.get("calm").handler("", context);
};
await load("working", { ui: { setWorkingMessage() { throw new Error("working failed"); } }, setInterval() { throw new Error("interval failed"); }, clearTimer() {} });
await load("timer", { ui: { setWorkingMessage() {} }, setInterval() { throw new Error("interval failed"); }, clearTimer() {} });
const messages = [];
let clearAttempts = 0;
let retainedTimer;
await load("clear", { ui: { setWorkingMessage(message) { messages.push(message); } }, setInterval(callback) { retainedTimer = { callback }; return retainedTimer; }, clearTimer() { clearAttempts += 1; if (clearAttempts === 1) throw new Error("clear failed"); } }, true, false, true);
if (messages.at(-1) !== undefined) throw new Error("stock working message was not attempted after clear failure");
retainedTimer.callback();
if (clearAttempts !== 2) throw new Error("failed timer cleanup was not retried with the retained handle");
console.error = previousError;
for (const [name, detail] of [["working-message", "working failed"], ["working-message timer", "interval failed"], ["working-message timer", "clear failed"]]) {
  if (!diagnostics.some((line) => line.includes(name) && line.includes(detail))) throw new Error("missing invocation diagnostic for " + name + ": " + detail);
}
console.log("a10-ok");
JS
  out=$(run_node "$TMP_ROOT/a10.mjs" 2>&1) || fail "A10 invocation failures: $out"
  assert_contains "$out" "a10-ok" "A10 invocation failures did not complete"
  pass "OMP isolates throwing presentation invocations and cleans up state"
}

test_calm_toggle_off_restores_stock_and_clears_timer
test_calm_write_failure_preserves_active_state
test_calm_working_timer_is_managed_across_settle_and_shutdown
test_calm_off_keeps_ordinary_working_surface
test_calm_working_message_restore_is_retryable
test_calm_frame_update_failure_is_retryable
test_calm_pending_agent_start_retries_after_timer_clear_failure
test_calm_pending_agent_start_survives_presentation_toggle
test_calm_unusable_width_leaves_stock_working_surface
test_omp_adapter_failures_are_isolated_and_diagnosed
test_omp_adapter_invocation_failures_are_isolated

test_calm_command_enables_shared_preference_without_transcript_row
test_calm_session_restores_shared_preference
