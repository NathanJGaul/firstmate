#!/usr/bin/env python3
"""Local Telegram Bot API transport for one Firstmate home.

Only outbound HTTPS is used. Telegram text is data: command dispatch uses fixed
argv vectors and never invokes a shell.
"""
from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import re
import secrets
import shutil
import shlex
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
MAX_TELEGRAM_ID = 2**63 - 1
MAX_TELEGRAM_OFFSET = MAX_TELEGRAM_ID + 1
PORTABLE_MAX_STATUS_BYTES = 256 * 1024
PORTABLE_MAX_METADATA_BYTES = 64 * 1024
PORTABLE_MAX_RECORD_BYTES = 16 * 1024
PORTABLE_MAX_RECORDS = 4096
PORTABLE_MAX_TASKS = 256
PORTABLE_OWNER_TIMEOUT = 20
OWNER_TIMEOUT = 20
DEFAULT_SEND_REMOTE_BUDGET = 30
STEER_UNCONFIRMED = "steer unconfirmed - may have landed; check before resending"
DEFAULT_POLL_TIMEOUT = 30
MAX_POLL_TIMEOUT = 50
DEFAULT_PAIRING_TTL = 600
TELEGRAM_UPDATE_RETENTION = 24 * 60 * 60
TELEGRAM_REJECTED_CODES = (400, 403)
UPDATE_STATE_NAMES = ("offset", "inbox", "inbound", "processed", "outbound")
DEFAULT_TELEGRAM_PAGE_SIZE = 10
MAX_TELEGRAM_PAGE_SIZE = 50
MAX_TELEGRAM_PAGE = 100000
TOKEN_RE = re.compile(r"^[0-9]+:[A-Za-z0-9_-]{20,}$")
ID_RE = re.compile(r"^[0-9]+$")
CHAT_ID_RE = re.compile(r"^-?[0-9]+$")
WORKER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
NOTE_ID_RE = re.compile(r"^[0-9]+-[A-Za-z0-9._-]+$")
FROMFIRST_MARK = "[fm-from-firstmate]\u2063"
_PORTABLE_DEADLINE: float | None = None


def _portable_timeout(default: float) -> float:
    if _PORTABLE_DEADLINE is None:
        return default
    remaining = _PORTABLE_DEADLINE - time.monotonic()
    if remaining <= 0:
        raise TelegramError("Firstmate owner call timed out")
    return min(default, remaining)


class TelegramError(Exception):
    pass


class DurableOwnerError(TelegramError):
    pass


class TelegramRejected(TelegramError):
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


def _windows_private_path(path: Path) -> None:
    if os.name != "nt":
        return
    principal = os.environ.get("USERDOMAIN", "")
    username = os.environ.get("USERNAME", "")
    if principal and username:
        principal = f"{principal}\\{username}"
    else:
        try:
            result = subprocess.run(["whoami"], capture_output=True, text=False, timeout=_portable_timeout(5), check=False)
            principal = result.stdout.decode("utf-8").strip()
        except (OSError, subprocess.SubprocessError, UnicodeDecodeError) as exc:
            raise TelegramError("Windows private ACL could not identify the current user") from exc
    if not principal or "\n" in principal or "\r" in principal:
        raise TelegramError("Windows private ACL could not identify the current user")
    try:
        _portable_check_deadline()
        reset = subprocess.run(["icacls", str(path), "/reset"], capture_output=True, text=False, timeout=_portable_timeout(5), check=False)
        _portable_check_deadline()
        restrict = subprocess.run(["icacls", str(path), "/inheritance:r", "/grant:r", f"{principal}:F"], capture_output=True, text=False, timeout=_portable_timeout(5), check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise TelegramError(f"Windows private ACL is unavailable: {path}") from exc
    if reset.returncode != 0 or restrict.returncode != 0:
        raise TelegramError(f"Windows private ACL could not be applied: {path}")


def _secure_private_path(path: Path, mode: int) -> None:
    _portable_check_deadline()
    os.chmod(path, mode)
    _windows_private_path(path)


def ensure_private_dir(path: Path) -> None:
    try:
        _portable_check_deadline()
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        _portable_check_deadline()
        if path.is_symlink() or not path.is_dir():
            raise TelegramError(f"unsafe state directory: {path}")
        _secure_private_path(path, 0o700)
    except OSError as exc:
        raise TelegramError(f"private directory could not be prepared: {path}") from exc


def atomic_write(path: Path, data: bytes) -> None:
    ensure_private_dir(path.parent)
    if path.is_symlink():
        raise TelegramError(f"unsafe state path: {path}")
    tmp = path.parent / f".{path.name}.{os.getpid()}.{secrets.token_hex(4)}.tmp"
    try:
        _portable_check_deadline()
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        _portable_check_deadline()
        _secure_private_path(tmp, 0o600)
        _portable_check_deadline()
        os.replace(tmp, path)
    except OSError as exc:
        raise TelegramError(f"private state could not be persisted: {path}") from exc
    finally:
        try:
            tmp.unlink()
        except (FileNotFoundError, OSError):
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




def verify_token_path(path: Path) -> None:
    try:
        info = path.lstat()
    except OSError as exc:
        raise TelegramError(f"cannot inspect Telegram bot token: {path}") from exc
    if path.is_symlink() or not path.is_file():
        raise TelegramError(f"unsafe Telegram bot token file: {path}")
    if os.name == "nt":
        _windows_private_path(path)
        return
    if info.st_mode & 0o077:
        raise TelegramError("Telegram bot token file is not private")
    if hasattr(os, "getuid") and info.st_uid != os.getuid():
        raise TelegramError("Telegram bot token file is not owned by the current user")


def token_value() -> str:
    value = os.environ.get("FM_TELEGRAM_BOT_TOKEN", "")
    if not value:
        path = config_dir() / TOKEN_NAME
        if path.exists() or path.is_symlink():
            verify_token_path(path)
            value = read_text(path)
    if not TOKEN_RE.fullmatch(value):
        raise TelegramError(f"invalid Telegram bot token; write one line into {config_dir() / TOKEN_NAME}")
    return value


def _validate_api_url(value: str) -> urllib.parse.SplitResult:
    try:
        parsed = urllib.parse.urlsplit(value)
        hostname = parsed.hostname.lower() if parsed.hostname else ""
        parsed.port
    except ValueError as exc:
        raise TelegramError("Telegram API base URL is malformed") from exc
    if parsed.scheme != "https" and not (parsed.scheme == "http" and hostname in {"localhost", "127.0.0.1"}):
        raise TelegramError("Telegram API base URL must use HTTPS except for localhost or 127.0.0.1 test endpoints")
    if not parsed.netloc or parsed.username is not None or parsed.password is not None:
        raise TelegramError("Telegram API base URL is malformed")
    return parsed


def api_base() -> str:
    value = os.environ.get("FM_TELEGRAM_API_BASE", "https://api.telegram.org/bot").rstrip("/")
    _validate_api_url(value)
    return value


class _RejectRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req: urllib.request.Request, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> None:
        raise TelegramError("Telegram API redirects are not allowed")


def api_call(method: str, params: dict[str, Any], timeout: float = 35, token: str | None = None) -> dict[str, Any]:
    base = api_base()
    token = token or token_value()
    url = f"{base}{urllib.parse.quote(token, safe=':')}/{method}"
    body = json.dumps(params, separators=(",", ":")).encode("utf-8")
    request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    try:
        opener = urllib.request.build_opener(_RejectRedirects())
        with opener.open(request, timeout=timeout) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
    except TelegramError:
        raise
    except urllib.error.HTTPError as exc:
        if exc.code in TELEGRAM_REJECTED_CODES:
            raise TelegramRejected("Telegram API rejected request") from exc
        raise TelegramError("Telegram API unavailable") from exc
    except (OSError, urllib.error.URLError, TimeoutError) as exc:
        raise TelegramError("Telegram API unavailable") from exc
    if len(raw) > MAX_RESPONSE_BYTES:
        raise TelegramError("Telegram API response is too large")
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError, RecursionError) as exc:
        raise TelegramError("Telegram API returned malformed JSON") from exc
    if not isinstance(payload, dict) or payload.get("ok") is not True:
        if isinstance(payload, dict) and payload.get("error_code") in TELEGRAM_REJECTED_CODES:
            raise TelegramRejected("Telegram API rejected request")
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


def numeric_value(value: Any, pattern: re.Pattern[str], maximum: int = MAX_TELEGRAM_ID) -> str | None:
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        return None
    try:
        candidate = str(value)
    except (ValueError, OverflowError):
        return None
    if pattern.fullmatch(candidate) is None:
        return None
    try:
        number = int(candidate)
    except (TypeError, ValueError, OverflowError):
        return None
    return str(number) if abs(number) <= maximum else None


def new_nonce() -> str:
    return secrets.token_urlsafe(24)


def deep_link(username: str, nonce: str) -> str:
    return f"https://t.me/{username}?start={urllib.parse.quote(nonce, safe='')}"


QR_BLOCKS_M: dict[int, tuple[tuple[int, int, int], ...]] = {
    1: ((1, 26, 16),),
    2: ((1, 44, 28),),
    3: ((1, 70, 44),),
    4: ((2, 50, 32),),
    5: ((2, 67, 43),),
    6: ((4, 43, 27),),
    7: ((4, 49, 31),),
    8: ((2, 60, 38), (2, 61, 39)),
    9: ((3, 58, 36), (2, 59, 37)),
    10: ((4, 69, 43), (1, 70, 44)),
}
QR_ALIGNMENT: dict[int, tuple[int, ...]] = {
    2: (6, 18), 3: (6, 22), 4: (6, 26), 5: (6, 30), 6: (6, 34),
    7: (6, 22, 38), 8: (6, 24, 42), 9: (6, 26, 46), 10: (6, 28, 50),
}


def qr_gf_mul(left: int, right: int) -> int:
    result = 0
    while right:
        if right & 1:
            result ^= left
        right >>= 1
        left <<= 1
        if left & 0x100:
            left ^= 0x11D
    return result


def qr_ecc(data: list[int], count: int) -> list[int]:
    generator = [1]
    value = 1
    for _ in range(count):
        generator = [coefficient ^ qr_gf_mul(value, generator[index - 1]) if index else coefficient
                     for index, coefficient in enumerate(generator + [0])]
        value = qr_gf_mul(value, 2)
    remainder = [0] * count
    for byte in data:
        factor = byte ^ remainder[0]
        remainder = remainder[1:] + [0]
        for index, coefficient in enumerate(generator[1:]):
            remainder[index] ^= qr_gf_mul(coefficient, factor)
    return remainder


def qr_bch(value: int, polynomial: int, degree: int) -> int:
    remainder = value << degree
    for bit in range(value.bit_length() + degree - 1, degree - 1, -1):
        if remainder & (1 << bit):
            remainder ^= polynomial << (bit - degree)
    return remainder


def qr_base(version: int) -> list[list[bool | None]]:
    size = version * 4 + 17
    modules: list[list[bool | None]] = [[None] * size for _ in range(size)]

    def finder(row: int, column: int) -> None:
        for dy in range(-1, 8):
            for dx in range(-1, 8):
                y, x = row + dy, column + dx
                if 0 <= y < size and 0 <= x < size:
                    modules[y][x] = 0 <= dx <= 6 and 0 <= dy <= 6 and (
                        dx in (0, 6) or dy in (0, 6) or 2 <= dx <= 4 and 2 <= dy <= 4
                    )

    finder(0, 0)
    finder(size - 7, 0)
    finder(0, size - 7)
    for coordinate in QR_ALIGNMENT.get(version, ()):
        for row in QR_ALIGNMENT.get(version, ()):
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
    version_bits = (version << 12) | qr_bch(version, 0x1F25, 12)
    if version >= 7:
        for index in range(18):
            bit = bool((version_bits >> index) & 1)
            modules[index // 3][index % 3 + size - 11] = bit
            modules[index % 3 + size - 11][index // 3] = bit
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
    return modules


def qr_mask(mask: int, row: int, column: int) -> bool:
    if mask == 0:
        return (row + column) % 2 == 0
    if mask == 1:
        return row % 2 == 0
    if mask == 2:
        return column % 3 == 0
    if mask == 3:
        return (row + column) % 3 == 0
    if mask == 4:
        return (row // 2 + column // 3) % 2 == 0
    if mask == 5:
        return row * column % 2 + row * column % 3 == 0
    if mask == 6:
        return (row * column % 2 + row * column % 3) % 2 == 0
    return ((row * column) % 3 + (row + column) % 2) % 2 == 0


def qr_draw_data(modules: list[list[bool | None]], bits: list[int], mask: int) -> None:
    size = len(modules)
    bit_index = 0
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
                    bit = bits[bit_index] if bit_index < len(bits) else 0
                    bit_index += 1
                    modules[row_index][column_index] = bool(bit ^ qr_mask(mask, row_index, column_index))
            row -= 1
        row = size - 1
        upward = not upward
        column -= 2
    if bit_index < len(bits):
        raise TelegramError("bundled QR renderer produced an incomplete symbol")


def qr_draw_format(modules: list[list[bool | None]], mask: int) -> None:
    data = mask
    format_bits = ((data << 10) | qr_bch(data, 0x537, 10)) ^ 0x5412
    size = len(modules)
    for index in range(15):
        bit = bool((format_bits >> index) & 1)
        if index < 6:
            modules[index][8] = bit
        elif index < 8:
            modules[index + 1][8] = bit
        else:
            modules[size - 15 + index][8] = bit
        if index < 8:
            modules[8][size - index - 1] = bit
        elif index == 8:
            modules[8][7] = bit
        else:
            modules[8][15 - index - 1] = bit


def qr_penalty(modules: list[list[bool | None]]) -> int:
    size = len(modules)
    score = 0
    lines = [modules[row] for row in range(size)] + [[modules[row][column] for row in range(size)] for column in range(size)]
    for line in lines:
        run = 1
        for index in range(1, size):
            if line[index] == line[index - 1]:
                run += 1
            else:
                if run >= 5:
                    score += run - 2
                run = 1
        if run >= 5:
            score += run - 2
        for index in range(size - 6):
            if line[index:index + 7] == [True, False, True, True, True, False, True]:
                before = index >= 4 and all(value is False for value in line[index - 4:index])
                after = index + 11 <= size and all(value is False for value in line[index + 7:index + 11])
                if before or after:
                    score += 40
    for row in range(size - 1):
        for column in range(size - 1):
            block = modules[row][column]
            if block == modules[row + 1][column] == modules[row][column + 1] == modules[row + 1][column + 1]:
                score += 3
    dark = sum(1 for row in modules for value in row if value)
    score += abs(dark * 20 - size * size * 10) // (size * size) * 10
    return score


def qr(link: str) -> str:
    payload = link.encode("utf-8")
    selected_version = None
    selected_bits: list[int] = []
    for version, specifications in QR_BLOCKS_M.items():
        capacity = sum(count * data_count for count, _, data_count in specifications)
        if len(payload) > capacity - 2:
            continue
        bits = [0, 1, 0, 0]
        bits.extend((len(payload) >> shift) & 1 for shift in range(7, -1, -1))
        for byte in payload:
            bits.extend((byte >> shift) & 1 for shift in range(7, -1, -1))
        bits.extend([0] * min(4, capacity * 8 - len(bits)))
        bits.extend([0] * ((-len(bits)) % 8))
        pad = [1, 1, 1, 0, 1, 1, 0, 0]
        while len(bits) < capacity * 8:
            bits.extend(pad[:min(8, capacity * 8 - len(bits))])
            pad = [0, 0, 0, 1, 0, 0, 0, 1] if pad == [1, 1, 1, 0, 1, 1, 0, 0] else [1, 1, 1, 0, 1, 1, 0, 0]
        selected_version = version
        selected_bits = bits
        break
    if selected_version is None:
        raise TelegramError("deep link is too long for the bundled QR renderer")
    codewords = [sum(selected_bits[index + offset] << (7 - offset) for offset in range(8)) for index in range(0, len(selected_bits), 8)]
    blocks: list[list[int]] = []
    ecc_blocks: list[list[int]] = []
    cursor = 0
    for count, total_count, data_count in QR_BLOCKS_M[selected_version]:
        for _ in range(count):
            block = codewords[cursor:cursor + data_count]
            cursor += data_count
            blocks.append(block)
            ecc_blocks.append(qr_ecc(block, total_count - data_count))
    interleaved = []
    for index in range(max(len(block) for block in blocks)):
        interleaved.extend(block[index] for block in blocks if index < len(block))
    for index in range(max(len(block) for block in ecc_blocks)):
        interleaved.extend(block[index] for block in ecc_blocks if index < len(block))
    final_bits = [bit for byte in interleaved for bit in ((byte >> shift) & 1 for shift in range(7, -1, -1))]
    base = qr_base(selected_version)
    best: list[list[bool | None]] | None = None
    best_score = 10**9
    for mask in range(8):
        candidate = [row[:] for row in base]
        qr_draw_data(candidate, final_bits, mask)
        qr_draw_format(candidate, mask)
        score = qr_penalty(candidate)
        if score < best_score:
            best_score = score
            best = candidate
    if best is None:
        raise TelegramError("bundled QR renderer could not select a mask")
    quiet = 4
    lines = []
    for row in range(-quiet, len(best) + quiet):
        line = []
        for column in range(-quiet, len(best) + quiet):
            line.append("██" if 0 <= row < len(best) and 0 <= column < len(best) and best[row][column] else "  ")
        lines.append("".join(line))
    return "\n".join(lines) + "\n"


def setup_token() -> str:
    try:
        if sys.stdin.isatty():
            return getpass.getpass("Telegram bot token: ").strip()
        return sys.stdin.readline(MAX_COMMAND_BYTES).strip()
    except (EOFError, OSError, UnicodeDecodeError) as exc:
        raise TelegramError("Telegram bot token could not be read") from exc


def setup(token: str, machine: bool) -> dict[str, Any]:
    if not TOKEN_RE.fullmatch(token):
        raise TelegramError("invalid Telegram bot token")
    os.environ["FM_TELEGRAM_BOT_TOKEN"] = token
    ensure_private_dir(state_dir())
    pairing_lock = state_dir() / ".pairing.lock"
    pairing_token = portable_lock_acquire(pairing_lock)
    try:
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
            "paired_update_id": None,
        }
        save_pairing(record)
    finally:
        portable_lock_release(pairing_lock, pairing_token)
    link = deep_link(username, nonce)
    picture = qr(link)
    output = {
        "schema": "fm-telegram-setup.v1",
        "bot_username": username,
        "deep_link": link,
        "qr": picture,
        "nonce_expires_at": record["nonce_expires_at"],
    }
    if machine:
        return output
    print(f"Telegram bot: @{username}")
    print(f"Pairing link: {link}")
    sys.stdout.flush()
    stream = getattr(sys.stdout, "buffer", None)
    if stream is None:
        reconfigure = getattr(sys.stdout, "reconfigure", None)
        if callable(reconfigure):
            reconfigure(encoding="utf-8", errors="strict")
        try:
            sys.stdout.write(picture)
            sys.stdout.flush()
        except UnicodeEncodeError:
            try:
                os.write(sys.stdout.fileno(), picture.encode("utf-8"))
            except (AttributeError, OSError) as exc:
                raise TelegramError("QR output stream cannot emit UTF-8") from exc
    else:
        stream.write(picture.encode("utf-8"))
        stream.flush()
    return output




def _pair_hash(candidate_hash: str, user_id: str, chat_id: str, update_id: str | None = None) -> dict[str, Any]:
    normalized_user = numeric_value(user_id, ID_RE)
    normalized_chat = numeric_value(chat_id, CHAT_ID_RE)
    normalized_update = numeric_value(update_id, ID_RE) if update_id is not None else None
    if normalized_user is None or normalized_chat is None or update_id is not None and normalized_update is None:
        raise TelegramError("Telegram identity must be numeric")
    lock = state_dir() / ".pairing.lock"
    token = portable_lock_acquire(lock)
    try:
        record = load_pairing()
        expires = record.get("nonce_expires_at")
        valid_nonce = isinstance(expires, int) and not isinstance(expires, bool) and expires > now() and secrets.compare_digest(candidate_hash, str(record.get("nonce_hash", "")))
        if not valid_nonce or record.get("paired_user_id") is not None or record.get("paired_chat_id") is not None:
            raise TelegramError("pairing nonce is expired or invalid")
        rotated = new_nonce()
        record.update({"nonce_hash": nonce_hash(rotated), "nonce_expires_at": now() + DEFAULT_PAIRING_TTL, "paired_user_id": normalized_user, "paired_chat_id": normalized_chat, "paired_at": iso_now(), "paired_update_id": normalized_update})
        save_pairing(record)
        return {"schema": "fm-telegram-pairing-result.v1", "paired": True, "user_id": normalized_user, "chat_id": normalized_chat}
    finally:
        portable_lock_release(lock, token)


def utf8_length(text: str, label: str) -> int:
    try:
        return len(text.encode("utf-8"))
    except UnicodeEncodeError as exc:
        raise TelegramError(f"{label} contains malformed Unicode") from exc


def validate_text(text: str, label: str = "text") -> str:
    if not isinstance(text, str) or not text or not text.strip():
        raise TelegramError(f"{label} is empty or too large")
    if utf8_length(text, label) > MAX_COMMAND_BYTES:
        raise TelegramError(f"{label} is empty or too large")
    if any(ord(char) < 32 or ord(char) == 127 for char in text):
        raise TelegramError(f"{label} contains control bytes")
    return text


def identity(record: dict[str, Any], user_id: Any, chat_id: Any) -> bool:
    user = numeric_value(user_id, ID_RE)
    chat = numeric_value(chat_id, CHAT_ID_RE)
    return user is not None and chat is not None and user == str(record.get("paired_user_id")) and chat == str(record.get("paired_chat_id"))


def validate_steer_text(text: str) -> str:
    text = validate_text(text, "steer")
    stripped = text.lstrip()
    if stripped.startswith(("/", "$", "--")):
        raise TelegramError("steer text cannot start with a parser-native prefix")
    return text


def bounded(text: str) -> str:
    return text[:MAX_MESSAGE_CHARS]


def telegram_response(text: str) -> str:
    if not isinstance(text, str):
        raise TelegramError("Telegram response is too large")
    utf8_length(text, "Telegram response")
    if len(text) > MAX_MESSAGE_CHARS:
        raise TelegramError("Telegram response is too large")
    return text


def operational_state_dir() -> Path:
    return Path(os.environ.get("FM_STATE_OVERRIDE", home() / "state"))


def operational_data_dir() -> Path:
    return Path(os.environ.get("FM_DATA_OVERRIDE", home() / "data"))


def _portable_check_deadline() -> None:
    if _PORTABLE_DEADLINE is not None and time.monotonic() >= _PORTABLE_DEADLINE:
        raise TelegramError("Firstmate owner call timed out")


def read_key_value(path: Path) -> dict[str, str]:
    _portable_check_deadline()
    if path.is_symlink() or not path.is_file():
        return {}
    try:
        if path.stat().st_size > PORTABLE_MAX_METADATA_BYTES:
            return {}
        with path.open("rb") as stream:
            raw = stream.read(PORTABLE_MAX_METADATA_BYTES + 1)
    except OSError:
        return {}
    _portable_check_deadline()
    if len(raw) > PORTABLE_MAX_METADATA_BYTES:
        return {}
    values: dict[str, str] = {}
    for line in raw.decode("utf-8", errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def _portable_read_status(path: Path) -> list[str]:
    _portable_check_deadline()
    if path.is_symlink() or not path.is_file():
        return []
    try:
        if path.stat().st_size > PORTABLE_MAX_STATUS_BYTES:
            raise TelegramError("portable status log is too large")
        with path.open("rb") as stream:
            raw = stream.read(PORTABLE_MAX_STATUS_BYTES + 1)
    except TelegramError:
        raise
    except (OSError, UnicodeError) as exc:
        raise TelegramError("portable status log could not be read") from exc
    _portable_check_deadline()
    if len(raw) > PORTABLE_MAX_STATUS_BYTES:
        raise TelegramError("portable status log is too large")
    return raw.decode("utf-8", errors="replace").splitlines()


def _portable_read_backlog() -> list[dict[str, Any]]:
    _portable_check_deadline()
    path = operational_data_dir() / "backlog.md"
    if path.is_symlink() or not path.is_file():
        return []
    try:
        if path.stat().st_size > PORTABLE_MAX_STATUS_BYTES:
            raise TelegramError("portable backlog is too large")
        with path.open("rb") as stream:
            raw = stream.read(PORTABLE_MAX_STATUS_BYTES + 1)
    except TelegramError:
        raise
    except OSError as exc:
        raise TelegramError("portable backlog could not be read") from exc
    _portable_check_deadline()
    if len(raw) > PORTABLE_MAX_STATUS_BYTES:
        raise TelegramError("portable backlog is too large")
    _portable_check_deadline()
    lines = raw.decode("utf-8", errors="replace").splitlines()
    section = ""
    records: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    row_re = re.compile(r"^[-*]\s+\[[ xX]\]\s+(?P<id>[A-Za-z0-9._-]+)\s+-\s+(?P<rest>.*)$")
    for line in lines:
        _portable_check_deadline()
        heading = re.match(r"^##\s+(.+?)\s*$", line)
        if heading:
            title = heading.group(1).strip().lower()
            section = {"in flight": "in_flight", "queued": "queued", "done": "done"}.get(title, "")
            current = None
            continue
        match = row_re.match(line)
        if match is None:
            bold = re.match(r"^[-*]\s+\*\*(?P<id>[A-Za-z0-9._-]+)\*\*\s+-\s+(?P<rest>.*)$", line)
            if bold is not None:
                match = bold
        if match and section:
            rest = match.group("rest")
            fields: dict[str, str] = {}
            for key, value in re.findall(r"\(([^():]+):\s*([^)]*)\)", rest):
                fields[key.strip()] = value.strip()
            title = re.sub(r"\s+\([^)]*\)", "", rest).strip()
            current = {
                "id": match.group("id"),
                "state": section,
                "title": title[:128],
                "kind": fields.get("kind", "ship"),
                "hold_kind": fields.get("hold-kind", ""),
                "hold_reason": fields.get("hold", ""),
                "hold_until": fields.get("hold-until", ""),
                "since": fields.get("since", ""),
                "hold_set": "",
                "blocked_by": re.findall(r"blocked-by:\s*([A-Za-z0-9._-]+)", rest),
            }
            records.append(current)
            if len(records) > PORTABLE_MAX_RECORDS:
                raise TelegramError("portable backlog has too many records")
            continue
        if current is not None:
            stamp = re.match(r"^\s*Captain hold set:\s*(\d{4}-\d{2}-\d{2}(?:T[^ ]+)?)\s*$", line)
            if stamp:
                current["hold_set"] = stamp.group(1)
    return records


def _portable_hold_bucket(record: dict[str, Any], records: list[dict[str, Any]]) -> str | None:
    if record.get("state") == "done" or record.get("hold_kind") != "captain" or not record.get("hold_reason"):
        return None
    done = {item["id"] for item in records if item.get("state") == "done"}
    if any(blocker not in done for blocker in record.get("blocked_by", [])):
        return "blocked"
    hold_until = str(record.get("hold_until", ""))
    today = datetime.now(timezone.utc).date()
    if hold_until:
        try:
            if datetime.fromisoformat(hold_until + ("T00:00:00+00:00" if len(hold_until) == 10 else "")).date() > today:
                return "dated"
        except ValueError:
            pass
    stamp = str(record.get("hold_set") or record.get("since") or "")
    age_limit = os.environ.get("FM_SNAPSHOT_UNDATED_HOLD_AGE_DAYS", "14")
    try:
        age_limit_value = max(0, int(age_limit))
    except ValueError:
        age_limit_value = 14
    if stamp:
        try:
            if (today - datetime.fromisoformat(stamp + ("T00:00:00+00:00" if len(stamp) == 10 else "")).date()).days >= age_limit_value:
                return "aged"
        except ValueError:
            pass
    return "live"


def _portable_backlog_decisions(records: list[dict[str, Any]], all_decisions: bool) -> list[dict[str, str]]:
    decisions: list[dict[str, str]] = []
    for record in records:
        _portable_check_deadline()
        bucket = _portable_hold_bucket(record, records)
        if bucket is None or not all_decisions and bucket != "live":
            continue
        decisions.append({"id": record["id"], "key": record["id"], "verb": "captain-hold", "summary": str(record.get("hold_reason") or record.get("title") or record["id"])[:256], "owner": "(main)"})
    return decisions


def _portable_bound(name: str, default: int) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        value = default
    return min(PORTABLE_MAX_RECORDS, max(1, value))


def _portable_status_unstamped(line: str) -> str:
    rest = line
    kept = ""
    while "[at=" in rest and "]" in rest:
        before, after = rest.split("[at=", 1)
        if ":" in before:
            break
        kept += before.rstrip()
        rest = after.split("]", 1)[1]
    return kept + rest


def _portable_status_verb(unstamped: str) -> str:
    head = unstamped.partition(":")[0].strip()
    verb = head.split("[", 1)[0].strip()
    words = verb.split()
    if not words or not all(re.fullmatch(r"corr=[0-9A-Fa-f]{16}", word) for word in words[1:]):
        return ""
    return words[0]


def _portable_status_note(unstamped: str) -> str:
    head, separator, note = unstamped.partition(":")
    if not separator:
        return unstamped.strip()
    note = note.strip()
    if "[key=" not in head:
        match = re.match(r"\[key=([^\]]+)\]\s*(.*)", note)
        if match and re.fullmatch(r"[A-Za-z0-9._-]+", match.group(1)):
            note = match.group(2)
    return note


def _portable_status_key(unstamped: str) -> str | None:
    head, separator, note = unstamped.partition(":")
    match = re.search(r"\[key=([^\]]+)\]", head)
    if match is None and separator:
        match = re.match(r"\s*\[key=([^\]]+)\]", note)
    if match is None:
        return "default"
    key = match.group(1)
    return key if re.fullmatch(r"[A-Za-z0-9._-]+", key) else None


PORTABLE_STATE_MAP = {
    "working": "working",
    "needs-decision": "parked",
    "blocked": "blocked",
    "paused": "paused",
    "done": "done",
    "failed": "failed",
    "resolved": "unknown",
    "captain-held": "unknown",
}


def _portable_busy_state(task_id: str, values: dict[str, str]) -> str | None:
    _portable_check_deadline()
    record_path = operational_state_dir() / f"{task_id}.busy-state"
    generation_path = operational_state_dir() / f"{task_id}.busy-gen"
    if not record_path.exists() and not generation_path.exists():
        return None
    try:
        if generation_path.stat().st_size > 256 or record_path.stat().st_size > 4096:
            return "unknown"
        generation = generation_path.read_text(encoding="ascii").strip()
        raw = record_path.read_text(encoding="ascii")
    except (OSError, UnicodeError):
        return "unknown"
    _portable_check_deadline()
    lines = raw.splitlines()
    if len(lines) != 1 or not re.fullmatch(r"[A-Za-z0-9._-]+", generation):
        return "unknown"
    fields = lines[0].split(" ")
    if len(fields) != 7 or fields[0] != "v1":
        return "unknown"
    parsed: dict[str, str] = {}
    for field in fields[1:]:
        key, separator, value = field.partition("=")
        if not separator or key in parsed or not value:
            return "unknown"
        parsed[key] = value
    if set(parsed) != {"gen", "seq", "state", "source", "event", "ts"}:
        return "unknown"
    if parsed["gen"] != generation or parsed["state"] not in {"busy", "idle", "unknown"}:
        return "unknown"
    if not re.fullmatch(r"[0-9]+", parsed["seq"]) or not re.fullmatch(r"[0-9]+", parsed["ts"]):
        return "unknown"
    harness_sources = {
        "claude": {"claude-hook"},
        "gemini": {"gemini-hook"},
        "opencode": {"opencode-plugin"},
        "pi": {"pi-ext"},
        "pi-signed": {"pi-ext"},
        "omp": {"omp-ext"},
        "codex": {"codex-hook", "codex-appserver"},
        "kimi": {"kimi-wire", "kimi-hook"},
    }
    harness = values.get("harness", "").split("-", 1)[0]
    trusted = {"fm-spawn", "fm-interrupt", "fm-recovery"} | harness_sources.get(harness, set())
    return parsed["state"] if parsed["source"] in trusted else "unknown"


def _portable_status_fold(lines: list[str], task_id: str, kind: str, lifecycle_state: str | None = None) -> tuple[list[dict[str, str]], tuple[str, str] | None]:
    open_decisions: list[dict[str, str]] = []
    latest: tuple[str, str] | None = None
    pause = os.environ.get("FM_CLASSIFY_PAUSED_VERB", "paused")
    resolve = os.environ.get("FM_CLASSIFY_RESOLVE_VERB", "resolved")
    held = os.environ.get("FM_CLASSIFY_CAPTAIN_HELD_VERB", "captain-held")
    verbs = {"working", "needs-decision", "blocked", "done", "failed", pause, resolve, held}
    for line in lines:
        _portable_check_deadline()
        unstamped = _portable_status_unstamped(line)
        if ":" not in unstamped:
            continue
        verb = _portable_status_verb(unstamped)
        if verb not in verbs:
            continue
        note = _portable_status_note(unstamped)
        latest = (verb, note)
        if verb in ("done", "failed") and ":" in unstamped and kind in ("ship", "scout"):
            open_decisions.clear()
            continue
        if verb not in ("needs-decision", "blocked", resolve, held):
            continue
        key = _portable_status_key(unstamped)
        if key is None:
            continue
        if key.startswith("pending-reply-") and not re.match(r"pending-reply-[^:]+:", note):
            continue
        open_decisions = [entry for entry in open_decisions if entry["key"] != key]
        if verb in ("needs-decision", "blocked"):
            open_decisions.append({"id": task_id, "key": key, "verb": verb, "summary": note})
    if lifecycle_state in ("working", "done", "failed") and kind in ("ship", "scout"):
        open_decisions.clear()
    if latest is not None:
        latest = (latest[0], latest[1])
    return open_decisions, latest


def _portable_state_projection(open_decisions: list[dict[str, str]], latest: tuple[str, str] | None) -> tuple[str, str]:
    if open_decisions:
        entry = open_decisions[-1]
        return PORTABLE_STATE_MAP[entry["verb"]], entry["summary"][:256]
    if latest is None:
        return "unknown", ""
    verb, note = latest
    pause = os.environ.get("FM_CLASSIFY_PAUSED_VERB", "paused")
    state = "paused" if verb == pause else PORTABLE_STATE_MAP.get(verb, "unknown")
    return state, note[:256] if state != "unknown" else ""


def portable_snapshot(all_decisions: bool, page_kind: str | None = None, page_offset: int = 0, page_limit: int | None = None) -> str:
    _portable_check_deadline()
    if page_kind not in (None, "in_flight", "decisions") or page_offset < 0 or page_offset > MAX_TELEGRAM_PAGE * MAX_TELEGRAM_PAGE_SIZE:
        raise TelegramError("Telegram page is malformed")
    if page_kind is not None and (page_limit is None or page_limit < 1 or page_limit > MAX_TELEGRAM_PAGE_SIZE + 1):
        raise TelegramError("Telegram page is malformed")
    tasks: list[dict[str, Any]] = []
    decisions: list[dict[str, str]] = []
    state = operational_state_dir()
    backlog = _portable_read_backlog()
    backlog_by_id = {record["id"]: record for record in backlog}
    meta_paths = _portable_directory_entries(state, ".meta", PORTABLE_MAX_TASKS)
    meta_paths.sort()
    for meta in meta_paths:
        _portable_check_deadline()
        if meta.is_symlink() or not meta.is_file():
            continue
        values = read_key_value(meta)
        task_id = values.get("id", meta.stem)
        if not WORKER_RE.fullmatch(task_id):
            continue
        if values.get("remote_host"):
            raise TelegramError("Windows remote worker status and steer are unsupported; run Telegram on the remote Firstmate home")
        kind = values.get("kind") or "ship"
        backend = values.get("backend", "tmux")
        target = values.get("remote_target") if values.get("remote_host") else values.get("window", "")
        busy_state = _portable_busy_state(task_id, values)
        status_path = state / f"{task_id}.status"
        status_lines = _portable_read_status(status_path)
        task_decisions, latest = _portable_status_fold(status_lines, task_id, kind, "working" if busy_state == "busy" else None)
        if busy_state == "busy":
            current_state, doing = "working", "worker active"
        else:
            if kind in ("ship", "scout") and latest is not None and latest[0] == "working":
                task_decisions.clear()
            current_state, doing = _portable_state_projection(task_decisions, latest)
        backlog_record = backlog_by_id.get(task_id)
        if backlog_record is not None:
            if backlog_record.get("state") == "done":
                current_state, doing = "done", str(backlog_record.get("title") or "")[:256]
            elif backlog_record.get("hold_kind") == "captain" and backlog_record.get("hold_reason") and current_state != "working":
                current_state, doing = "parked", str(backlog_record.get("hold_reason"))[:256]
        row: dict[str, Any] = {
            "id": task_id,
            "kind": kind,
            "state": current_state,
            "backend": str(backend or "unknown")[:128],
            "target": str(target or "")[:256],
            "name": str(values.get("title") or (backlog_record or {}).get("title") or task_id)[:128],
            "doing": doing,
        }
        decisions.extend(task_decisions)
        tasks.append(row)
    backlog_decisions = _portable_backlog_decisions(backlog, all_decisions)
    backlog_all_decisions = _portable_backlog_decisions(backlog, True)
    decisions = backlog_decisions + [
        decision for decision in decisions
        if not any(existing["id"] == decision["id"] and existing["key"] == decision["key"] for existing in backlog_all_decisions)
    ]
    decision_limit = _portable_bound("FM_BEARINGS_DECISIONS", 20)
    if page_kind == "decisions":
        visible_decisions = decisions[page_offset:page_offset + (page_limit or decision_limit)]
    else:
        visible_decisions = decisions[:decision_limit]
    omitted: list[dict[str, Any]] = []
    decisions_end = page_offset + len(visible_decisions) if page_kind == "decisions" else len(visible_decisions)
    if len(decisions) > decisions_end:
        omitted.append({"surface": f"decisions_open showing {decisions_end} of {len(decisions)}", "reveal": "--all-decisions" if not all_decisions else "raise FM_BEARINGS_DECISIONS", "count": len(decisions) - decisions_end})
    in_flight_all = [
        task for task in tasks
        if task["state"] in ("working", "parked", "blocked", "paused")
        and not (
            task["state"] != "working"
            and (backlog_by_id.get(task["id"]) or {}).get("state") == "in_flight"
            and (backlog_by_id.get(task["id"]) or {}).get("hold_kind") == "captain"
            and (backlog_by_id.get(task["id"]) or {}).get("hold_reason")
        )
    ]
    in_flight_limit = _portable_bound("FM_BEARINGS_IN_FLIGHT", 20)
    if page_kind == "in_flight":
        in_flight = in_flight_all[page_offset:page_offset + (page_limit or in_flight_limit)]
    else:
        in_flight = in_flight_all[:in_flight_limit]
    in_flight_end = page_offset + len(in_flight) if page_kind == "in_flight" else len(in_flight)
    if len(in_flight_all) > in_flight_end:
        omitted.append({"surface": f"in_flight showing {in_flight_end} of {len(in_flight_all)}", "reveal": "--all-in-flight", "count": len(in_flight_all) - in_flight_end})
    result: dict[str, Any] = {
        "schema": "fm-bearings.v1",
        "generated": iso_now(),
        "tasks": tasks,
        "in_flight": in_flight,
        "decisions_open": visible_decisions,
        "omitted": omitted,
    }
    return json.dumps(result, sort_keys=True, separators=(",", ":"))


def _portable_windows_process(pid: int, terminate: bool = False) -> tuple[Any, Any, str] | None:
    if os.name != "nt" or pid <= 0:
        return None
    try:
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.FILETIME), ctypes.POINTER(wintypes.FILETIME), ctypes.POINTER(wintypes.FILETIME), ctypes.POINTER(wintypes.FILETIME)]
        kernel.GetProcessTimes.restype = wintypes.BOOL
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.CloseHandle.restype = wintypes.BOOL
        access = 0x1000 | (0x0001 if terminate else 0)
        handle = kernel.OpenProcess(access, False, pid)
        if not handle:
            return None
        created = wintypes.FILETIME()
        exited = wintypes.FILETIME()
        kernel_time = wintypes.FILETIME()
        user_time = wintypes.FILETIME()
        if not kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited), ctypes.byref(kernel_time), ctypes.byref(user_time)):
            kernel.CloseHandle(handle)
            return None
        started = (created.dwHighDateTime << 32) | created.dwLowDateTime
        return kernel, handle, str(started)
    except (AttributeError, OSError, OverflowError, TypeError):
        return None


def _portable_record_process(record: dict[str, Any], terminate: bool = False) -> tuple[Any, Any] | None:
    try:
        pid = int(record["pid"])
        expected = str(record["process_start"])
    except (KeyError, TypeError, ValueError, OverflowError):
        return None
    if pid <= 0 or re.fullmatch(r"[0-9]+", expected) is None:
        return None
    process = _portable_windows_process(pid, terminate)
    if process is None:
        return None
    kernel, handle, started = process
    if started != expected:
        kernel.CloseHandle(handle)
        return None
    return kernel, handle


def _portable_pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if os.name == "nt":
        try:
            import ctypes
            from ctypes import wintypes
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
            kernel.OpenProcess.restype = wintypes.HANDLE
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            kernel.CloseHandle.restype = wintypes.BOOL
            handle = kernel.OpenProcess(0x1000, False, pid)
            if handle:
                kernel.CloseHandle(handle)
                return True
            return ctypes.get_last_error() == 5
        except (AttributeError, OSError, OverflowError, TypeError):
            return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except (OSError, OverflowError):
        return False
    return True


def _portable_lock_stale_after() -> float:
    try:
        value = float(os.environ.get("FM_LOCK_STALE_AFTER", "2"))
    except ValueError:
        value = 2
    return value if value > 0 else 2


def _portable_lock_is_stale(path: Path) -> bool:
    try:
        age = time.time() - path.stat().st_mtime
    except OSError:
        return False
    if age < _portable_lock_stale_after():
        return False
    owner = path / "owner"
    try:
        parts = owner.read_text(encoding="ascii").strip().split("\t")
        pid = int(parts[0]) if parts else 0
    except (OSError, ValueError, UnicodeError):
        pid = 0
    return not _portable_pid_alive(pid)


def portable_lock_acquire(path: Path) -> str:
    ensure_private_dir(path.parent)
    token = secrets.token_hex(8)
    deadline = time.monotonic() + _portable_timeout(5)
    while True:
        _portable_check_deadline()
        if path.is_symlink():
            raise TelegramError(f"unsafe portable lock: {path}")
        candidate = path.parent / f".{path.name}.candidate.{os.getpid()}.{token}"
        try:
            candidate.mkdir(mode=0o700)
            ensure_private_dir(candidate)
            atomic_write(candidate / "owner", f"{os.getpid()}\t{token}\n".encode("ascii"))
            try:
                candidate.rename(path)
            except FileExistsError:
                shutil.rmtree(candidate)
                continue
            return token
        except FileExistsError:
            if candidate.exists():
                shutil.rmtree(candidate, ignore_errors=True)
            if _portable_lock_is_stale(path):
                reclaimed = path.parent / f".{path.name}.reclaim.{os.getpid()}.{token}"
                try:
                    path.rename(reclaimed)
                    if reclaimed.is_dir():
                        shutil.rmtree(reclaimed)
                    else:
                        reclaimed.unlink(missing_ok=True)
                except FileNotFoundError:
                    continue
                except OSError:
                    pass
                continue
            if time.monotonic() >= deadline:
                raise TelegramError(f"portable lock could not be acquired: {path}")
            time.sleep(min(0.05, max(0.0, deadline - time.monotonic())))
        except OSError as exc:
            if candidate.exists():
                shutil.rmtree(candidate, ignore_errors=True)
            if path.exists() and time.monotonic() < deadline:
                time.sleep(min(0.05, max(0.0, deadline - time.monotonic())))
                continue
            raise TelegramError(f"portable lock could not be acquired: {path}") from exc


def portable_lock_release(path: Path, token: str) -> None:
    owner = path / "owner"
    try:
        value = owner.read_text(encoding="ascii").strip().split("\t")
        if len(value) != 2 or value[1] != token:
            return
        shutil.rmtree(path)
    except (FileNotFoundError, OSError, UnicodeError):
        return


def _portable_wake_append_locked(state: Path, target: str, summary: str) -> None:
    sequence_path = state / ".wake-queue.seq"
    try:
        sequence = int(sequence_path.read_text(encoding="utf-8").strip()) if sequence_path.exists() else 0
    except (OSError, ValueError):
        sequence = 0
    sequence += 1
    atomic_write(sequence_path, f"{sequence}\n".encode("utf-8"))
    queue = state / ".wake-queue"
    if queue.is_symlink() or (queue.exists() and not queue.is_file()):
        raise TelegramError("unsafe portable wake queue")
    safe_summary = bounded(summary).replace("\r", " ").replace("\n", " ").replace("\t", " ")
    with queue.open("a", encoding="utf-8") as stream:
        stream.write(f"{now()}\t{sequence}\tcheck\t{target}\t{safe_summary}\n")
        stream.flush()
        os.fsync(stream.fileno())


def portable_wake(note_id: str, body: str) -> None:
    token: str | None = None
    try:
        state = operational_state_dir()
        ensure_private_dir(state)
        marker_dir = state / "inbox" / ".announced"
        ensure_private_dir(marker_dir)
        marker = marker_dir / note_id
        lock = state / ".wake-queue.lock"
        token = portable_lock_acquire(lock)
        if marker.is_symlink() or (marker.exists() and not marker.is_file()):
            raise TelegramError("portable inbox announcement marker is unsafe")
        if marker.exists():
            return
        _portable_wake_append_locked(state, f"inbox:{note_id}", f"check: captain inbox note {note_id} - {bounded(body)}")
        atomic_write(marker, f"{iso_now()}\n".encode("utf-8"))
    except OSError as exc:
        raise TelegramError("portable inbox wake could not be persisted") from exc
    finally:
        if token is not None:
            portable_lock_release(lock, token)


def portable_task_wake(target: str, record_path: Path) -> None:
    token: str | None = None
    try:
        state = operational_state_dir()
        ensure_private_dir(state)
        lock = state / ".wake-queue.lock"
        token = portable_lock_acquire(lock)
        record_dir = record_path.parent
        if record_dir.name == "handled":
            record_dir = record_dir.parent
        path_text = str(record_dir).replace("\\", "/").replace("'", "'\\\\''")
        ack_command = " ".join(shlex.quote(part) for part in (sys.executable, str(Path(__file__).resolve()), "ack", "--state", str(state), "--task", target, "--record", record_path.name))
        summary = f": Firstmate instruction waiting: list '{path_text}'/*.msg and, in numeric order, read and act on each, then run {ack_command} for each handled record."
        _portable_wake_append_locked(state, f"inbox:{target}", summary)
    except OSError as exc:
        raise TelegramError("portable task wake could not be persisted") from exc
    finally:
        if token is not None:
            portable_lock_release(lock, token)


def _portable_atomic_claim(path: Path, data: bytes) -> bool:
    ensure_private_dir(path.parent)
    if path.is_symlink():
        raise TelegramError(f"unsafe portable reservation: {path}")
    tmp = path.parent / f".{path.name}.{os.getpid()}.{secrets.token_hex(4)}.tmp"
    try:
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            os.link(tmp, path)
        except FileExistsError:
            return False
        except OSError:
            lock = path.parent / f".{path.name}.lock"
            token = portable_lock_acquire(lock)
            try:
                if path.exists():
                    return False
                atomic_write(path, data)
                return True
            finally:
                portable_lock_release(lock, token)
        return True
    finally:
        tmp.unlink(missing_ok=True)


def _portable_reservation_id(path: Path) -> str | None:
    _portable_check_deadline()
    if path.is_symlink() or not path.is_file():
        raise TelegramError("portable inbox request is unsafe")
    try:
        if path.stat().st_size > PORTABLE_MAX_RECORD_BYTES:
            raise TelegramError("portable inbox request is too large")
        with path.open("rb") as stream:
            raw = stream.read(PORTABLE_MAX_RECORD_BYTES + 1)
    except TelegramError:
        raise
    except (OSError, UnicodeDecodeError) as exc:
        raise TelegramError("portable inbox request is unreadable") from exc
    _portable_check_deadline()
    if len(raw) > PORTABLE_MAX_RECORD_BYTES:
        raise TelegramError("portable inbox request is too large")
    lines = raw.decode("utf-8", errors="replace").splitlines()
    note_id = lines[0].strip() if lines else ""
    if not NOTE_ID_RE.fullmatch(note_id):
        if not lines or not "".join(lines).strip():
            path.unlink()
            return None
        raise TelegramError("portable inbox request is malformed")
    return note_id


def portable_note(body: str, request_id: str) -> str:
    _portable_check_deadline()
    body = validate_text(body, "note")
    if not REQUEST_ID_RE.fullmatch(request_id):
        raise TelegramError("portable inbox request ID is malformed")
    directory = operational_state_dir() / "inbox"
    request_dir = directory / ".requests"
    ensure_private_dir(directory)
    ensure_private_dir(request_dir)
    request_path = request_dir / request_id
    created = False
    note_id = _portable_reservation_id(request_path) if request_path.exists() else None
    if note_id is None:
        candidate = f"{now()}-{secrets.token_hex(4)}"
        if _portable_atomic_claim(request_path, f"{candidate}\n".encode("ascii")):
            note_id = candidate
            created = True
        else:
            note_id = _portable_reservation_id(request_path)
            if note_id is None:
                raise TelegramError("portable inbox request could not be recovered")
    note_path = directory / f"{note_id}.note"
    handled_path = directory / "handled" / f"{note_id}.note"
    if handled_path.is_symlink() or (handled_path.exists() and not handled_path.is_file()):
        raise TelegramError("portable handled inbox note is unsafe")
    if handled_path.is_file():
        return json.dumps({"schema": "fm-inbox-note.v1", "outcome": "replay", "id": note_id, "request_id": request_id, "saved": True, "announced": False, "acknowledged": True}, separators=(",", ":"))
    if note_path.is_symlink() or (note_path.exists() and not note_path.is_file()):
        raise TelegramError("portable inbox note is unsafe")
    if not note_path.exists():
        note = f"id={note_id}\nat={iso_now()}\nsource=telegram\nannounce_marker=1\nrequest_id={request_id}\n--\n{body}\n"
        atomic_write(note_path, note.encode("utf-8"))
    try:
        portable_wake(note_id, body)
    except TelegramError as exc:
        partial = json.dumps({"schema": "fm-inbox-note.v1", "outcome": "created" if created else "replay", "id": note_id, "request_id": request_id, "saved": True, "announced": False, "acknowledged": False, "error": "note saved but wake could not be announced"}, separators=(",", ":"))
        raise DurableOwnerError(partial) from exc
    return json.dumps({"schema": "fm-inbox-note.v1", "outcome": "created" if created else "replay", "id": note_id, "request_id": request_id, "saved": True, "announced": True, "acknowledged": False}, separators=(",", ":"))


def _portable_record_text(path: Path) -> str | None:
    _portable_check_deadline()
    try:
        if path.stat().st_size > PORTABLE_MAX_RECORD_BYTES:
            raise TelegramError("portable task inbox record is too large")
        with path.open("rb") as stream:
            raw = stream.read(PORTABLE_MAX_RECORD_BYTES + 1)
    except TelegramError:
        raise
    except (OSError, UnicodeDecodeError):
        return None
    _portable_check_deadline()
    if len(raw) > PORTABLE_MAX_RECORD_BYTES:
        raise TelegramError("portable task inbox record is too large")
    return raw.decode("utf-8", errors="replace")


def _portable_record_body(path: Path) -> str | None:
    content = _portable_record_text(path)
    return content.split("\n--\n", 1)[1] if content is not None and "\n--\n" in content else None


def _portable_record_field(path: Path, field: str) -> str | None:
    content = _portable_record_text(path)
    if content is None:
        return None
    header = content.split("\n--\n", 1)[0]
    prefix = f"{field}="
    for line in header.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):]
    return None


def portable_task_id(target: str, state: Path) -> str:
    if state.joinpath(f"{target}.meta").is_file():
        return target
    if target.startswith("fm-") and state.joinpath(f"{target[3:]}.meta").is_file():
        return target[3:]
    raise TelegramError("Firstmate owner script rejected request")


def portable_task_meta(target: str, state: Path) -> tuple[str, Path, dict[str, str]]:
    task_id = portable_task_id(target, state)
    meta = state / f"{task_id}.meta"
    if meta.is_symlink() or not meta.is_file():
        raise TelegramError("Firstmate owner script rejected request")
    return task_id, meta, read_key_value(meta)


def portable_target_kind(target: str, state: Path) -> str | None:
    try:
        _, _, values = portable_task_meta(target, state)
    except TelegramError:
        return None
    return values.get("kind") or "ship"


def portable_target_is_remote(target: str, state: Path) -> bool:
    _, _, values = portable_task_meta(target, state)
    return bool(values.get("remote_host"))


def _portable_delivery_reservation(inbox: Path, delivery_id: str) -> Path:
    if re.fullmatch(r"[a-f0-9]{16}", delivery_id) is None:
        raise TelegramError("Firstmate owner script rejected request")
    return inbox / ".idempotency" / f"{delivery_id}.reservation"


def _portable_reserved_record_name(path: Path) -> str:
    name = _portable_record_field(path, "record") or ""
    if re.fullmatch(r"[0-9]{1,12}\.msg", name) is None:
        raise TelegramError("portable inbox reservation is malformed")
    return name


def _portable_delivery_match(path: Path, delivery_id: str, wire_body: str, fire_and_forget: bool) -> bool:
    if path.is_symlink() or not path.is_file():
        return False
    existing_key = _portable_record_field(path, "idempotency-key")
    legacy_match = re.match(rf"^{re.escape(FROMFIRST_MARK)}delivery=([a-f0-9]{{16}}) (.*)$", _portable_record_body(path) or "", re.DOTALL)
    if existing_key != delivery_id and not (existing_key is None and legacy_match and legacy_match.group(1) == delivery_id):
        return False
    existing = _portable_record_body(path)
    if existing != wire_body or (_portable_record_field(path, "delivery") == "fire-and-forget") != fire_and_forget:
        raise TelegramError("Firstmate delivery ID was reused for different text")
    return True


def _portable_directory_entries(directory: Path, suffix: str, limit: int = PORTABLE_MAX_RECORDS) -> list[Path]:
    entries: list[Path] = []
    try:
        with os.scandir(directory) as scan:
            for entry in scan:
                _portable_check_deadline()
                if entry.name.endswith(suffix):
                    entries.append(Path(entry.path))
                    if len(entries) > limit:
                        raise TelegramError("portable directory has too many records")
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise TelegramError("portable directory could not be enumerated") from exc
    return entries


def _portable_next_inbox_sequence(inbox: Path, handled: Path) -> str:
    numbers: list[int] = []
    for directory in (inbox, handled):
        for path in _portable_directory_entries(directory, ".msg"):
            try:
                numbers.append(int(path.stem))
            except ValueError:
                continue
    reservation_dir = inbox / ".idempotency"
    for path in _portable_directory_entries(reservation_dir, ".reservation"):
        name = _portable_record_field(path, "record") or ""
        if re.fullmatch(r"[0-9]{1,12}\.msg", name):
            numbers.append(int(name[:-4]))
    return f"{max(numbers, default=0) + 1:03d}.msg"


def _portable_inbox_record_text(record_name: str, body: str, delivery_id: str, fire_and_forget: bool) -> bytes:
    delivery_line = "delivery=fire-and-forget\n" if fire_and_forget else ""
    return f"schema=fm-task-inbox.v1\nat={iso_now()}\n{delivery_line}idempotency-key={delivery_id}\n--\n{body}".encode("utf-8")


def _portable_reservation_text(record_name: str, body: str, delivery_id: str, fire_and_forget: bool) -> bytes:
    delivery_line = "delivery=fire-and-forget\n" if fire_and_forget else ""
    return f"schema=fm-task-inbox-reservation.v1\nat={iso_now()}\n{delivery_line}idempotency-key={delivery_id}\nrecord={record_name}\n--\n{body}".encode("utf-8")


def portable_send(target: str, body: str, delivery_id: str, fire_and_forget: bool) -> str:
    _portable_check_deadline()
    body = validate_steer_text(body)
    if not WORKER_RE.fullmatch(target) or not re.fullmatch(r"[a-f0-9]{16}", delivery_id):
        raise TelegramError("Firstmate owner script rejected request")
    state = operational_state_dir()
    task_id, _, values = portable_task_meta(target, state)
    meta_identity = {key: values.get(key, "") for key in ("id", "spawn_gen", "kind", "backend", "window", "remote_host", "remote_target")}
    meta_lock = state / f".meta-{task_id}.lock"
    meta_token = portable_lock_acquire(meta_lock)
    inbox_token: str | None = None
    record_path: Path | None = None
    try:
        current_task_id, _, current_values = portable_task_meta(target, state)
        current_identity = {key: current_values.get(key, "") for key in meta_identity}
        if current_task_id != task_id or current_identity != meta_identity:
            raise TelegramError("Firstmate worker changed during steering")
        if current_values.get("remote_host"):
            raise TelegramError("Windows remote worker status and steer are unsupported; run Telegram on the remote Firstmate home")
        is_secondmate = (current_values.get("kind") or "ship") == "secondmate"
        if fire_and_forget != is_secondmate:
            raise TelegramError("Firstmate owner script rejected request")
        inbox = state / f"{task_id}.inbox"
        handled = inbox / "handled"
        ensure_private_dir(inbox)
        ensure_private_dir(handled)
        reservation_dir = inbox / ".idempotency"
        ensure_private_dir(reservation_dir)
        wire_body = f"{FROMFIRST_MARK}delivery={delivery_id} {body}" if fire_and_forget else body
        lock = inbox / ".seq.lock"
        inbox_token = portable_lock_acquire(lock)
        try:
            reservation = _portable_delivery_reservation(inbox, delivery_id)
            if reservation.is_symlink() or (reservation.exists() and not reservation.is_file()):
                raise TelegramError("portable inbox reservation is unsafe")
            if reservation.is_file():
                if not _portable_delivery_match(reservation, delivery_id, wire_body, fire_and_forget):
                    raise TelegramError("Firstmate delivery ID was reused for different text")
                record_name = _portable_reserved_record_name(reservation)
                root_record = inbox / record_name
                handled_record = handled / record_name
                if handled_record.is_file():
                    record_path = handled_record
                elif root_record.is_file():
                    record_path = root_record
                else:
                    record_path = root_record
                    atomic_write(record_path, _portable_inbox_record_text(record_name, wire_body, delivery_id, fire_and_forget))
            else:
                record_name = _portable_next_inbox_sequence(inbox, handled)
                atomic_write(reservation, _portable_reservation_text(record_name, wire_body, delivery_id, fire_and_forget))
                record_path = inbox / record_name
                atomic_write(record_path, _portable_inbox_record_text(record_name, wire_body, delivery_id, fire_and_forget))
        finally:
            portable_lock_release(lock, inbox_token)
            inbox_token = None
    finally:
        if inbox_token is not None:
            portable_lock_release(inbox / ".seq.lock", inbox_token)
        portable_lock_release(meta_lock, meta_token)
    if record_path is None:
        raise TelegramError("Firstmate owner script rejected request")
    if record_path.parent.name == "handled":
        return f"steer already handled for {target} with delivery {delivery_id}"
    try:
        portable_task_wake(task_id, record_path)
    except TelegramError as exc:
        raise DurableOwnerError(f"steer saved for {target} with delivery {delivery_id}, but worker wake failed: {exc}") from exc
    return f"steer delivered to {target} with delivery {delivery_id}"


def portable_owner(argv: list[str], stdin: str, env_extra: dict[str, str] | None = None) -> str:
    global _PORTABLE_DEADLINE
    previous_deadline = _PORTABLE_DEADLINE
    _PORTABLE_DEADLINE = time.monotonic() + PORTABLE_OWNER_TIMEOUT
    try:
        command = Path(argv[0]).name
        owner_env = env_extra or {}
        if command == "fm-bearings-snapshot.sh":
            page_kind = owner_env.get("FM_TELEGRAM_PAGE_KIND")
            try:
                page_offset = int(owner_env.get("FM_TELEGRAM_PAGE_OFFSET", "0"))
                page_limit = int(owner_env["FM_TELEGRAM_PAGE_LIMIT"]) if page_kind is not None else None
            except (KeyError, TypeError, ValueError, OverflowError) as exc:
                raise TelegramError("Telegram page is malformed") from exc
            return portable_snapshot("--all-decisions" in argv, page_kind, page_offset, page_limit)
        if command == "fm-inbox.sh" and len(argv) >= 4 and argv[1] == "note":
            request_index = argv.index("--request-id") + 1
            return portable_note(validate_text(stdin, "note"), argv[request_index])
        if command == "fm-send.sh" and len(argv) >= 5 and "--fire-and-forget" in argv:
            flag = argv.index("--fire-and-forget")
            if flag + 2 >= len(argv) or portable_target_kind(argv[1], operational_state_dir()) != "secondmate":
                raise TelegramError("Firstmate owner script rejected request")
            delivery_id = argv[flag + 1]
            body = validate_text(" ".join(argv[flag + 2:]), "steer")
            return portable_send(argv[1], body, delivery_id, True)
        if command == "fm-send.sh" and len(argv) >= 3 and "--fire-and-forget" not in argv:
            delivery_id = owner_env.get("FM_TELEGRAM_DELIVERY_ID", os.environ.get("FM_TELEGRAM_DELIVERY_ID", ""))
            if portable_target_kind(argv[1], operational_state_dir()) == "secondmate":
                raise TelegramError("Firstmate owner script rejected request")
            body = validate_text(" ".join(argv[2:]), "steer")
            return portable_send(argv[1], body, delivery_id, False)
        raise TelegramError("Firstmate owner script unavailable on this platform")
    finally:
        _PORTABLE_DEADLINE = previous_deadline


def _durable_note_owner_result(output: str) -> str | None:
    try:
        value = json.loads(output)
    except (TypeError, ValueError):
        return None
    if not isinstance(value, dict) or value.get("schema") != "fm-inbox-note.v1" or value.get("saved") is not True:
        return None
    note_id = value.get("id")
    if not isinstance(note_id, str) or NOTE_ID_RE.fullmatch(note_id) is None:
        return None
    if value.get("announced") is not True and value.get("acknowledged") is not True:
        raise DurableOwnerError(output.strip())
    return output.strip()


def steer_owner_timeout() -> int:
    raw = os.environ.get("FM_SEND_REMOTE_BUDGET", "")
    budget = int(raw) if re.fullmatch(r"[1-9][0-9]{0,5}", raw) else DEFAULT_SEND_REMOTE_BUDGET
    return 2 * budget + OWNER_TIMEOUT


def owner(argv: list[str], stdin: str = "", env_extra: dict[str, str] | None = None, steer: bool = False) -> str:
    if os.name == "nt":
        output = portable_owner(argv, stdin, env_extra).strip() or "completed"
        if utf8_length(output, "Firstmate owner response") > MAX_RESPONSE_BYTES:
            raise TelegramError("Firstmate owner response is too large")
        return output
    try:
        input_bytes = stdin.encode("utf-8")
        proc = subprocess.run(argv, cwd=root(), env={**os.environ, "FM_HOME": str(home()), **(env_extra or {})}, input=input_bytes, text=False, capture_output=True, timeout=steer_owner_timeout() if steer else OWNER_TIMEOUT, check=False)
    except (OSError, subprocess.SubprocessError, UnicodeEncodeError) as exc:
        if steer and isinstance(exc, subprocess.TimeoutExpired):
            raise TelegramError(STEER_UNCONFIRMED) from exc
        raise TelegramError("Firstmate owner script unavailable") from exc
    try:
        stdout = proc.stdout.decode("utf-8")
    except (AttributeError, UnicodeDecodeError) as exc:
        raise TelegramError("Firstmate owner returned malformed Unicode") from exc
    if proc.returncode != 0:
        partial = _durable_note_owner_result(stdout)
        if partial is not None:
            return partial
        if steer and proc.returncode == 3:
            raise TelegramError(STEER_UNCONFIRMED)
        raise TelegramError("Firstmate owner script rejected request")
    output = stdout.strip() or "completed"
    if utf8_length(output, "Firstmate owner response") > MAX_RESPONSE_BYTES:
        raise TelegramError("Firstmate owner response is too large")
    return output


_TELEGRAM_PATH_RE = re.compile(
    r"(?<![A-Za-z0-9_/:])(?:"
    r"[A-Za-z]:[\\/][^\s\"'<>`,;)]*"
    r"|\\\\[^\s\"'<>`,;)]*"
    r"|/(?:[^/\s\"'<>`,;)]+(?:/[^/\s\"'<>`,;)]+)*)"
    r"|/"
    r")"
)


def _telegram_redact_paths(text: str) -> str:
    return _TELEGRAM_PATH_RE.sub("[path redacted]", text)


def _telegram_redact_value(value: Any) -> Any:
    if isinstance(value, str):
        return _telegram_redact_paths(value)
    if isinstance(value, list):
        return [_telegram_redact_value(item) for item in value]
    if isinstance(value, dict):
        return {key: _telegram_redact_value(item) for key, item in value.items()}
    return value


def _telegram_owner_output(output: str) -> str:
    try:
        value = json.loads(output)
    except (TypeError, ValueError):
        return _telegram_redact_paths(output)
    if not isinstance(value, dict):
        return _telegram_redact_paths(output)
    value = _telegram_redact_value(value)
    if value.get("schema") == "fm-inbox-note.v1":
        value.pop("path", None)
        if "error" in value:
            value["error"] = "note saved but wake could not be announced"
    encoded = json.dumps(value, separators=(",", ":"))
    if len(encoded) <= MAX_MESSAGE_CHARS:
        return encoded
    schema = value.get("schema") if isinstance(value.get("schema"), str) else "fm-telegram-owner-result.v1"
    return json.dumps({"schema": schema, "omitted": True, "message": "Firstmate response exceeded Telegram's message limit"}, separators=(",", ":"))


def _telegram_owner_error(exc: TelegramError) -> str:
    message = _telegram_redact_paths(str(exc))
    if "/" in message or "\\" in message or re.search(r"[A-Za-z]:", message):
        return "Firstmate owner request failed"
    return message


def _telegram_page_output(output: str, command: str, page: int, page_size: int, collection: str, offset: int) -> str:
    try:
        value = json.loads(output)
    except (TypeError, ValueError):
        return _telegram_owner_output(output)
    if not isinstance(value, dict) or value.get("schema") != "fm-bearings.v1" or not isinstance(value.get(collection), list):
        return _telegram_owner_output(output)
    value = _telegram_redact_value(value)
    rows = value[collection]
    page_rows = rows[:page_size]
    upstream_more = len(rows) > page_size
    omitted = value.get("omitted")
    if isinstance(omitted, list):
        for item in omitted:
            if isinstance(item, dict) and str(item.get("surface", "")).startswith(collection):
                upstream_more = True
                break
    names = ("id", "key", "verb", "summary", "owner") if collection == "decisions_open" else ("id", "kind", "state", "name", "doing")

    def compact_row(row: Any, text_limit: int) -> dict[str, str]:
        if not isinstance(row, dict):
            return {"id": "(malformed)"}
        result: dict[str, str] = {}
        for key in names:
            item = row.get(key)
            if item is None:
                continue
            text = str(item).replace("\r", " ").replace("\n", " ")
            result[key] = text[:128] if key in {"id", "key"} else text[:text_limit]
        return result

    def render(rendered_rows: list[dict[str, str]]) -> str:
        has_more = len(rendered_rows) < len(page_rows) or upstream_more
        next_offset = offset + len(rendered_rows)
        next_page = page + 1 if has_more else None
        expected_offset = page * page_size
        next_command = None
        if next_page is not None:
            suffix = str(next_page) if next_offset == expected_offset else f"{next_page}:{next_offset}"
            next_command = f"{command} {suffix}"
        result: dict[str, Any] = {"schema": "fm-bearings.v1", collection: rendered_rows, "pagination": {
            "page": page,
            "page_size": page_size,
            "collection": collection,
            "next_page": next_page,
            "next_offset": next_offset if next_page is not None else None,
            "next_command": next_command,
        }}
        generated = value.get("generated")
        if isinstance(generated, str):
            result["generated"] = generated[:64]
        return json.dumps(result, separators=(",", ":"))

    best_rows: list[dict[str, str]] = []
    best_output = ""
    for text_limit in (128, 96, 64, 48, 32, 24, 16, 8):
        candidate_rows: list[dict[str, str]] = []
        for row in page_rows:
            candidate = candidate_rows + [compact_row(row, text_limit)]
            if len(render(candidate)) > MAX_MESSAGE_CHARS:
                break
            candidate_rows = candidate
        if len(candidate_rows) > len(best_rows):
            best_rows = candidate_rows
            best_output = render(candidate_rows)
        if len(best_rows) == len(page_rows):
            break
    if not best_output:
        best_output = render(best_rows)
    return best_output


def _telegram_page_size() -> int:
    raw = os.environ.get("FM_TELEGRAM_PAGE_SIZE", str(DEFAULT_TELEGRAM_PAGE_SIZE))
    if re.fullmatch(r"[0-9]+", raw) is None:
        raise TelegramError(f"Telegram page size must be between 1 and {MAX_TELEGRAM_PAGE_SIZE}")
    value = int(raw)
    if value < 1 or value > MAX_TELEGRAM_PAGE_SIZE:
        raise TelegramError(f"Telegram page size must be between 1 and {MAX_TELEGRAM_PAGE_SIZE}")
    return value


def _telegram_page_number(text: str, command: str) -> tuple[int, int | None]:
    if text == command:
        return 1, None
    prefix = f"{command} "
    if not text.startswith(prefix):
        raise TelegramError("unsupported Telegram command")
    raw = text[len(prefix):]
    parts = raw.split(":")
    if len(parts) not in (1, 2) or any(re.fullmatch(r"[0-9]{1,7}", part) is None for part in parts):
        raise TelegramError(f"{command[1:]} page must be between 1 and {MAX_TELEGRAM_PAGE}")
    page = int(parts[0])
    if page < 1 or page > MAX_TELEGRAM_PAGE:
        raise TelegramError(f"{command[1:]} page must be between 1 and {MAX_TELEGRAM_PAGE}")
    if len(parts) == 1:
        return page, None
    offset = int(parts[1])
    if offset < 0 or offset > MAX_TELEGRAM_PAGE * MAX_TELEGRAM_PAGE_SIZE:
        raise TelegramError(f"{command[1:]} continuation is malformed")
    return page, offset


def _telegram_snapshot_page(command: str, page: int, page_size: int, page_offset: int | None = None) -> str:
    collection = "in_flight" if command == "/status" else "decisions_open"
    offset = (page - 1) * page_size if page_offset is None else page_offset
    limit = page_size + 1
    env_extra = {
        "FM_TELEGRAM_PAGE_KIND": collection,
        "FM_TELEGRAM_PAGE_OFFSET": str(offset),
        "FM_TELEGRAM_PAGE_LIMIT": str(limit),
    }
    if collection == "in_flight":
        env_extra.update({"FM_BEARINGS_IN_FLIGHT": str(limit), "FM_BEARINGS_IN_FLIGHT_OFFSET": str(offset)})
    else:
        env_extra.update({"FM_BEARINGS_DECISIONS": str(limit), "FM_BEARINGS_DECISIONS_OFFSET": str(offset), "FM_BEARINGS_DECISIONS_PAGED": "1"})
    arguments = [str(root() / "bin/fm-bearings-snapshot.sh"), "--json"]
    if command == "/decisions":
        arguments.append("--all-decisions")
    return owner_result(arguments, env_extra=env_extra, page=(command, page, page_size, collection, offset))


def owner_result(argv: list[str], stdin: str = "", env_extra: dict[str, str] | None = None, page: tuple[str, int, int, str, int] | None = None, steer: bool = False) -> str:
    try:
        output = owner(argv, stdin, env_extra, steer)
    except DurableOwnerError as exc:
        raise DurableOwnerError(_telegram_owner_error(exc)) from exc
    except TelegramError as exc:
        raise TelegramError(_telegram_owner_error(exc)) from exc
    if page is not None:
        command, page_number, page_size, collection, page_offset = page
        result = _telegram_page_output(output, command, page_number, page_size, collection, page_offset)
    else:
        result = _telegram_owner_output(output)
    return telegram_response(result)


def dispatch(text: str, user_id: str, chat_id: str, update_id: str) -> str:
    if numeric_value(user_id, ID_RE) is None or numeric_value(chat_id, CHAT_ID_RE) is None or numeric_value(update_id, ID_RE) is None:
        raise TelegramError("Telegram identity or update ID is malformed")
    record = load_pairing()
    if not identity(record, user_id, chat_id):
        raise TelegramError("Telegram identity is not paired")
    text = validate_text(text)
    if text == "/status" or text.startswith("/status "):
        page, page_offset = _telegram_page_number(text, "/status")
        return _telegram_snapshot_page("/status", page, _telegram_page_size(), page_offset)
    if text == "/decisions" or text.startswith("/decisions "):
        page, page_offset = _telegram_page_number(text, "/decisions")
        return _telegram_snapshot_page("/decisions", page, _telegram_page_size(), page_offset)
    if text.startswith("/note "):
        body = validate_text(text[6:], "note")
        return owner_result([str(root() / "bin/fm-inbox.sh"), "note", "--request-id", f"telegram-{update_id}", "--json", "-"], body)
    if text.startswith("/steer "):
        rest = validate_text(text[7:], "steer")
        target, separator, body = rest.partition(" ")
        if not separator or not WORKER_RE.fullmatch(target):
            raise TelegramError("steer target or text is invalid")
        body = validate_steer_text(body)
        if os.name == "nt" and portable_target_is_remote(target, operational_state_dir()):
            raise TelegramError("Windows remote worker status and steer are unsupported; run Telegram on the remote Firstmate home")
        delivery_id = hashlib.sha256(f"telegram-steer-{update_id}".encode("ascii")).hexdigest()[:16]
        if portable_target_kind(target, operational_state_dir()) == "secondmate":
            return owner_result([str(root() / "bin" / "fm-send.sh"), target, "--fire-and-forget", delivery_id, body], env_extra={"FM_SEND_IDEMPOTENT": "1", "FM_TELEGRAM_DELIVERY_ID": delivery_id}, steer=True)
        return owner_result([str(root() / "bin" / "fm-send.sh"), target, body], env_extra={"FM_SEND_IDEMPOTENT": "1", "FM_TELEGRAM_DELIVERY_ID": delivery_id}, steer=True)
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
    return numeric_value(value, pattern)


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


def load_record(path: Path, schema: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise TelegramError(f"missing Telegram record: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TelegramError(f"Telegram record is malformed: {path}") from exc
    if not isinstance(value, dict) or value.get("schema") != schema:
        raise TelegramError(f"Telegram record has incompatible schema: {path}")
    return value


PAIRING_REDACTED_TEXT = "/start [pairing nonce redacted]"
PAIRING_INVALID_TEXT = "/start [invalid pairing nonce]"


def redact_pairing_text(text: str) -> tuple[str, str | None]:
    if text in (PAIRING_REDACTED_TEXT, PAIRING_INVALID_TEXT) or not text.startswith("/start "):
        return text, None
    try:
        return PAIRING_REDACTED_TEXT, nonce_hash(text[7:])
    except TelegramError:
        return PAIRING_INVALID_TEXT, None


def update_message(update: dict[str, Any], update_id: str) -> dict[str, Any]:
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
    validation_error = None
    if valid_message:
        try:
            oversized = utf8_length(text, "Telegram message") > MAX_COMMAND_BYTES
        except TelegramError:
            valid_message = False
            oversized = False
            validation_error = "Telegram message contains malformed Unicode"
            text = "[malformed Unicode]"
    else:
        oversized = False
    pairing_hash = None
    if not valid_message and validation_error is None:
        text = ""
    elif valid_message:
        text, pairing_hash = redact_pairing_text(text)
    return {
        "schema": "fm-telegram-inbox.v1",
        "update_id": update_id,
        "at": iso_now(),
        "user_id": user_id,
        "chat_id": chat_id,
        "text": bounded(text),
        "pairing_nonce_hash": pairing_hash,
        "valid_message": valid_message,
        "validation_error": validation_error,
        "oversized": oversized,
        "state": "pending",
        "effect": "pending",
        "delivery": "pending",
        "reply": None,
        "outcome": "rejected" if not valid_message else None,
        "outbound_sequence": None,
    }


def load_or_create_inbox(update: dict[str, Any], update_id: str) -> dict[str, Any]:
    path = state_dir() / "inbox" / f"{update_id}.json"
    if path.exists():
        record = load_record(path, "fm-telegram-inbox.v1")
        if str(record.get("update_id")) != update_id:
            raise TelegramError("Telegram inbox record has the wrong update ID")
        text = record.get("text", "")
        if isinstance(text, str):
            redacted, pairing_hash = redact_pairing_text(text)
            if redacted != text or pairing_hash is not None and record.get("pairing_nonce_hash") != pairing_hash:
                record["text"] = redacted
                if pairing_hash is not None:
                    record["pairing_nonce_hash"] = pairing_hash
                record_json(state_dir() / "inbox", f"{update_id}.json", record)
        return record
    record = update_message(update, update_id)
    record_json(state_dir() / "inbox", f"{update_id}.json", record)
    return record


def persist_inbound(record: dict[str, Any]) -> None:
    record_json(state_dir() / "inbound", f"{record['update_id']}.json", {
        "schema": "fm-telegram-inbound.v1",
        "update_id": record["update_id"],
        "at": record["at"],
        "user_id": record.get("user_id"),
        "chat_id": record.get("chat_id"),
        "text": record.get("text", ""),
    })


def prepare_pairing(record: dict[str, Any]) -> None:
    if not str(record.get("text", "")).startswith("/start ") or record.get("pairing_nonce_hash"):
        return
    raise TelegramError("pairing nonce is malformed")


def apply_effect(record: dict[str, Any]) -> None:
    if record.get("effect") == "complete":
        return
    record["state"] = "processing"
    record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
    user_id = record.get("user_id")
    chat_id = record.get("chat_id")
    text = record.get("text", "")
    command = text.split(" ", 1)[0] if text else "rejected"
    try:
        if not record.get("valid_message"):
            raise TelegramError(str(record.get("validation_error") or "Telegram message identity is malformed"))
        if record.get("oversized"):
            raise TelegramError("text is empty or too large")
        if text.startswith("/start "):
            prepare_pairing(record)
            pairing = load_pairing()
            if pairing.get("paired_user_id") is None:
                _pair_hash(str(record["pairing_nonce_hash"]), str(user_id), str(chat_id), str(record["update_id"]))
                reply = "Telegram paired."
            elif pairing.get("paired_update_id") == str(record["update_id"]) and identity(pairing, user_id, chat_id):
                reply = "Telegram paired."
            else:
                raise TelegramError("Telegram pairing is already complete")
        else:
            reply = dispatch(text, str(user_id), str(chat_id), str(record["update_id"]))
        outcome = "accepted"
    except DurableOwnerError as exc:
        record.update({"state": "pending", "effect": "pending", "reply": bounded(str(exc)), "outcome": "rejected", "command": command})
        record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
        return
    except TelegramError as exc:
        reply = _telegram_redact_paths(str(exc))
        outcome = "unconfirmed" if str(exc) == STEER_UNCONFIRMED else "rejected"
    record.update({"state": "response_pending", "effect": "complete", "reply": bounded(reply), "outcome": outcome, "command": command})
    record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)


def complete_update(record: dict[str, Any]) -> bool:
    apply_effect(record)
    if record.get("effect") != "complete":
        return False
    chat_id = record.get("chat_id")
    if not isinstance(chat_id, str):
        record.update({"state": "complete", "delivery": "not-applicable"})
        record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
        return True
    sequence = record.get("outbound_sequence")
    if sequence is None:
        sequence = str(record["update_id"])
        record["outbound_sequence"] = sequence
        record["state"] = "response_pending"
        record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
    try:
        send_message(chat_id, str(record["update_id"]), str(record.get("command", "rejected")), str(record.get("reply", "")), sequence)
    except TelegramRejected:
        record.update({"state": "complete", "delivery": "rejected"})
        record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
        return True
    except TelegramError:
        record["delivery"] = "pending"
        record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
        return False
    record.update({"state": "complete", "delivery": "sent", "outbound_sequence": sequence})
    record_json(state_dir() / "inbox", f"{record['update_id']}.json", record)
    return True


def _poll_once(machine: bool, event: bool = False) -> dict[str, Any]:
    token = token_value()
    claim_update_state(token.split(":", 1)[0])
    offset = read_offset()
    timeout = poll_timeout()
    response = api_call("getUpdates", {"offset": offset, "timeout": timeout, "allowed_updates": ["message"]}, timeout=timeout + 5, token=token)
    updates = response.get("result")
    if not isinstance(updates, list) or len(_json_encode(updates, "Telegram update response")) > MAX_UPDATE_BYTES:
        raise TelegramError("Telegram update response is malformed or too large")
    processed = duplicates = rejected = unconfirmed = 0
    highest = offset
    blocked = False
    for update in updates:
        update_id_value = update.get("update_id") if isinstance(update, dict) else None
        if isinstance(update_id_value, bool) or not isinstance(update_id_value, int) or update_id_value < 0 or update_id_value > MAX_TELEGRAM_ID:
            raise TelegramError("Telegram update is malformed")
        update_id = str(update_id_value)
        highest = max(highest, update_id_value + 1)
        record = load_or_create_inbox(update, update_id)
        persist_inbound(record)
        marker = state_dir() / "processed" / update_id
        marker_was_present = not claim_marker(marker)
        if record.get("effect") == "complete" and record.get("delivery") in ("sent", "not-applicable", "rejected"):
            duplicates += 1
            continue
        if marker_was_present:
            duplicates += 1
        if not complete_update(record):
            blocked = True
            continue
        if record.get("outcome") == "accepted":
            processed += 1
        elif record.get("outcome") == "unconfirmed":
            unconfirmed += 1
        else:
            rejected += 1
    next_offset = highest if not blocked else offset
    if next_offset != offset:
        atomic_write(offset_path(), f"{next_offset}\n".encode())
    if blocked:
        raise TelegramError("Telegram outbound response remains pending")
    output = {"schema": "fm-telegram-poll.v1", "processed": processed, "duplicates": duplicates, "rejected": rejected, "unconfirmed": unconfirmed, "next_offset": next_offset}
    if event:
        print(f"schema={RESULT_SCHEMA}\nstatus=ok\nprocessed={processed}\nduplicates={duplicates}\nrejected={rejected}\nunconfirmed={unconfirmed}\n")
    elif machine:
        print(json.dumps(output, sort_keys=True))
    else:
        print(f"processed {processed}; duplicates {duplicates}; rejected {rejected}; unconfirmed {unconfirmed}")
    return output


def _poll(machine: bool, event: bool = False) -> dict[str, Any]:
    state = state_dir()
    ensure_private_dir(state)
    lock = state / ".poll.lock"
    token = portable_lock_acquire(lock)
    try:
        return _poll_once(machine, event)
    finally:
        portable_lock_release(lock, token)


def poll(machine: bool, event: bool = False) -> dict[str, Any]:
    try:
        return _poll(machine, event)
    except TelegramError as exc:
        record_poll_error(str(exc))
        raise


def _json_encode(value: Any, label: str) -> bytes:
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    except (TypeError, ValueError, OverflowError, RecursionError, UnicodeEncodeError) as exc:
        raise TelegramError(f"{label} contains malformed data") from exc


def record_json(directory: Path, name: str, value: dict[str, Any]) -> None:
    raw = _json_encode(value, "Telegram record") + b"\n"
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


def send_message(chat_id: str, update_id: str, command: str, text: str, sequence: Any = None) -> str:
    normalized_chat = numeric_value(chat_id, CHAT_ID_RE)
    normalized_update = numeric_value(update_id, ID_RE)
    if normalized_chat is None or normalized_update is None:
        raise TelegramError("Telegram outbound identity is malformed")
    chat_id = normalized_chat
    update_id = normalized_update
    text = telegram_response(text)
    out_dir = state_dir() / "outbound"
    if sequence is None:
        sequence = next_sequence(out_dir)
    normalized_sequence = numeric_value(sequence, ID_RE, MAX_TELEGRAM_OFFSET)
    if normalized_sequence is None:
        raise TelegramError("Telegram outbound sequence is malformed")
    sequence = normalized_sequence
    path = out_dir / f"{sequence}.json"
    if path.exists():
        record = load_record(path, "fm-telegram-outbound.v1")
        if record.get("update_id") != update_id or record.get("chat_id") != chat_id or record.get("text") != text:
            raise TelegramError("Telegram outbound record does not match update")
        if record.get("api_ok") is True:
            return sequence
    else:
        record = {"schema": "fm-telegram-outbound.v1", "sequence": sequence, "update_id": update_id, "chat_id": chat_id, "command": command, "text": text, "at": iso_now(), "api_ok": False, "delivery": "pending", "attempts": 0}
    record["attempts"] = int(record.get("attempts", 0)) + 1
    record["delivery"] = "unknown"
    record_json(out_dir, f"{sequence}.json", record)
    try:
        api_call("sendMessage", {"chat_id": int(chat_id), "text": text})
    except TelegramError as exc:
        record["error"] = "Telegram API unavailable or rejected response"
        if isinstance(exc, TelegramRejected):
            record["delivery"] = "rejected"
        record_json(out_dir, f"{sequence}.json", record)
        raise
    record.update({"api_ok": True, "delivery": "sent"})
    record.pop("error", None)
    record_json(out_dir, f"{sequence}.json", record)
    return sequence


def offset_path() -> Path:
    return state_dir() / "offset"


def read_offset() -> int:
    path = offset_path()
    if not path.exists():
        return 0
    value = read_text(path)
    if numeric_value(value, ID_RE, MAX_TELEGRAM_OFFSET) is None:
        raise TelegramError("Telegram offset is malformed")
    try:
        age = time.time() - path.stat().st_mtime
    except OSError as exc:
        raise TelegramError("Telegram offset is unreadable") from exc
    return int(value) if age <= TELEGRAM_UPDATE_RETENTION else 0


def claim_update_state(bot_id: str) -> None:
    path = state_dir() / "bot-id"
    previous = read_text(path) if path.exists() or path.is_symlink() else None
    if previous == bot_id:
        return
    if previous is not None:
        if numeric_value(previous, ID_RE) is None:
            raise TelegramError("Telegram bot identity state is malformed")
        retired = state_dir() / "retired" / f"{previous}-{now()}-{secrets.token_hex(4)}"
        for name in UPDATE_STATE_NAMES:
            source = state_dir() / name
            if source.exists() or source.is_symlink():
                ensure_private_dir(retired)
                try:
                    os.replace(source, retired / name)
                except OSError as exc:
                    raise TelegramError("Telegram update state could not be retired") from exc
    atomic_write(path, f"{bot_id}\n".encode())




def worker_path() -> Path:
    return state_dir() / "worker.json"


def worker_loop() -> None:
    if os.name == "nt":
        process = _portable_windows_process(os.getpid())
        if process is None:
            return
        kernel, handle, process_start = process
        kernel.CloseHandle(handle)
        handoff_deadline = time.monotonic() + PORTABLE_OWNER_TIMEOUT
        while True:
            if not worker_path().exists():
                return
            try:
                record = load_record(worker_path(), "fm-telegram-worker.v1")
                recorded_pid = int(record.get("pid", 0))
            except (TelegramError, TypeError, ValueError, OverflowError):
                return
            if recorded_pid == 0:
                if time.monotonic() >= handoff_deadline:
                    return
                time.sleep(0.05)
                continue
            if recorded_pid != os.getpid() or str(record.get("process_start", "")) != process_start:
                return
            break
    while worker_path().exists():
        if os.name == "nt":
            try:
                record = load_record(worker_path(), "fm-telegram-worker.v1")
                if int(record.get("pid", 0)) != os.getpid() or str(record.get("process_start", "")) != process_start:
                    return
            except (TelegramError, TypeError, ValueError, OverflowError):
                return
        try:
            poll(False)
        except TelegramError:
            time.sleep(5)


def portable_enable() -> str:
    token_value()
    load_pairing()
    path = worker_path()
    lock = state_dir() / ".worker.lock"
    token = portable_lock_acquire(lock)
    try:
        if path.exists():
            record = load_record(path, "fm-telegram-worker.v1")
            try:
                pid = int(record["pid"])
            except (TypeError, ValueError, KeyError, OverflowError):
                path.unlink(missing_ok=True)
            else:
                if pid <= 0:
                    path.unlink(missing_ok=True)
                else:
                    process = _portable_record_process(record)
                    if process is not None:
                        process[0].CloseHandle(process[1])
                        return "Telegram polling already enabled"
                    path.unlink(missing_ok=True)
        ensure_private_dir(path.parent)
        record_json(path.parent, path.name, {"schema": "fm-telegram-worker.v1", "pid": 0, "process_start": "", "at": iso_now()})
        flags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0) | getattr(subprocess, "DETACHED_PROCESS", 0)
        try:
            proc = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "worker"], cwd=root(), env={**os.environ, "FM_HOME": str(home())}, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)
        except (OSError, subprocess.SubprocessError) as exc:
            path.unlink(missing_ok=True)
            raise TelegramError("Telegram polling worker could not start") from exc
        process = _portable_windows_process(proc.pid)
        if process is None:
            try:
                proc.terminate()
            except OSError:
                pass
            path.unlink(missing_ok=True)
            raise TelegramError("Telegram polling worker identity could not be recorded")
        kernel, handle, process_start = process
        kernel.CloseHandle(handle)
        record_json(path.parent, path.name, {"schema": "fm-telegram-worker.v1", "pid": proc.pid, "process_start": process_start, "at": iso_now()})
        return "enabled Telegram polling"
    finally:
        portable_lock_release(lock, token)


def portable_disable() -> str:
    path = worker_path()
    lock = state_dir() / ".worker.lock"
    token = portable_lock_acquire(lock)
    try:
        if not path.exists():
            return "retired Telegram polling"
        record = load_record(path, "fm-telegram-worker.v1")
        process = _portable_record_process(record, terminate=True)
        if process is not None:
            kernel, handle = process
            try:
                kernel.TerminateProcess(handle, 15)
            finally:
                kernel.CloseHandle(handle)
        if path.is_symlink():
            raise TelegramError("unsafe Telegram worker state")
        path.unlink(missing_ok=True)
        return "retired Telegram polling"
    finally:
        portable_lock_release(lock, token)


def enable() -> str:
    if os.name == "nt":
        return portable_enable()
    token_value()
    load_pairing()
    adapter = root() / "bin" / "fm-procevent-telegram.sh"
    runner = root() / "bin" / "fm-procevent.sh"
    try:
        proc = subprocess.run([str(runner), "register", "telegram", "telegram-bot", "--", str(adapter), "poll"], cwd=root(), env={**os.environ, "FM_HOME": str(home())}, capture_output=True, text=False, timeout=20, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise TelegramError("Telegram polling registration failed") from exc
    if proc.returncode:
        raise TelegramError("Telegram polling registration failed")
    try:
        output = proc.stdout.decode("utf-8").strip()
    except (AttributeError, UnicodeDecodeError) as exc:
        raise TelegramError("Telegram polling registration returned malformed Unicode") from exc
    return output or "registered Telegram polling"


def disable() -> str:
    if os.name == "nt":
        return portable_disable()
    try:
        proc = subprocess.run([str(root() / "bin" / "fm-procevent.sh"), "retire", "telegram-bot"], cwd=root(), env={**os.environ, "FM_HOME": str(home())}, capture_output=True, text=False, timeout=20, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise TelegramError("Telegram polling retirement failed") from exc
    if proc.returncode:
        raise TelegramError("Telegram polling retirement failed")
    try:
        output = proc.stdout.decode("utf-8").strip()
    except (AttributeError, UnicodeDecodeError) as exc:
        raise TelegramError("Telegram polling retirement returned malformed Unicode") from exc
    return output or "retired Telegram polling"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="local outbound Telegram control")
    parser.add_argument("--json", action="store_true", dest="global_json")
    sub = parser.add_subparsers(dest="command", required=True)
    setup_parser = sub.add_parser("setup")
    setup_parser.add_argument("--json", action="store_true")
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
    sub.add_parser("worker")
    args = parser.parse_args(argv)
    try:
        if args.command == "setup":
            result = setup(setup_token(), args.json or args.global_json)
            if args.json or args.global_json:
                print(json.dumps(result, sort_keys=True))
        elif args.command == "dispatch":
            result = dispatch(args.text, args.user_id, args.chat_id, args.update_id)
            print(json.dumps({"schema": "fm-telegram-dispatch.v1", "text": bounded(result)}, sort_keys=True) if args.json or args.global_json else result)
        elif args.command == "poll":
            poll(args.json or args.global_json, args.event)
        elif args.command == "enable":
            print(enable())
        elif args.command == "disable":
            print(disable())
        elif args.command == "worker":
            worker_loop()
        return 0
    except TelegramError as exc:
        print(f"fm-telegram: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
