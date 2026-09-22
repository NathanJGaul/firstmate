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
            else:
                payload = {"ok": True, "result": {"message_id": 1}}
        else:
            payload = {"ok": False, "error_code": 404, "description": "unknown"}
        raw = json.dumps(payload).encode()
        self.send_response(200)
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
  "$TELEGRAM" setup --json --token '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi')
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

nonce=$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.parse_qs(urllib.parse.urlparse(json.load(sys.stdin)["deep_link"]).query)["start"][0])' <<<"$setup")
if grep -F '"nonce"' "$home/state/telegram/pairing.json" >/dev/null 2>&1; then
  fail 'pairing state stored the raw nonce'
fi

pair=$(FM_HOME="$home" "$TELEGRAM" pair --json --nonce "$nonce" --user-id 7 --chat-id 8)
assert_contains "$pair" '"paired": true' 'pairing accepts fresh nonce'
set +e
replay=$(FM_HOME="$home" "$TELEGRAM" pair --json --nonce "$nonce" --user-id 7 --chat-id 8 2>&1)
replay_code=$?
set -e
expect_code 1 "$replay_code" 'pairing nonce cannot be reused'
assert_contains "$replay" 'expired or invalid' 'replayed nonce is rejected'
pass 'pairing is one-time and rotates nonce'

expired_nonce='expired-nonce-123456'
expired_hash=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest())' "$expired_nonce")
cat > "$home/state/telegram/pairing.json" <<JSON
{"schema":"fm-telegram-pairing.v1","bot_username":"firstmate_test_bot","nonce_hash":"$expired_hash","nonce_expires_at":1,"paired_user_id":null,"paired_chat_id":null,"paired_at":null}
JSON
set +e
expired=$(FM_HOME="$home" "$TELEGRAM" pair --json --nonce "$expired_nonce" --user-id 7 --chat-id 8 2>&1)
expired_code=$?
malformed=$(FM_HOME="$home" "$TELEGRAM" pair --json --nonce 'bad nonce' --user-id 7 --chat-id 8 2>&1)
malformed_code=$?
set -e
expect_code 1 "$expired_code" 'expired pairing nonce is rejected'
assert_contains "$expired" 'expired or invalid' 'expired nonce rejection is explicit'
expect_code 1 "$malformed_code" 'malformed pairing nonce is rejected'
assert_contains "$malformed" 'nonce is malformed' 'malformed nonce rejection is explicit'
assert_contains "$(cat "$home/state/telegram/pairing.json")" '"paired_user_id":null' 'rejected nonces do not bind identity'
pass 'expired and malformed pairing nonces are rejected'

wire_home=$(make_home wire-pair)
wire_setup=$(FM_HOME="$wire_home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" setup --json --token '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi')
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
assert_contains "$steer" 'steer:worker --fire-and-forget ' 'steer uses a duplicate-tolerant delivery id'
assert_contains "$steer" ' hello' 'steer preserves reversible worker text'
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
set -e
expect_code 1 "$blank_note_code" 'whitespace-only note is rejected'
expect_code 1 "$blank_steer_code" 'whitespace-only steer is rejected'
expect_code 1 "$parser_slash_code" 'slash parser command is rejected'
expect_code 1 "$parser_dollar_code" 'codex parser command is rejected'
assert_contains "$parser_slash" 'parser-native prefix' 'slash parser rejection is explicit'
assert_contains "$parser_dollar" 'parser-native prefix' 'codex parser rejection is explicit'
pass 'paired command owner boundaries are enforced'

home=$(make_home poll)
mkdir -p "$home/state/telegram"
cat > "$home/state/telegram/pairing.json" <<'JSON'
{"schema":"fm-telegram-pairing.v1","bot_username":"firstmate_test_bot","nonce_hash":"unused","nonce_expires_at":4102444800,"paired_user_id":"7","paired_chat_id":"8","paired_at":"2026-01-01T00:00:00Z"}
JSON
cat > "$api/updates" <<'JSON'
{"ok":true,"result":[{"update_id":42,"message":{"message_id":1,"from":{"id":7},"chat":{"id":8,"type":"private"},"text":"/note hello"}}]}
JSON
printf '%s\n' '123456:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi' > "$home/config/telegram-bot-token"
poll=$(FM_HOME="$home" FM_TELEGRAM_API_BASE="http://127.0.0.1:$API_PORT/bot" \
  "$TELEGRAM" poll --once --json)
assert_contains "$poll" '"processed": 1' 'poll processes update'
assert_contains "$(cat "$api/requests")" '"timeout":30' 'poll uses Telegram long-poll timeout'
assert_present "$home/state/telegram/offset" 'poll advances durable offset'
assert_present "$home/state/telegram/inbound/42.json" 'poll stores inbound update'
assert_present "$home/state/telegram/outbound/" 'poll stores outbound response directory'
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

