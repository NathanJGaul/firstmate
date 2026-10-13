"""Render a tmux `capture-pane -e -p` dump (SGR escapes preserved) to a PNG,
the way a terminal paints it: every cell gets its foreground/background from the
SGR state (256-colour palette, explicit), falling back to the theme's default
colours when the program set none. U+2588 FULL BLOCK fills the cell with the
foreground colour; spaces show only the background colour.

  render_ansi.py <capture.txt> <out.png> light|dark
"""
import re
import sys

from PIL import Image

source, target, theme = sys.argv[1], sys.argv[2], sys.argv[3]
DEFAULT_FG, DEFAULT_BG = ((20, 20, 20), (250, 250, 250)) if theme == "light" else ((235, 235, 235), (28, 30, 36))


def xterm256(n):
    base = [(0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0), (0, 0, 238), (205, 0, 205), (0, 205, 205), (229, 229, 229),
            (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0), (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]
    if n < 16:
        return base[n]
    if n < 232:
        n -= 16
        steps = [0, 95, 135, 175, 215, 255]
        return (steps[n // 36], steps[(n // 6) % 6], steps[n % 6])
    v = 8 + (n - 232) * 10
    return (v, v, v)


token = re.compile(r"\x1b\[([0-9;]*)m|(.)", re.S)
rows = []
fg, bg = None, None  # SGR state carries across lines, as in a real terminal
for line in open(source, encoding="utf-8").read().split("\n"):
    cells = []
    for match in token.finditer(line):
        if match.group(1) is not None:
            params = [int(p) if p else 0 for p in match.group(1).split(";")] or [0]
            i = 0
            while i < len(params):
                p = params[i]
                if p == 0:
                    fg, bg = None, None
                elif p == 39:
                    fg = None
                elif p == 49:
                    bg = None
                elif p in (38, 48) and i + 2 < len(params) and params[i + 1] == 5:
                    if p == 38:
                        fg = xterm256(params[i + 2])
                    else:
                        bg = xterm256(params[i + 2])
                    i += 2
                elif 30 <= p <= 37:
                    fg = xterm256(p - 30)
                elif 40 <= p <= 47:
                    bg = xterm256(p - 40)
                i += 1
        else:
            cells.append((match.group(2), fg or DEFAULT_FG, bg or DEFAULT_BG))
    rows.append(cells)
while rows and not rows[-1]:
    rows.pop()
cw, ch = 8, 16
width = max(len(r) for r in rows)
image = Image.new("RGB", ((width + 2) * cw, (len(rows) + 2) * ch), DEFAULT_BG)
px = image.load()
for y, row in enumerate(rows, start=1):
    for x, (char, fg, bg) in enumerate(row, start=1):
        colour = fg if char == "█" else bg
        if char == "\u2580":
            for dy in range(ch):
                for dx in range(cw):
                    px[x * cw + dx, y * ch + dy] = fg if dy < ch // 2 else bg
            continue
        if char not in ("█", " ", "\u2580"):
            # text glyph: draw a mid-tone bar so text lines are visible but never read as modules
            colour = tuple((a + b) // 2 for a, b in zip(fg, bg))
        for dy in range(ch):
            for dx in range(cw):
                if char not in ("█", " ") and not (4 <= dy <= 11 and 1 <= dx <= 6):
                    px[x * cw + dx, y * ch + dy] = bg
                else:
                    px[x * cw + dx, y * ch + dy] = colour
image.save(target)
