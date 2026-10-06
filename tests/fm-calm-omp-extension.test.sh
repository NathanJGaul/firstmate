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
const context = { ui: { setWorkingMessage(message) { working.push(message); } } };
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (working.length === 0) throw new Error("agent_start did not restore active Calm presentation");
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

test_omp_supported_rows_hide_without_semantic_mutation() {
  local home out
  home="$TMP_ROOT/home-a6"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a6.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a6");
const renderers = new Map();
const tools = [];
const events = new Map();
const pi = {
  on(name, handler) { events.set(name, handler); },
  registerCommand() {},
  registerMessageRenderer(name, renderer) { renderers.set(name, renderer); },
  getAllTools() { return [
    { name: "read", description: "native read", parameters: { type: "object" }, sourceInfo: { source: "builtin" } },
    { name: "bash", description: "foreign bash", parameters: { type: "object" }, sourceInfo: { source: "extension" } },
  ]; },
  registerTool(tool) { tools.push(tool); },
};
extension.default(pi);
await events.get("session_start")({}, { ui: { setWorkingMessage() {} } });
if (!renderers.has("firstmate-synthetic-input-presentation")) throw new Error("legacy custom-message renderer was not registered");
const hidden = renderers.get("firstmate-synthetic-input-presentation")({ content: "internal", customType: "firstmate-synthetic-input-presentation" }, {}, {});
if (!hidden || hidden.render(80).length !== 0) throw new Error("Calm-on legacy custom row was not hidden");
const read = tools.find((tool) => tool.name === "read");
if (!read) throw new Error("native read wrapper was not registered");
if (tools.some((tool) => tool.name === "bash")) throw new Error("foreign bash tool was claimed by Calm");
if (read.renderCall?.().render(80).length !== 0 || read.renderResult?.().render(80).length !== 0) throw new Error("Calm-on native tool rows were not hidden");
let delegated = false;
const result = await read.execute("call-1", { path: "file" }, "signal", "updates", { invokeTool: async (params, options) => { delegated = params.path === "file" && options.signal === "signal" && options.onUpdate === "updates"; return { content: [{ type: "text", text: "ok" }] }; } });
if (!delegated || result?.content?.[0]?.text !== "ok") throw new Error("native tool wrapper did not preserve execution inputs and result");
console.log("a6-ok");
JS
  out=$(run_node "$TMP_ROOT/a6.mjs" 2>&1) || fail "A6 supported rows: $out"
  assert_contains "$out" "a6-ok" "A6 supported rows did not complete"
  pass "OMP hides only supported Calm rows and delegates native tool execution"
}

test_omp_supported_rows_hide_without_semantic_mutation

test_calm_toggle_off_restores_stock_and_clears_timer() {
  local home out
  home="$TMP_ROOT/home-a3"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a3.mjs" <<JS
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a3");
const events = new Map();
const commands = new Map();
const messages = [];
const cleared = [];
const context = { ui: { setWorkingMessage(message) { messages.push(message); }, notify() {} }, setInterval(callback) { return { callback }; }, clearTimer(timer) { cleared.push(timer); } };
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand(name, command) { commands.set(name, command); }, registerMessageRenderer() {}, getAllTools() { return []; }, registerTool() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
await commands.get("calm").handler("", context);
if (readFileSync(${home@Q} + "/config/calm", "utf8") !== "off\\n") throw new Error("toggle off did not persist");
if (messages.at(-1) !== undefined) throw new Error("toggle off did not restore the stock working row");
if (cleared.length !== 1) throw new Error("toggle off did not clear the managed timer");
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
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a5");
const events = new Map();
const intervals = [];
const cleared = [];
const messages = [];
const context = { ui: { setWorkingMessage(message) { messages.push(message); } }, setInterval(callback) { const timer = { callback }; intervals.push(timer); return timer; }, clearTimer(timer) { cleared.push(timer); } };
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {}, registerMessageRenderer() {}, getAllTools() { return []; }, registerTool() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (intervals.length !== 1) throw new Error("agent_start did not create one managed timer");
const first = messages.at(-1);
intervals[0].callback();
if (messages.at(-1) === first) throw new Error("managed timer did not advance the working frame");
await events.get("agent_end")({}, context);
if (cleared.length !== 1 || messages.at(-1) !== undefined) throw new Error("agent_end did not clean up the working presentation");
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
const messages = [];
const intervals = [];
const context = { ui: { setWorkingMessage(message) { messages.push(message); } }, setInterval(callback) { intervals.push(callback); return callback; }, clearTimer() {} };
const pi = { on(name, handler) { events.set(name, handler); }, registerCommand() {} };
extension.default(pi);
await events.get("session_start")({}, context);
await events.get("agent_start")({}, context);
if (intervals.length !== 0) throw new Error("Calm off created a working timer");
if (messages.at(-1) !== undefined) throw new Error("Calm off replaced the stock working row");
console.log("a7-ok");
JS
  out=$(run_node "$TMP_ROOT/a7.mjs" 2>&1) || fail "A7 Calm off: $out"
  assert_contains "$out" "a7-ok" "A7 Calm off did not complete"
  pass "OMP Calm off leaves the ordinary working surface untouched"
}

test_omp_adapter_failures_are_isolated_and_diagnosed() {
  local home out
  home="$TMP_ROOT/home-a9"
  mkdir -p "$home/config"
  printf 'on\n' >"$home/config/calm"
  cat >"$TMP_ROOT/a9.mjs" <<JS
import { pathToFileURL } from "node:url";
process.env.FM_HOME = ${home@Q};
const extension = await import(pathToFileURL(${EXTENSION@Q}).href + "?a9");
const diagnostics = [];
const previousError = console.error;
console.error = (message) => diagnostics.push(String(message));
const commands = new Map();
const events = new Map();
extension.default({ on(name, handler) { events.set(name, handler); }, registerCommand(name, command) { commands.set(name, command); } });
await events.get("session_start")({}, {});
await events.get("agent_start")({}, {});
console.error = previousError;
if (!commands.has("calm")) throw new Error("preference command was lost with unsupported OMP seams");
for (const name of ["working-message", "legacy custom-message renderer", "native built-in tool wrappers", "generic transcript-row renderer"]) {
  if (!diagnostics.some((line) => line.includes(name))) throw new Error("missing diagnostic for " + name);
}
console.log("a9-ok " + diagnostics.length);
JS
  out=$(run_node "$TMP_ROOT/a9.mjs" 2>&1) || fail "A9 adapter diagnostics: $out"
  assert_contains "$out" "a9-ok" "A9 adapter diagnostics did not complete"
  pass "OMP reports each unsupported Calm seam independently while retaining /calm"
}

test_calm_toggle_off_restores_stock_and_clears_timer
test_calm_write_failure_preserves_active_state
test_calm_working_timer_is_managed_across_settle_and_shutdown
test_calm_off_keeps_ordinary_working_surface
test_omp_adapter_failures_are_isolated_and_diagnosed

test_calm_command_enables_shared_preference_without_transcript_row
test_calm_session_restores_shared_preference
