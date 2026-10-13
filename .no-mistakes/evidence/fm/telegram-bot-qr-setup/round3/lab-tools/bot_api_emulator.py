"""Local Telegram Bot API emulator for driving bin/fm-telegram.py in a lab.

Implements the subset Firstmate uses (getMe, getUpdates long-poll with offset
confirmation, sendMessage) with Telegram's URL shape /bot<token>/<method>.
State lives in <dir>: queue.json (pending updates injected by phone.py),
sent.jsonl (bot replies), requests.log (method log, token never written),
and flag files fail-send / reject-send / redirect.
"""
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

root = sys.argv[1]
port = int(sys.argv[2])
token = open(os.path.join(root, "token"), encoding="utf-8").read().strip()
lock = threading.Lock()


def load_queue():
    try:
        with open(os.path.join(root, "queue.json"), encoding="utf-8") as stream:
            return json.load(stream)
    except FileNotFoundError:
        return []


def save_queue(queue):
    tmp = os.path.join(root, ".queue.tmp")
    with open(tmp, "w", encoding="utf-8") as stream:
        json.dump(queue, stream)
    os.replace(tmp, os.path.join(root, "queue.json"))


def log(line):
    with open(os.path.join(root, "requests.log"), "a", encoding="utf-8") as stream:
        stream.write(time.strftime("%H:%M:%S ") + line + "\n")


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, payload):
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        params = json.loads(self.rfile.read(length) or b"{}")
        parts = self.path.split("/")
        presented = parts[1][3:] if len(parts) > 2 and parts[1].startswith("bot") else ""
        method = parts[-1]
        log(f"{method} token_ok={presented == token} params={json.dumps({k: v for k, v in params.items() if k != 'text'})}")
        if os.path.exists(os.path.join(root, "redirect")):
            self.send_response(307)
            self.send_header("Location", "http://198.51.100.7/redirected" + self.path)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if presented != token:
            return self.reply(401, {"ok": False, "error_code": 401, "description": "Unauthorized"})
        if method == "getMe":
            return self.reply(200, {"ok": True, "result": {"id": int(token.split(":")[0]), "is_bot": True, "first_name": "Firstmate Lab", "username": (open(os.path.join(root, "username")).read().strip() if os.path.exists(os.path.join(root, "username")) else "fm_lab_bot")}})
        if method == "getUpdates":
            offset = int(params.get("offset", 0))
            deadline = time.time() + min(int(params.get("timeout", 0)), 5)
            while True:
                with lock:
                    queue = [update for update in load_queue() if update["update_id"] >= offset]
                    save_queue(queue)
                if queue or time.time() >= deadline:
                    return self.reply(200, {"ok": True, "result": queue})
                time.sleep(0.2)
        if method == "sendMessage":
            if os.path.exists(os.path.join(root, "fail-send")):
                return self.reply(502, {"ok": False, "error_code": 502, "description": "Bad Gateway"})
            if os.path.exists(os.path.join(root, "reject-send")):
                return self.reply(403, {"ok": False, "error_code": 403, "description": "Forbidden: bot was blocked by the user"})
            with open(os.path.join(root, "sent.jsonl"), "a", encoding="utf-8") as stream:
                stream.write(json.dumps({"at": time.strftime("%H:%M:%S"), "chat_id": params.get("chat_id"), "text": params.get("text")}) + "\n")
            return self.reply(200, {"ok": True, "result": {"message_id": int(time.time() * 1000) % 100000}})
        return self.reply(404, {"ok": False, "error_code": 404, "description": "Not Found"})

    def log_message(self, *_):
        pass


ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
