"""Scripted stand-in worker: on each doorbell line, act on every inbox record in
numeric order (append its body to the acted log), then mv it into handled/."""
import os, sys
inbox = os.environ["FM_TASK_INBOX"]
log = os.path.join(os.path.dirname(inbox), "w-steer.acted.log")
print(f"scripted worker ready; inbox={inbox}", flush=True)
for line in sys.stdin:
    print(f"doorbell received: {line.strip()}", flush=True)
    for name in sorted(n for n in os.listdir(inbox) if n.endswith(".msg")):
        path = os.path.join(inbox, name)
        text = open(path, encoding="utf-8").read()
        body = text.split("\n--\n", 1)[-1].strip()
        print(f"--- acting on {name}: {body}", flush=True)
        with open(log, "a", encoding="utf-8") as stream:
            stream.write(f"{name} {body}\n")
        os.makedirs(os.path.join(inbox, "handled"), exist_ok=True)
        os.replace(path, os.path.join(inbox, "handled", name))
        print(f"    moved {name} -> handled/", flush=True)
