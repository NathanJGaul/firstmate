"""Demo only (not product code): take fm-telegram.py setup --json's explicit-colour
QR, recover the module grid, and reprint it with U+2580 half blocks
(fg = upper module, bg = lower module) to show the same code at half the size."""
import json, re, sys
setup = json.load(sys.stdin)
grid = [[p.startswith("38;5;16;") for p in re.findall("\x1b\\[([0-9;]+)m\u2588\u2588", row)] for row in setup["qr"].rstrip("\n").split("\n")]
colour = {True: 16, False: 231}
print(f"Pairing link: {setup['deep_link']}")
for y in range(0, len(grid), 2):
    top, bottom = grid[y], grid[y + 1] if y + 1 < len(grid) else [False] * len(grid[y])
    print("".join(f"\x1b[38;5;{colour[t]};48;5;{colour[b]}m\u2580" for t, b in zip(top, bottom)) + "\x1b[0m")
