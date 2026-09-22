#!/usr/bin/env python3
"""Local Telegram Bot API transport for one Firstmate home.

Only outbound HTTPS is used. Telegram text is data: command dispatch uses fixed
argv vectors and never invokes a shell.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "fm-telegram-pairing.v1"
RESULT_SCHEMA = "fm-telegram-result.v1"
TOKEN_NAME = "telegram-bot-token"
MAX_UPDATE_BYTES = 256 * 1024
MAX_COMMAND_BYTES = 4096
MAX_MESSAGE_CHARS = 4096
MAX_RESPONSE_BYTES = 256 * 1024
DEFAULT_POLL_TIMEOUT = 30
MAX_POLL_TIMEOUT = 50
DEFAULT_PAIRING_TTL = 600
TOKEN_RE = re.compile(r"^[0-9]+:[A-Za-z0-9_-]{20,}$")
ID_RE = re.compile(r"^[0-9]+$")
CHAT_ID_RE = re.compile(r"^-?[0-9]+$")
WORKER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")




class TelegramError(Exception):
    pass


def home() -> Path:
    return Path(os.environ.get("FM_HOME", Path(__file__).resolve().parent.parent))


def root() -> Path:
    return Path(os.environ.get("FM_ROOT_OVERRIDE", Path(__file__).resolve().parent.parent))


def config_dir() -> Path:
    return Path(os.environ.get("FM_CONFIG_OVERRIDE", home() / "config"))


def state_dir() -> Path:
    return Path(os.environ.get("FM_STATE_OVERRIDE", home() / "state")) / "telegram"


def now() -> int:
    return int(time.time())


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def ensure_private_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.is_symlink() or not path.is_dir():
        raise TelegramError(f"unsafe state directory: {path}")
    os.chmod(path, 0o700)


def atomic_write(path: Path, data: bytes) -> None:
    ensure_private_dir(path.parent)
    if path.is_symlink():
        raise TelegramError(f"unsafe state path: {path}")
    tmp = path.parent / f".{path.name}.{os.getpid()}.{secrets.token_hex(4)}.tmp"
    try:
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
        os.chmod(path, 0o600)
    finally:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass


def read_text(path: Path) -> str:
    if path.is_symlink() or not path.is_file():
        raise TelegramError(f"missing configuration: {path}")
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise TelegramError(f"cannot read configuration: {path}") from exc
    lines = raw.splitlines()
    if len(lines) != 1:
        raise TelegramError(f"configuration must contain one line: {path}")
    return lines[0].strip()




def token_value() -> str:
    value = os.environ.get("FM_TELEGRAM_BOT_TOKEN", "")
    if not value:
        path = config_dir() / TOKEN_NAME
        if path.exists():
            value = read_text(path)
    if not TOKEN_RE.fullmatch(value):
        raise TelegramError(f"invalid Telegram bot token; write one line into {config_dir() / TOKEN_NAME}")
    return value


def api_base() -> str:
    return os.environ.get("FM_TELEGRAM_API_BASE", "https://api.telegram.org/bot").rstrip("/")


def api_call(method: str, params: dict[str, Any], timeout: float = 35) -> dict[str, Any]:
    token = token_value()
    url = f"{api_base()}/{urllib.parse.quote(token, safe='')}/{method}"
    body = json.dumps(params, separators=(",", ":")).encode("utf-8")
    request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
    except (OSError, urllib.error.URLError, TimeoutError) as exc:
        raise TelegramError("Telegram API unavailable") from exc
    if len(raw) > MAX_RESPONSE_BYTES:
        raise TelegramError("Telegram API response is too large")
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TelegramError("Telegram API returned malformed JSON") from exc
    if not isinstance(payload, dict) or payload.get("ok") is not True:
        raise TelegramError("Telegram API rejected request")
    return payload


def pairing_path() -> Path:
    return state_dir() / "pairing.json"


def load_pairing() -> dict[str, Any]:
    path = pairing_path()
    if not path.exists():
        raise TelegramError("Telegram is not set up")
    if path.is_symlink():
        raise TelegramError("unsafe pairing state")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TelegramError("pairing state is malformed") from exc
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise TelegramError("pairing state has incompatible schema")
    return value


def save_pairing(value: dict[str, Any]) -> None:
    atomic_write(pairing_path(), (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode())


def nonce_hash(nonce: str) -> str:
    if not isinstance(nonce, str) or not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", nonce):
        raise TelegramError("pairing nonce is malformed")
    return hashlib.sha256(nonce.encode("ascii")).hexdigest()




def new_nonce() -> str:
    return secrets.token_urlsafe(24)


def deep_link(username: str, nonce: str) -> str:
    return f"https://t.me/{username}?start={urllib.parse.quote(nonce, safe='')}"


def qr(link: str) -> str:
    try:
        proc = subprocess.run(["qrencode", "-t", "ANSIUTF8", "-o", "-", link], capture_output=True, text=True, timeout=3, check=False)
    except (OSError, subprocess.SubprocessError):
        return ""
    return proc.stdout if proc.returncode == 0 else ""


def setup(token: str, machine: bool) -> dict[str, Any]:
    if not TOKEN_RE.fullmatch(token):
        raise TelegramError("invalid Telegram bot token")
    os.environ["FM_TELEGRAM_BOT_TOKEN"] = token
    me = api_call("getMe", {})
    result = me.get("result")
    username = result.get("username") if isinstance(result, dict) else None
    if not isinstance(username, str) or not re.fullmatch(r"[A-Za-z0-9_]{1,64}", username):
        raise TelegramError("Telegram getMe returned no usable bot username")
    ensure_private_dir(config_dir())
    atomic_write(config_dir() / TOKEN_NAME, (token + "\n").encode())
    nonce = new_nonce()
    record = {
        "schema": SCHEMA,
        "bot_username": username,
        "nonce_hash": nonce_hash(nonce),
        "nonce_expires_at": now() + DEFAULT_PAIRING_TTL,
        "paired_user_id": None,
        "paired_chat_id": None,
        "paired_at": None,
    }
    save_pairing(record)
    link = deep_link(username, nonce)
    picture = qr(link)
    output = {
        "schema": "fm-telegram-setup.v1",
        "bot_username": username,
        "deep_link": link,
        "qr": picture or None,
        "nonce_expires_at": record["nonce_expires_at"],
    }
    if machine:
        return output
    print(f"Telegram bot: @{username}")
    print(f"Pairing link: {link}")
    if picture:
        print(picture, end="")
    else:
        print("QR unavailable; open the pairing link above.")
    return output




def pair(nonce: str, user_id: str, chat_id: str) -> dict[str, Any]:
    if not ID_RE.fullmatch(user_id) or not CHAT_ID_RE.fullmatch(chat_id):
        raise TelegramError("Telegram identity must be numeric")
    candidate_hash = nonce_hash(nonce)
    record = load_pairing()
    expires = record.get("nonce_expires_at")
    valid_nonce = isinstance(expires, int) and not isinstance(expires, bool) and expires > now() and secrets.compare_digest(candidate_hash, str(record.get("nonce_hash", "")))
    if not valid_nonce or record.get("paired_user_id") is not None or record.get("paired_chat_id") is not None:
        raise TelegramError("pairing nonce is expired or invalid")
    rotated = new_nonce()
    record.update({"nonce_hash": nonce_hash(rotated), "nonce_expires_at": now() + DEFAULT_PAIRING_TTL, "paired_user_id": user_id, "paired_chat_id": chat_id, "paired_at": iso_now()})
    save_pairing(record)
    return {"schema": "fm-telegram-pairing-result.v1", "paired": True, "user_id": user_id, "chat_id": chat_id}




def validate_text(text: str, label: str = "text") -> str:
    if not isinstance(text, str) or not text or len(text.encode("utf-8")) > MAX_COMMAND_BYTES:
        raise TelegramError(f"{label} is empty or too large")
    if any(ord(char) < 32 or ord(char) == 127 for char in text):
        raise TelegramError(f"{label} contains control bytes")
    return text


def identity(record: dict[str, Any], user_id: Any, chat_id: Any) -> bool:
    return ID_RE.fullmatch(str(user_id)) is not None and CHAT_ID_RE.fullmatch(str(chat_id)) is not None and str(user_id) == str(record.get("paired_user_id")) and str(chat_id) == str(record.get("paired_chat_id"))


def bounded(text: str) -> str:
    return text[:MAX_MESSAGE_CHARS]


def owner(argv: list[str], stdin: str = "") -> str:
    try:
        proc = subprocess.run(argv, cwd=root(), env={**os.environ, "FM_HOME": str(home())}, input=stdin, text=True, capture_output=True, timeout=20, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise TelegramError("Firstmate owner script unavailable") from exc
    if proc.returncode != 0:
        raise TelegramError("Firstmate owner script rejected request")
    return bounded(proc.stdout.strip() or "completed")

def dispatch(text: str, user_id: str, chat_id: str, update_id: str) -> str:
    if not ID_RE.fullmatch(user_id) or not CHAT_ID_RE.fullmatch(chat_id) or not ID_RE.fullmatch(update_id):
        raise TelegramError("Telegram identity or update ID is malformed")
    record = load_pairing()
    if not identity(record, user_id, chat_id):
        raise TelegramError("Telegram identity is not paired")
    text = validate_text(text)
    if text == "/status":
        return owner([str(root() / "bin/fm-bearings-snapshot.sh"), "--json"])
    if text == "/decisions":
        return owner([str(root() / "bin/fm-bearings-snapshot.sh"), "--json", "--all-decisions"])
    if text.startswith("/note "):
        body = validate_text(text[6:], "note")
        return owner([str(root() / "bin/fm-inbox.sh"), "note", "--request-id", f"telegram-{update_id}", "--json", "-"], body)
    if text.startswith("/steer "):
        rest = validate_text(text[7:], "steer")
        target, separator, body = rest.partition(" ")
        if not separator or not WORKER_RE.fullmatch(target):
            raise TelegramError("steer target or text is invalid")
        body = validate_text(body, "steer")
        return owner([str(root() / "bin" / "fm-send.sh"), target, body])
    raise TelegramError("unsupported Telegram command")


def poll_timeout() -> int:
    raw = os.environ.get("FM_TELEGRAM_POLL_TIMEOUT", str(DEFAULT_POLL_TIMEOUT))
    try:
        value = int(raw)
    except ValueError as exc:
        raise TelegramError("Telegram poll timeout is not an integer") from exc
    if value < 1 or value > MAX_POLL_TIMEOUT:
        raise TelegramError(f"Telegram poll timeout must be between 1 and {MAX_POLL_TIMEOUT} seconds")
    return value


def identity_value(value: Any, pattern: re.Pattern[str]) -> str | None:
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        return None
    candidate = str(value)
    return candidate if pattern.fullmatch(candidate) else None


def record_poll_error(message: str) -> None:
    try:
        directory = state_dir() / "errors"
        seq = next_sequence(directory)
        record_json(directory, f"{seq}.json", {"schema": "fm-telegram-error.v1", "operation": "poll", "error": bounded(message), "at": iso_now()})
    except (OSError, TelegramError):
        pass


def claim_marker(path: Path) -> bool:
    ensure_private_dir(path.parent)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise TelegramError(f"unsafe processed-update marker: {path}")
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        return False
    except OSError as exc:
        raise TelegramError("cannot persist processed-update marker") from exc
    with os.fdopen(fd, "wb") as stream:
        stream.write(b"\n")
        stream.flush()
        os.fsync(stream.fileno())
    return True



def _poll(machine: bool, event: bool = False) -> dict[str, Any]:
    offset = read_offset()
    timeout = poll_timeout()
    response = api_call("getUpdates", {"offset": offset, "timeout": timeout, "allowed_updates": ["message"]}, timeout=timeout + 5)
    updates = response.get("result")
    if not isinstance(updates, list) or len(json.dumps(updates).encode("utf-8")) > MAX_UPDATE_BYTES:
        raise TelegramError("Telegram update response is malformed or too large")
    inbound = state_dir() / "inbound"
    processed_dir = state_dir() / "processed"
    processed = duplicates = rejected = 0
    highest = offset
    for update in updates:
        update_id_value = update.get("update_id") if isinstance(update, dict) else None
        if isinstance(update_id_value, bool) or not isinstance(update_id_value, int) or update_id_value < 0:
            raise TelegramError("Telegram update is malformed")
        update_id = str(update_id_value)
        highest = max(highest, update_id_value + 1)
        marker = processed_dir / update_id
        if not claim_marker(marker):
            duplicates += 1
            continue
        message = update.get("message")
        user_id = chat_id = None
        text = ""
        if isinstance(message, dict):
            sender = message.get("from")
            chat = message.get("chat")
            user_id = identity_value(sender.get("id") if isinstance(sender, dict) else None, ID_RE)
            chat_id = identity_value(chat.get("id") if isinstance(chat, dict) else None, CHAT_ID_RE)
            text = message.get("text", "")
        valid_message = user_id is not None and chat_id is not None and isinstance(text, str)
        if not valid_message:
            rejected += 1
            text = ""
        inbound_record = {"schema": "fm-telegram-inbound.v1", "update_id": update_id, "at": iso_now(), "user_id": user_id, "chat_id": chat_id, "text": bounded(text)}
        record_json(inbound, f"{update_id}.json", inbound_record)
        atomic_write(marker, b"\n")
        try:
            if valid_message and text.startswith("/start "):
                pairing = load_pairing()
                if pairing.get("paired_user_id") is None:
                    pair(text[7:], user_id, chat_id)
                    reply = "Telegram paired."
                else:
                    reply = dispatch(text, user_id, chat_id, update_id)
            elif valid_message:
                reply = dispatch(text, user_id, chat_id, update_id)
            else:
                raise TelegramError("Telegram message identity is malformed")
            send_message(chat_id, update_id, text.split(" ", 1)[0], reply)
            processed += 1
        except TelegramError as exc:
            rejected += 1
            if chat_id is not None:
                try:
                    send_message(chat_id, update_id, text.split(" ", 1)[0] if text else "rejected", str(exc))
                except TelegramError:
                    pass
    if highest != offset:
        atomic_write(offset_path(), f"{highest}\n".encode())
    output = {"schema": "fm-telegram-poll.v1", "processed": processed, "duplicates": duplicates, "rejected": rejected, "next_offset": highest}
    if event:
        print(f"schema={RESULT_SCHEMA}\nstatus=ok\nprocessed={processed}\nduplicates={duplicates}\nrejected={rejected}\n")
    elif machine:
        print(json.dumps(output, sort_keys=True))
    else:
        print(f"processed {processed}; duplicates {duplicates}; rejected {rejected}")
    return output


def poll(machine: bool, event: bool = False) -> dict[str, Any]:
    try:
        return _poll(machine, event)
    except TelegramError as exc:
        record_poll_error(str(exc))
        raise


def record_json(directory: Path, name: str, value: dict[str, Any]) -> None:
    raw = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    if len(raw) > MAX_RESPONSE_BYTES:
        raise TelegramError("Telegram record is too large")
    atomic_write(directory / name, raw)


def next_sequence(directory: Path) -> str:
    ensure_private_dir(directory)
    values = []
    for path in directory.glob("*.json"):
        try:
            values.append(int(path.stem))
        except ValueError:
            continue
    return str(max(values, default=0) + 1)


def send_message(chat_id: str, update_id: str, command: str, text: str) -> None:
    text = bounded(text)
    out_dir = state_dir() / "outbound"
    seq = next_sequence(out_dir)
    record = {"schema": "fm-telegram-outbound.v1", "sequence": seq, "update_id": update_id, "chat_id": chat_id, "command": command, "text": text, "at": iso_now(), "api_ok": False}
    try:
        api_call("sendMessage", {"chat_id": int(chat_id), "text": text})
        record["api_ok"] = True
    except TelegramError:
        record["error"] = "Telegram API unavailable or rejected response"
        record_json(out_dir, f"{seq}.json", record)
        raise
    record_json(out_dir, f"{seq}.json", record)


def offset_path() -> Path:
    return state_dir() / "offset"


def read_offset() -> int:
    path = offset_path()
    if not path.exists():
        return 0
    value = read_text(path)
    if not value.isdigit():
        raise TelegramError("Telegram offset is malformed")
    return int(value)




def enable() -> str:
    token_value()
    load_pairing()
    adapter = root() / "bin" / "fm-procevent-telegram.sh"
    runner = root() / "bin" / "fm-procevent.sh"
    proc = subprocess.run([str(runner), "register", "telegram", "telegram-bot", "--", str(adapter), "poll"], cwd=root(), env={**os.environ, "FM_HOME": str(home())}, capture_output=True, text=True, timeout=20, check=False)
    if proc.returncode:
        raise TelegramError("Telegram polling registration failed")
    return proc.stdout.strip() or "registered Telegram polling"


def disable() -> str:
    proc = subprocess.run([str(root() / "bin" / "fm-procevent.sh"), "retire", "telegram-bot"], cwd=root(), env={**os.environ, "FM_HOME": str(home())}, capture_output=True, text=True, timeout=20, check=False)
    if proc.returncode:
        raise TelegramError("Telegram polling retirement failed")
    return proc.stdout.strip() or "retired Telegram polling"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="local outbound Telegram control")
    parser.add_argument("--json", action="store_true", dest="global_json")
    sub = parser.add_subparsers(dest="command", required=True)
    setup_parser = sub.add_parser("setup")
    setup_parser.add_argument("--token", required=True)
    setup_parser.add_argument("--json", action="store_true")
    pair_parser = sub.add_parser("pair")
    pair_parser.add_argument("--nonce", required=True)
    pair_parser.add_argument("--user-id", required=True)
    pair_parser.add_argument("--chat-id", required=True)
    pair_parser.add_argument("--json", action="store_true")
    dispatch_parser = sub.add_parser("dispatch")
    dispatch_parser.add_argument("--user-id", required=True)
    dispatch_parser.add_argument("--chat-id", required=True)
    dispatch_parser.add_argument("--update-id", required=True)
    dispatch_parser.add_argument("--text", required=True)
    dispatch_parser.add_argument("--json", action="store_true")
    poll_parser = sub.add_parser("poll")
    poll_parser.add_argument("--once", action="store_true")
    poll_parser.add_argument("--event", action="store_true")
    poll_parser.add_argument("--json", action="store_true")
    sub.add_parser("enable")
    sub.add_parser("disable")
    args = parser.parse_args(argv)
    try:
        if args.command == "setup":
            result = setup(args.token, args.json or args.global_json)
            if args.json or args.global_json:
                print(json.dumps(result, sort_keys=True))
        elif args.command == "pair":
            result = pair(args.nonce, args.user_id, args.chat_id)
            print(json.dumps(result, sort_keys=True) if args.json or args.global_json else "paired")
        elif args.command == "dispatch":
            result = dispatch(args.text, args.user_id, args.chat_id, args.update_id)
            print(json.dumps({"schema": "fm-telegram-dispatch.v1", "text": bounded(result)}, sort_keys=True) if args.json or args.global_json else result)
        elif args.command == "poll":
            poll(args.json or args.global_json, args.event)
        elif args.command == "enable":
            print(enable())
        elif args.command == "disable":
            print(disable())
        return 0
    except TelegramError as exc:
        print(f"fm-telegram: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
