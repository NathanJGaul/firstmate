"""Render captured terminal text to a PNG the way a terminal paints it.

  render_terminal.py <text-file> <out.png> [light|dark]

Each character occupies one 10x20 cell; U+2588 FULL BLOCK fills its cell with the
foreground colour (as terminals do), other glyphs are drawn with a monospace font.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

source, target = sys.argv[1], sys.argv[2]
theme = sys.argv[3] if len(sys.argv) > 3 else "light"
fg, bg = ((20, 20, 20), (250, 250, 250)) if theme == "light" else ((235, 235, 235), (28, 30, 36))
lines = open(source, encoding="utf-8").read().splitlines()
cw, ch = 10, 20
width = max((len(line) for line in lines), default=1) + 2
image = Image.new("RGB", (width * cw, (len(lines) + 2) * ch), bg)
draw = ImageDraw.Draw(image)
try:
    font = ImageFont.truetype("DejaVuSansMono.ttf", 15)
except OSError:
    font = ImageFont.load_default(size=15)
for row, line in enumerate(lines, start=1):
    for column, char in enumerate(line, start=1):
        x, y = column * cw, row * ch
        if char == "█":
            draw.rectangle([x, y, x + cw - 1, y + ch - 1], fill=fg)
        elif char != " ":
            draw.text((x, y + 1), char, font=font, fill=fg)
image.save(target)
