"""Stand-in for the paired phone: inject Telegram updates and show the chat.

  phone.py <api-dir> send <user-id> <chat-id> <text>   queue one message update
  phone.py <api-dir> resend <update-id>                 re-queue a past update (replay)
  phone.py <api-dir> chat                               print the conversation
"""
import json
import os
import sys
import time

root = sys.argv[1]
action = sys.argv[2]


def load(name, default):
    try:
        with open(os.path.join(root, name), encoding="utf-8") as stream:
            return json.load(stream)
    except FileNotFoundError:
        return default


def save(name, value):
    tmp = os.path.join(root, "." + name + ".tmp")
    with open(tmp, "w", encoding="utf-8") as stream:
        json.dump(value, stream)
    os.replace(tmp, os.path.join(root, name))


if action == "send":
    user_id, chat_id, text = int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    history = load("history.json", [])
    update_id = 700000001 + len(history)
    update = {"update_id": update_id, "message": {"message_id": len(history) + 1, "date": int(time.time()), "from": {"id": user_id, "is_bot": False, "first_name": "Phone"}, "chat": {"id": chat_id, "type": "private" if chat_id > 0 else "group"}, "text": text}}
    history.append({"at": time.strftime("%H:%M:%S"), "update": update})
    save("history.json", history)
    queue = load("queue.json", [])
    queue.append(update)
    save("queue.json", queue)
    print(update_id)
elif action == "resend":
    wanted = int(sys.argv[3])
    for item in load("history.json", []):
        if item["update"]["update_id"] == wanted:
            queue = load("queue.json", [])
            queue.append(item["update"])
            save("queue.json", queue)
            print(wanted)
            break
    else:
        raise SystemExit("unknown update")
elif action == "chat":
    events = []
    for item in load("history.json", []):
        message = item["update"]["message"]
        events.append((item["at"], 0, f"[{item['at']}] phone user={message['from']['id']} chat={message['chat']['id']} (update {item['update']['update_id']}) >> {message['text']}"))
    try:
        with open(os.path.join(root, "sent.jsonl"), encoding="utf-8") as stream:
            for line in stream:
                sent = json.loads(line)
                events.append((sent["at"], 1, f"[{sent['at']}] bot -> chat={sent['chat_id']} << {sent['text']}"))
    except FileNotFoundError:
        pass
    for _, _, text in sorted(events, key=lambda event: (event[0], event[1])):
        print(text)
