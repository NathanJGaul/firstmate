#!/usr/bin/env bash
# Telegram pairing, safe command, durable polling, and process-event adapter behavior.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-telegram)
TELEGRAM="$ROOT/bin/fm-telegram.py"
ADAPTER="$ROOT/bin/fm-procevent-telegram.sh"

make_home() {
  local home="$TMP_ROOT/home-$1"
  mkdir -p "$home/config" "$home/data" "$home/projects" "$home/state"
  touch "$home/state/.last-watcher-beat"
  printf '%s\n' "$home"
}

start_api() {
  local dir=$1 port=$2
  cat > "$dir/api.py" <<'PY'
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

root = sys.argv[1]
port = int(sys.argv[2])
class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        with open(root + "/requests", "ab") as stream:
            stream.write(body + b"\n")
        with open(root + "/paths", "a", encoding="utf-8") as stream:
            stream.write(self.path + "\n")
        if os.path.exists(root + "/redirect"):
            self.send_response(302)
            self.send_header("Location", "http://127.0.0.1:1/redirected")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        status = 200
        if self.path.endswith("/getMe"):
            payload = {"ok": True, "result": {"id": 99, "is_bot": True, "username": "firstmate_test_bot"}}
        elif self.path.endswith("/getUpdates"):
            try:
                with open(root + "/updates", encoding="utf-8") as stream:
                    payload = json.load(stream)
            except FileNotFoundError:
                payload = {"ok": True, "result": []}
        elif self.path.endswith("/sendMessage"):
            if os.path.exists(root + "/fail-send"):
                payload = {"ok": False, "error_code": 503, "description": "send unavailable"}
            elif os.path.exists(root + "/reject-send"):
                status = 403
                payload = {"ok": False, "error_code": 403, "description": "Forbidden: bot was blocked by the user"}
            else:
                payload = {"ok": True, "result": {"message_id": 1}}
        else:
            payload = {"ok": False, "error_code": 404, "description": "unknown"}
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
    def log_message(self, *_):
        pass
HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
  python3 "$dir/api.py" "$dir" "$port" >"$dir/api.log" 2>&1 &
  API_PID=$!
  FM_TEST_PIDS="${FM_TEST_PIDS:-} $API_PID"
  export FM_TEST_PIDS
  sleep 0.2
}

API_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
api="$TMP_ROOT/api"
mkdir -p "$api"
start_api "$api" "$API_PORT"

home=$(make_home setup)
setup=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" setup --json <<<'123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi')
assert_equals '/bot123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi/getMe' "$(head -1 "$api/paths")" 'Bot API path concatenates bot token without an extra slash'
assert_contains "$setup" 'firstmate_test_bot' 'setup prints bot username'
assert_contains "$setup" 'https://t.me/firstmate_test_bot?start=' 'setup prints Telegram deep link'
assert_contains "$setup" '"qr":' 'machine setup records QR field'
assert_not_contains "$setup" '"qr": null' 'machine setup always includes bundled QR output'
decoded_link=$(python3 - "$setup" <<'PY'
import json
import re
import sys

setup = json.loads(sys.argv[1])
expected = setup["deep_link"]
rows = setup["qr"].rstrip("\n").splitlines()
assert rows and len({len(row) for row in rows}) == 1
assert len(rows[0]) % 2 == 0 and len(rows) == len(rows[0]) // 2
full = [[row[column:column + 2] == "██" for column in range(0, len(row), 2)] for row in rows]
assert all(cell in ("██", "  ") for row in rows for cell in re.findall("..", row))
quiet = 4
size = len(full) - quiet * 2
assert size == len(full[0]) - quiet * 2 and size >= 21
modules = [row[quiet:-quiet] for row in full[quiet:-quiet]]
version = (size - 17) // 4
blocks = {
    1: ((1, 26, 16),), 2: ((1, 44, 28),), 3: ((1, 70, 44),),
    4: ((2, 50, 32),), 5: ((2, 67, 43),), 6: ((4, 43, 27),),
    7: ((4, 49, 31),), 8: ((2, 60, 38), (2, 61, 39)),
    9: ((3, 58, 36), (2, 59, 37)), 10: ((4, 69, 43), (1, 70, 44)),
}
alignment = {
    2: (6, 18), 3: (6, 22), 4: (6, 26), 5: (6, 30), 6: (6, 34),
    7: (6, 22, 38), 8: (6, 24, 42), 9: (6, 26, 46), 10: (6, 28, 50),
}
def finder(row, column):
    for dy in range(-1, 8):
        for dx in range(-1, 8):
            y, x = row + dy, column + dx
            if 0 <= y < size and 0 <= x < size:
                modules[y][x] = 0 <= dx <= 6 and 0 <= dy <= 6 and (dx in (0, 6) or dy in (0, 6) or 2 <= dx <= 4 and 2 <= dy <= 4)

modules = [[None] * size for _ in range(size)]
finder(0, 0)
finder(size - 7, 0)
finder(0, size - 7)
for coordinate in alignment.get(version, ()):
    for row in alignment.get(version, ()):
        if modules[row][coordinate] is not None:
            continue
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                modules[row + dy][coordinate + dx] = max(abs(dx), abs(dy)) != 1
for index in range(8, size - 8):
    if modules[6][index] is None:
        modules[6][index] = index % 2 == 0
    if modules[index][6] is None:
        modules[index][6] = index % 2 == 0
modules[size - 8][8] = True
for index in range(15):
    if index < 6:
        modules[index][8] = False
    elif index < 8:
        modules[index + 1][8] = False
    else:
        modules[size - 15 + index][8] = False
    if index < 8:
        modules[8][size - index - 1] = False
    elif index == 8:
        modules[8][7] = False
    else:
        modules[8][15 - index - 1] = False
format_bits = 0
for index in range(15):
    if index < 6:
        bit = full[quiet + index][quiet + 8]
    elif index < 8:
        bit = full[quiet + index + 1][quiet + 8]
    else:
        bit = full[quiet + size - 15 + index][quiet + 8]
    format_bits |= int(bit) << index
mask = ((format_bits ^ 0x5412) >> 10) & 7
def mask_bit(row, column):
    if mask == 0: return (row + column) % 2 == 0
    if mask == 1: return row % 2 == 0
    if mask == 2: return column % 3 == 0
    if mask == 3: return (row + column) % 3 == 0
    if mask == 4: return (row // 2 + column // 3) % 2 == 0
    if mask == 5: return row * column % 2 + row * column % 3 == 0
    if mask == 6: return (row * column % 2 + row * column % 3) % 2 == 0
    return ((row * column) % 3 + (row + column) % 2) % 2 == 0
bits = []
row = size - 1
upward = True
column = size - 1
while column > 0:
    if column == 6:
        column -= 1
    for _ in range(size):
        row_index = row if upward else size - 1 - row
        for column_index in (column, column - 1):
            if modules[row_index][column_index] is None:
                bits.append(int(full[quiet + row_index][quiet + column_index] ^ mask_bit(row_index, column_index)))
        row -= 1
    row = size - 1
    upward = not upward
    column -= 2
spec = blocks[version]
total_codewords = sum(count * total for count, total, _ in spec)
bits = bits[:total_codewords * 8]
codewords = [sum(bits[index + offset] << (7 - offset) for offset in range(8)) for index in range(0, len(bits), 8)]
block_data = []
block_total = []
for count, total, data_count in spec:
    block_total.extend([total] * count)
    block_data.extend([data_count] * count)
block_bytes = [[] for _ in block_data]
position = 0
for index in range(max(block_data)):
    for block_index, data_count in enumerate(block_data):
        if index < data_count:
            block_bytes[block_index].append(codewords[position])
            position += 1
for index in range(max(total - data for total, data in zip(block_total, block_data))):
    for block_index, total in enumerate(block_total):
        data_count = block_data[block_index]
        if index < total - data_count:
            position += 1
assert position == len(codewords)
payload = bytes(value for block, data_count in zip(block_bytes, block_data) for value in block[:data_count])
payload_bits = [(value >> shift) & 1 for value in payload for shift in range(7, -1, -1)]
assert int("".join(map(str, payload_bits[:4])), 2) == 4
length = int("".join(map(str, payload_bits[4:12])), 2)
data_bits = payload_bits[12:12 + length * 8]
data = bytes(sum(data_bits[index + offset] << (7 - offset) for offset in range(8)) for index in range(0, len(data_bits), 8))
assert data.decode() == expected
print(expected)
PY
)
assert_equals "$(python3 -c 'import json,sys; print(json.load(sys.stdin)["deep_link"])' <<<"$setup")" "$decoded_link" 'bundled QR decodes to the exact Telegram deep link'
assert_present "$home/config/telegram-bot-token" 'setup stores token'
assert_present "$home/state/telegram/pairing.json" 'setup stores pairing state'
assert_equals '600' "$(stat -c '%a' "$home/config/telegram-bot-token")" 'token file is private'
if grep -F '123456:' "$home/state/telegram/pairing.json" "$home/state/telegram"/* 2>/dev/null; then
  fail 'Telegram token leaked into state records'
fi
pass 'setup stores token privately and prints a decodable QR deep link'

tty_home=$(make_home setup-tty)
tty_setup=$(python3 - "$TELEGRAM" "$tty_home" "http://127.0.0.1:$API_PORT/bot" <<'PY'
import os
import pty
import select
import signal
import sys
import time

telegram, home, api_base = sys.argv[1:4]
token = b"123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi"
pid, fd = pty.fork()
if pid == 0:
    os.execve(telegram, [telegram, "setup", "--json"], {**os.environ, "FM_HOME": home, "FM_TELEGRAM_API_BASE": api_base})
output = b""
sent = False
deadline = time.monotonic() + 30
while time.monotonic() < deadline:
    if not select.select([fd], [], [], 0.5)[0]:
        continue
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    output += chunk
    if not sent and b"Telegram bot token: " in output:
        os.write(fd, token + b"\n")
        sent = True
else:
    os.kill(pid, signal.SIGKILL)
status = os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1])
assert sent and status == 0, (status, output)
assert token not in output, output
sys.stdout.write(output.decode())
PY
)
assert_contains "$tty_setup" 'https://t.me/firstmate_test_bot?start=' 'interactive setup accepts the prompted token'
assert_equals '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' "$(cat "$tty_home/config/telegram-bot-token")" 'interactive setup stores the prompted token'
set +e
FM_HOME="$tty_home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" setup --token '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' </dev/null >/dev/null 2>&1
argv_token_code=$?
set -e
expect_code 2 "$argv_token_code" 'setup refuses a command-line bot token'
pass 'setup reads the bot token from a non-echoing prompt and never from argv'

nonce=$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.parse_qs(urllib.parse.urlparse(json.load(sys.stdin)["deep_link"]).query)["start"][0])' <<<"$setup")
if grep -F '"nonce"' "$home/state/telegram/pairing.json" >/dev/null 2>&1; then
  fail 'pairing state stored the raw nonce'
fi

set +e
direct_pair=$(FM_HOME="$home" "$TELEGRAM" pair --json --nonce "$nonce" --user-id 7 --chat-id 8 2>&1)
direct_pair_code=$?
set -e
expect_code 2 "$direct_pair_code" 'direct pairing bypass is unavailable'

cat > "$api/updates" <<JSON
{"ok":true,"result":[{"update_id":1,"message":{"message_id":1,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/start $nonce"}}]}
JSON
pair=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" "$TELEGRAM" poll --once --json)
assert_contains "$pair" '"processed": 1' 'QR pairing accepts a fresh nonce'

cat > "$api/updates" <<JSON
{"ok":true,"result":[{"update_id":2,"message":{"message_id":2,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/start $nonce"}}]}
JSON
replay=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" "$TELEGRAM" poll --once --json)
assert_contains "$replay" '"rejected": 1' 'replayed nonce is rejected after pairing'
pass 'QR pairing is one-time and rotates nonce'

expired_nonce='expired-nonce-123456'
expired_hash=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest())' "$expired_nonce")
cat > "$home/state/telegram/pairing.json" <<JSON
{"schema":"fm-telegram-pairing.v1","bot_username":"firstmate_test_bot","nonce_hash":"$expired_hash","nonce_expires_at":1,"paired_user_id":null,"paired_chat_id":null,"paired_at":null}
JSON
cat > "$api/updates" <<JSON
{"ok":true,"result":[{"update_id":3,"message":{"message_id":3,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/start $expired_nonce"}}]}
JSON
expired=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" "$TELEGRAM" poll --once --json)
assert_contains "$expired" '"rejected": 1' 'expired pairing nonce is rejected'
assert_contains "$(cat "$home/state/telegram/inbox/3.json")" 'expired or invalid' 'expired nonce rejection is explicit'
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":4,"message":{"message_id":4,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/start bad nonce"}}]}
JSON
malformed=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" "$TELEGRAM" poll --once --json)
assert_contains "$malformed" '"rejected": 1' 'malformed pairing nonce is rejected'
assert_contains "$(cat "$home/state/telegram/inbox/4.json")" 'nonce is malformed' 'malformed nonce rejection is explicit'
assert_contains "$(cat "$home/state/telegram/pairing.json")" '"paired_user_id":null' 'rejected nonces do not bind identity'
pass 'expired and malformed pairing nonces are rejected'

wire_home=$(make_home wire-pair)
wire_setup=$(FM_HOME="$wire_home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" setup --json <<<'123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi')
wire_nonce=$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.parse_qs(urllib.parse.urlparse(json.load(sys.stdin)["deep_link"]).query)["start"][0])' <<<"$wire_setup")
cat > "$api/updates" <<JSON
{"ok":true,"result":[{"update_id":7,"message":{"message_id":1,"from":{"id":17},"chat":{"id":18,"type":"private"},"text":"/start $wire_nonce"}}]}
JSON
printf '%s\n' '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' > "$wire_home/config/telegram-bot-token"
wire_poll=$(FM_HOME="$wire_home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" poll --once --json)
assert_contains "$wire_poll" '"processed": 1' 'Telegram deep-link start pairs through polling'
assert_contains "$(cat "$wire_home/state/telegram/pairing.json")" '"paired_user_id":"17"' 'poll records Telegram user identity'
assert_contains "$(cat "$wire_home/state/telegram/pairing.json")" '"paired_chat_id":"18"' 'poll records Telegram chat identity'
assert_not_contains "$(cat "$wire_home/state/telegram/inbox/7.json")" "$wire_nonce" 'inbox redacts pairing nonce'
assert_not_contains "$(cat "$wire_home/state/telegram/inbound/7.json")" "$wire_nonce" 'inbound record redacts pairing nonce'
pass 'Telegram deep-link pairing binds user and chat identities'

home=$(make_home commands)
mkdir -p "$home/state/telegram"
cat > "$home/state/telegram/pairing.json" <<'JSON'
{"schema":"fm-telegram-pairing.v1","bot_username":"firstmate_test_bot","nonce_hash":"unused","nonce_expires_at":4102444800,"paired_user_id":"7","paired_chat_id":"8","paired_at":"2026-01-01T00:00:00Z"}
JSON
set +e
FM_HOME="$home" "$TELEGRAM" dispatch --json --user-id 9 --chat-id 8 --update-id 1 --text /status >/tmp/fm-telegram-reject.out 2>&1
reject_code=$?
set -e
expect_code 1 "$reject_code" 'mismatched user is rejected'
assert_contains "$(cat /tmp/fm-telegram-reject.out)" 'not paired' 'identity rejection is explicit'
owner_root="$TMP_ROOT/owner-root"
mkdir -p "$owner_root/bin"
cat > "$owner_root/bin/fm-bearings-snapshot.sh" <<'SH'
#!/usr/bin/env bash
printf 'snapshot:%s\n' "$*"
SH
cat > "$owner_root/bin/fm-inbox.sh" <<'SH'
#!/usr/bin/env bash
printf 'note:%s:%s\n' "$*" "$(cat)"
SH
cat > "$owner_root/bin/fm-send.sh" <<'SH'
#!/usr/bin/env bash
printf 'steer:%s\n' "$*"
SH
chmod 755 "$owner_root/bin/"*.sh
status=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 2 --text /status)
assert_contains "$status" 'snapshot:--json' 'status uses durable snapshot owner'
decisions=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 3 --text /decisions)
assert_contains "$decisions" 'snapshot:--json --all-decisions' 'decisions use bounded decision owner'
note=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 4 --text '/note hello')
assert_contains "$note" 'note:note --request-id telegram-4 --json -:hello' 'note uses inbox owner and stdin'
steer=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 5 --text '/steer worker hello')
assert_contains "$steer" 'steer:worker hello' 'steer preserves the normal worker text path'
assert_not_contains "$steer" '--fire-and-forget' 'ordinary workers do not receive secondmate delivery flags'
set +e
unsafe=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 6 --text '/steer ../bad hello' 2>&1)
unsafe_code=$?
unknown=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 7 --text '/merge now' 2>&1)
unknown_code=$?
control=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 8 --text $'/note hello\nworld' 2>&1)
control_code=$?
set -e
expect_code 1 "$unsafe_code" 'unsafe worker target is rejected'
assert_contains "$unsafe" 'target or text is invalid' 'unsafe worker rejection is explicit'
expect_code 1 "$unknown_code" 'unsupported Telegram command is rejected'
assert_contains "$unknown" 'unsupported Telegram command' 'unsupported command rejection is explicit'
expect_code 1 "$control_code" 'control bytes are rejected'
assert_contains "$control" 'contains control bytes' 'control-byte rejection is explicit'
set +e
blank_note=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 9 --text '/note ' 2>&1)
blank_note_code=$?
blank_steer=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 10 --text '/steer worker ' 2>&1)
blank_steer_code=$?
parser_slash=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 11 --text '/steer worker /exit' 2>&1)
parser_slash_code=$?
parser_dollar=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 12 --text '/steer worker $skill' 2>&1)
parser_dollar_code=$?
parser_key=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$owner_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 13 --text '/steer worker --key Enter' 2>&1)
parser_key_code=$?
set -e
expect_code 1 "$blank_note_code" 'whitespace-only note is rejected'
expect_code 1 "$blank_steer_code" 'whitespace-only steer is rejected'
expect_code 1 "$parser_slash_code" 'slash parser command is rejected'
expect_code 1 "$parser_dollar_code" 'codex parser command is rejected'
expect_code 1 "$parser_key_code" 'key parser command is rejected'
assert_contains "$parser_slash" 'parser-native prefix' 'slash parser rejection is explicit'
assert_contains "$parser_dollar" 'parser-native prefix' 'codex parser rejection is explicit'
assert_contains "$parser_key" 'parser-native prefix' 'key parser rejection is explicit'
pass 'paired command owner boundaries are enforced'

unconfirmed_root="$TMP_ROOT/unconfirmed-root"
mkdir -p "$unconfirmed_root/bin"
cat > "$unconfirmed_root/bin/fm-send.sh" <<'SH'
#!/usr/bin/env bash
echo "error: steer is unconfirmed (delivery-id=x); retry only with the same delivery id" >&2
exit 3
SH
chmod 755 "$unconfirmed_root/bin/fm-send.sh"
set +e
unconfirmed=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$unconfirmed_root" "$TELEGRAM" dispatch --json --user-id 7 --chat-id 8 --update-id 16 --text '/steer worker hello' 2>&1)
unconfirmed_code=$?
set -e
expect_code 1 "$unconfirmed_code" 'unconfirmed steer is not reported as accepted'
assert_contains "$unconfirmed" 'steer unconfirmed - may have landed; check before resending' 'unconfirmed steer reply says it may have landed'
assert_not_contains "$unconfirmed" 'rejected request' 'unconfirmed steer is not reported as rejected'
python3 - "$TELEGRAM" "$home" "$unconfirmed_root" <<'PY'
import importlib.machinery
import importlib.util
import os
import subprocess
import sys

telegram, home, owner_root = sys.argv[1:4]
os.environ.update({"FM_HOME": home, "FM_ROOT_OVERRIDE": owner_root})
os.environ.pop("FM_SEND_REMOTE_BUDGET", None)
loader = importlib.machinery.SourceFileLoader("fm_telegram_steer_bound", telegram)
module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(module)


observed = []


def remote_send(argv, timeout, **kwargs):
    observed.append(timeout)
    return subprocess.CompletedProcess(argv, 3, b"", b"unconfirmed")


module.subprocess.run = remote_send
for budget in (None, "45"):
    if budget is not None:
        os.environ["FM_SEND_REMOTE_BUDGET"] = budget
    try:
        module.dispatch("/steer worker hello", "7", "8", "17")
    except module.TelegramError as exc:
        assert str(exc) == "steer unconfirmed - may have landed; check before resending", str(exc)
    else:
        raise AssertionError("unconfirmed remote steer was reported as accepted")
assert observed == [80, 110], observed


def slow_send(argv, timeout, **kwargs):
    raise subprocess.TimeoutExpired(argv, timeout)


module.subprocess.run = slow_send
try:
    module.dispatch("/steer worker hello", "7", "8", "18")
except module.TelegramError as exc:
    assert str(exc) == "steer unconfirmed - may have landed; check before resending", str(exc)
else:
    raise AssertionError("timed-out steer was reported as accepted")
PY
pass 'a steer whose fm-send delivery is unconfirmed or outlives its bound replies that it may have landed'

pagination_root="$TMP_ROOT/pagination-root"
mkdir -p "$pagination_root/bin"
cat > "$pagination_root/bin/fm-bearings-snapshot.sh" <<'SH'
#!/usr/bin/env python3
import json
import os
import sys

offset = int(os.environ.get("FM_BEARINGS_IN_FLIGHT_OFFSET", "0"))
limit = int(os.environ.get("FM_BEARINGS_IN_FLIGHT", "20"))
rows = [
    {"id": f"worker-{index:03d}-" + "x" * 117, "kind": "ship", "state": "working", "name": "n" * 120, "doing": "d" * 120}
    for index in range(80)
]
end = offset + limit
result = {"schema": "fm-bearings.v1", "generated": "2026-01-01T00:00:00Z", "in_flight": rows[offset:end], "decisions_open": [], "omitted": []}
if end < len(rows):
    result["omitted"].append({"surface": f"in_flight showing {end} of {len(rows)}", "count": len(rows) - end})
if os.environ.get("FM_BEARINGS_DECISIONS_PAGED") == "1" and "--all-decisions" in sys.argv:
    decisions = [
        {"id": f"task-{index:03d}", "key": f"q{index:03d}", "verb": "needs-decision", "summary": "s" * 200, "owner": "main"}
        for index in range(45)
    ]
    decisions_offset = int(os.environ.get("FM_BEARINGS_DECISIONS_OFFSET", "0"))
    decisions_end = decisions_offset + int(os.environ.get("FM_BEARINGS_DECISIONS", "20"))
    result["decisions_open"] = decisions[decisions_offset:decisions_end]
    if decisions_end < len(decisions):
        result["omitted"].append({"surface": f"decisions_open showing {decisions_end} of {len(decisions)}", "count": len(decisions) - decisions_end})
print(json.dumps(result))
SH
chmod 755 "$pagination_root/bin/fm-bearings-snapshot.sh"
page_one=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$pagination_root" FM_TELEGRAM_PAGE_SIZE=50 \
  "$TELEGRAM" dispatch --user-id 7 --chat-id 8 --update-id 14 --text /status)
next_command=$(python3 - "$page_one" <<'PY'
import json
import sys
value = json.loads(sys.argv[1])
assert 0 < len(value["in_flight"]) < 50
assert value["pagination"]["next_offset"] == len(value["in_flight"])
print(value["pagination"]["next_command"])
PY
)
page_two=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$pagination_root" FM_TELEGRAM_PAGE_SIZE=50 \
  "$TELEGRAM" dispatch --user-id 7 --chat-id 8 --update-id 15 --text "$next_command")
python3 - "$page_one" "$page_two" <<'PY'
import json
import sys
first = json.loads(sys.argv[1])
second = json.loads(sys.argv[2])
assert second["in_flight"][0]["id"] == f"worker-{first['pagination']['next_offset']:03d}-" + "x" * 117
PY
python3 - "$TELEGRAM" "$home" "$pagination_root" <<'PY'
import json
import os
import subprocess
import sys

telegram, home, owner_root = sys.argv[1:4]
update = 100


def pages(command, collection, field):
    global update
    seen = []
    text = command
    while text is not None:
        update += 1
        output = subprocess.run(
            [telegram, "dispatch", "--user-id", "7", "--chat-id", "8", "--update-id", str(update), "--text", text],
            env={**os.environ, "FM_HOME": home, "FM_ROOT_OVERRIDE": owner_root, "FM_TELEGRAM_PAGE_SIZE": "50"},
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        assert len(output) <= 4096
        value = json.loads(output)
        assert value[collection]
        seen.extend(row[field] for row in value[collection])
        text = value["pagination"]["next_command"]
    return seen


assert pages("/status", "in_flight", "id") == [f"worker-{index:03d}-" + "x" * 117 for index in range(80)]
assert pages("/decisions", "decisions_open", "key") == [f"q{index:03d}" for index in range(45)]
PY
pass 'status and decision pagination continue after response compaction without skipping or repeating rows'

legacy_state="$TMP_ROOT/legacy-inbox"
mkdir -p "$legacy_state/task.inbox/handled"
{
  printf 'schema=fm-task-inbox.v1\nat=2026-01-01T00:00:00Z\n--\n'
  printf 'legacy body\n'
} > "$legacy_state/task.inbox/001.msg"
legacy_record=$(bash -c '. "$1"; fm_task_inbox_write_idempotent "$2" "$3" "$4" "$5"' _ \
  "$ROOT/bin/fm-task-inbox-lib.sh" "$legacy_state" task $'legacy body\n' '')
assert_equals "$legacy_state/task.inbox/001.msg" "$legacy_record" 'legacy inbox replay preserves trailing newlines'
assert_absent "$legacy_state/task.inbox/002.msg" 'legacy inbox replay does not allocate a duplicate'
pass 'legacy inbox idempotency compares exact record bodies'

home=$(make_home poll)
mkdir -p "$home/state/telegram"
cat > "$home/state/telegram/pairing.json" <<'JSON'
{"schema":"fm-telegram-pairing.v1","bot_username":"firstmate_test_bot","nonce_hash":"unused","nonce_expires_at":4102444800,"paired_user_id":"7","paired_chat_id":"8","paired_at":"2026-01-01T00:00:00Z"}
JSON
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":42,"message":{"message_id":1,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/note hello"}}]}
JSON
printf '%s\n' '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' > "$home/config/telegram-bot-token"
chmod 600 "$home/config/telegram-bot-token"
poll=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" poll --once --json)
assert_contains "$poll" '"processed": 1' 'poll processes update'
assert_contains "$(cat "$api/requests")" '"timeout":30' 'poll uses Telegram long-poll timeout'
assert_present "$home/state/telegram/offset" 'poll advances durable offset'
assert_present "$home/state/telegram/inbound/42.json" 'poll stores inbound update'
assert_present "$home/state/telegram/outbound/" 'poll stores outbound response directory'
assert_not_contains "$(cat "$home/state/telegram/outbound/42.json")" "$home" 'Telegram note response omits the local home path'
set +e
replay=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" poll --once --json 2>&1)
replay_code=$?
set -e
expect_code 0 "$replay_code" 'poll replay succeeds'
assert_equals 'telegram-bot' "$(FM_HOME="$home" "$ADAPTER" source-id)" 'adapter source id'
adapter_result=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" "$ADAPTER" poll)
assert_contains "$adapter_result" 'schema=fm-telegram-result.v1' 'adapter poll emits bounded result'
pass 'poll persists updates and deduplicates replay'
printf '%s\n' '{"ok":true,"result":{"bad":1}}' > "$api/updates"
enabled=$(FM_HOME="$home" "$TELEGRAM" enable)
assert_contains "$enabled" 'registered' 'enable registers Telegram polling source'
assert_present "$home/state/procevent/telegram-bot.source" 'enable persists Telegram source'
disabled=$(FM_HOME="$home" "$TELEGRAM" disable)
assert_contains "$disabled" 'retired' 'disable retires Telegram polling source'
assert_absent "$home/state/procevent/telegram-bot.source" 'disable removes Telegram source'
pass 'Telegram polling enablement uses the process-event owner'
set +e
bad=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" FM_TELEGRAM_POLL_TIMEOUT=1 \
  "$TELEGRAM" poll --once --json 2>&1)
bad_code=$?
set -e
expect_code 1 "$bad_code" 'malformed API response fails poll'
assert_contains "$bad" 'malformed or too large' 'poll reports malformed response'
assert_present "$home/state/telegram/errors/1.json" 'poll records bounded API failure'
assert_contains "$(cat "$home/state/telegram/errors/1.json")" 'malformed or too large' 'poll error record describes malformed response'
pass 'poll records malformed API failures without changing command state'
set +e
unavailable=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:1/bot" FM_TELEGRAM_POLL_TIMEOUT=1 \
  "$TELEGRAM" poll --once --json 2>&1)
unavailable_code=$?
set -e
expect_code 1 "$unavailable_code" 'unavailable Telegram API fails poll'
assert_contains "$unavailable" 'Telegram API unavailable' 'poll reports API outage'
assert_present "$home/state/telegram/errors/2.json" 'poll records API outage'
assert_contains "$(cat "$home/state/telegram/errors/2.json")" 'Telegram API unavailable' 'poll outage record is bounded'
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":43,"message":{"message_id":2,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/status"}}]}
JSON
touch "$api/fail-send"
set +e
response_outage=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" FM_TELEGRAM_POLL_TIMEOUT=1 \
  "$TELEGRAM" poll --once --json 2>&1)
response_outage_code=$?
set -e
expect_code 1 "$response_outage_code" 'failed Telegram response keeps poll pending'
assert_equals '43' "$(cat "$home/state/telegram/offset")" 'failed Telegram response does not publish offset'
assert_contains "$(cat "$home/state/telegram/inbox/43.json")" '"effect":"complete"' 'failed response keeps completed local effect'
rm -f "$api/fail-send"
response_retry=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" FM_TELEGRAM_POLL_TIMEOUT=1 \
  "$TELEGRAM" poll --once --json)
assert_contains "$response_retry" '"processed": 1' 'later poll retries durable response'
assert_equals '44' "$(cat "$home/state/telegram/offset")" 'later poll publishes pending offset'
assert_contains "$(cat "$home/state/telegram/inbox/43.json")" '"delivery":"sent"' 'later poll completes durable inbox record'
pass 'poll retries durable outbound responses without re-running local effects'

result="$TMP_ROOT/result"
printf '%s\n' 'schema=fm-telegram-result.v1' 'status=ok' > "$result"
assert_equals 'ok' "$(FM_HOME="$home" "$ADAPTER" classify "$result")" 'adapter classifies result'
set +e
FM_HOME="$home" "$ADAPTER" silent "$result" >/dev/null 2>&1
silent_code=$?
set -e
expect_code 0 "$silent_code" 'adapter suppresses routine poll wake'
pass 'process-event adapter uses stable source and bounded result classification'


paired_home() {  # <name>
  local home
  home=$(make_home "$1")
  mkdir -p "$home/state/telegram"
  cat > "$home/state/telegram/pairing.json" <<'JSON'
{"schema":"fm-telegram-pairing.v1","bot_username":"firstmate_test_bot","nonce_hash":"unused","nonce_expires_at":4102444800,"paired_user_id":"7","paired_chat_id":"8","paired_at":"2026-01-01T00:00:00Z"}
JSON
  printf '%s\n' '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' > "$home/config/telegram-bot-token"
  chmod 600 "$home/config/telegram-bot-token"
  printf '%s\n' "$home"
}

poll_home() {  # <home>
  FM_HOME="$1" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" FM_TELEGRAM_POLL_TIMEOUT=1 \
    "$TELEGRAM" poll --once --json
}

redirect_home=$(paired_home redirect)
touch "$api/redirect"
set +e
redirect_out=$(poll_home "$redirect_home" 2>&1)
redirect_code=$?
set -e
rm -f "$api/redirect"
expect_code 1 "$redirect_code" 'redirected Bot API response fails the poll'
assert_contains "$redirect_out" 'redirects are not allowed' 'redirect rejection is reported as a Telegram error'
assert_not_contains "$redirect_out" 'Traceback' 'redirect rejection does not crash the poller'
assert_contains "$(cat "$redirect_home/state/telegram/errors/1.json")" 'redirects are not allowed' 'redirect rejection is recorded as a poll error'
pass 'Bot API redirects are refused as recorded poll errors'

blocked_home=$(paired_home blocked)
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":50,"message":{"message_id":1,"from":{"id":31},"chat":{"id":32,"type":"private"},"text":"/status"}}]}
JSON
touch "$api/reject-send"
blocked_poll=$(poll_home "$blocked_home")
blocked_replay=$(poll_home "$blocked_home")
rm -f "$api/reject-send"
assert_contains "$blocked_poll" '"rejected": 1' 'blocked stranger update completes as rejected'
assert_equals '51' "$(cat "$blocked_home/state/telegram/offset")" 'permanent response rejection publishes the offset'
assert_contains "$(cat "$blocked_home/state/telegram/inbox/50.json")" '"delivery":"rejected"' 'permanent response rejection is a terminal delivery'
assert_contains "$(cat "$blocked_home/state/telegram/outbound/50.json")" '"delivery":"rejected"' 'outbound record keeps the terminal rejection'
assert_absent "$blocked_home/state/telegram/errors" 'permanent response rejection is not a retried poll error'
assert_contains "$blocked_replay" '"duplicates": 1' 'a replayed update with a rejected response is not resent'
pass 'permanent Bot API response rejections release the update offset'

unconfirmed_home=$(paired_home unconfirmed-poll)
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":55,"message":{"message_id":1,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/steer worker hello"}}]}
JSON
unconfirmed_poll=$(FM_ROOT_OVERRIDE="$unconfirmed_root" poll_home "$unconfirmed_home")
assert_contains "$unconfirmed_poll" '"unconfirmed": 1' 'poll counts an unconfirmed steer as unconfirmed'
assert_contains "$unconfirmed_poll" '"rejected": 0' 'poll does not count an unconfirmed steer as rejected'
assert_contains "$(cat "$unconfirmed_home/state/telegram/inbox/55.json")" '"outcome":"unconfirmed"' 'inbox records the unconfirmed steer outcome'
pass 'an unconfirmed steer is recorded and counted as unconfirmed rather than rejected'

switch_home=$(paired_home bot-switch)
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":60,"message":{"message_id":1,"from":{"id":41},"chat":{"id":42,"type":"private"},"text":"/status"}}]}
JSON
poll_home "$switch_home" >/dev/null
assert_equals '61' "$(cat "$switch_home/state/telegram/offset")" 'first bot publishes its offset'
printf '%s\n' '654321:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' > "$switch_home/config/telegram-bot-token"
: > "$api/requests"
switch_poll=$(poll_home "$switch_home")
assert_contains "$(head -1 "$api/requests")" '"offset":0' 'a different bot does not reuse the previous bot offset'
assert_contains "$switch_poll" '"duplicates": 0' 'previous bot records do not mark a reused update ID duplicate'
assert_contains "$switch_poll" '"rejected": 1' 'a different bot processes its reused update ID'
assert_equals '654321' "$(cat "$switch_home/state/telegram/bot-id")" 'polling records the bot that owns update state'
assert_present "$(find "$switch_home/state/telegram/retired" -path '*/123456-*/inbox/60.json' -print -quit)" 'previous bot update records are retired by bot identity'
pass 'a different bot starts from a fresh offset and update namespace'

stale_home=$(paired_home stale-offset)
printf '%s\n' '{"ok":true,"result":[]}' > "$api/updates"
printf '900\n' > "$stale_home/state/telegram/offset"
python3 -c 'import os, sys, time; old = time.time() - 2 * 86400; os.utime(sys.argv[1], (old, old))' "$stale_home/state/telegram/offset"
: > "$api/requests"
poll_home "$stale_home" >/dev/null
assert_contains "$(head -1 "$api/requests")" '"offset":0' 'an offset older than Telegram update retention is not reused'
printf '900\n' > "$stale_home/state/telegram/offset"
: > "$api/requests"
poll_home "$stale_home" >/dev/null
assert_contains "$(head -1 "$api/requests")" '"offset":900' 'a fresh offset is reused'
pass 'offsets older than Telegram update retention are not trusted'

redact_home=$(make_home redact-errors)
redact_setup=$(FM_HOME="$redact_home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" setup --json <<<'123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi')
redact_nonce=$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.parse_qs(urllib.parse.urlparse(json.load(sys.stdin)["deep_link"]).query)["start"][0])' <<<"$redact_setup")
ln -s "$TMP_ROOT/missing-lock" "$redact_home/state/telegram/.pairing.lock"
cat > "$api/updates" <<JSON
{"ok":true,"result":[{"update_id":70,"message":{"message_id":1,"from":{"id":51},"chat":{"id":52,"type":"private"},"text":"/start $redact_nonce"}}]}
JSON
: > "$api/requests"
redact_poll=$(poll_home "$redact_home")
redact_reply=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["text"])' "$redact_home/state/telegram/outbound/70.json")
assert_contains "$redact_poll" '"rejected": 1' 'pairing state failure is rejected'
assert_contains "$redact_reply" 'unsafe portable lock: [path redacted]' 'pairing failure reply keeps its reason'
assert_not_contains "$redact_reply" "$redact_home" 'pairing failure reply omits the local home path'
assert_not_contains "$(cat "$api/requests")" "$redact_home" 'Telegram never receives the local home path'
pass 'rejected command replies redact local filesystem paths'
