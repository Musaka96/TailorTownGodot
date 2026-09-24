"""Compose labelled review sheets from raw render rows (PIL).

Used by tools/shot_cloth_photo.gd and tools/shot_cloth_light.gd: Godot saves each
row as a plain PNG plus a JSON manifest, then runs this to build the sheets with a
title strip on top and a solid label band down the left of each row.

    python tools/cloth_sheets.py .dev/cloth_rows/manifest.json

Manifest:
    {"sheets": [{
        "out": ".dev/x.png", "width": 1600,
        "title": "SUIT, FRONT LIGHT", "subtitle": "optional smaller line",
        "rows": [{"image": ".dev/rows/a.png",
                  "band": {"style": "before" | "after" | "name", "lines": ["BEFORE", "..."]},
                  "caption": "optional strip above the row"}]
    }]}
Rows are scaled to fit the sheet width (minus the band, when a row has one).
Paths are relative to the project root (or absolute).
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets", "fonts", "Fredoka.ttf")
BAND_W = 220
PAD = 16
TITLE_BG = (24, 26, 30)
CAPTION_BG = (44, 47, 54)
WHITE = (255, 255, 255)
SOFT = (208, 212, 220)
# style: (band colour, heading size, body size)
BANDS = {
    "before": ((58, 58, 62), 46, 26),
    "after": ((22, 92, 52), 46, 26),
    "name": ((34, 46, 66), 34, 20),
}


def font(size, weight="SemiBold"):
    try:
        f = ImageFont.truetype(FONT, size)
        try:
            f.set_variation_by_name(weight)
        except (OSError, ValueError):
            pass
        return f
    except OSError:
        return ImageFont.load_default(size)


def path_of(p):
    return p if os.path.isabs(p) else os.path.join(ROOT, p)


def text_w(draw, text, f):
    box = draw.textbbox((0, 0), text, font=f)
    return box[2] - box[0]


def wrap(draw, text, f, width):
    """Greedy word wrap to `width` pixels."""
    lines, line = [], ""
    for word in text.split():
        trial = word if not line else line + " " + word
        if line and text_w(draw, trial, f) > width:
            lines.append(line)
            line = word
        else:
            line = trial
    if line:
        lines.append(line)
    return lines


def title_strip(width, title, subtitle):
    big = font(44, "Bold")
    lines, size = [], 24
    if subtitle:
        # Shrink the summary to fit one line; past 18 px, wrap it instead.
        probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        small = font(size, "Regular")
        while size > 18 and text_w(probe, subtitle, small) > width - 2 * PAD:
            size -= 1
            small = font(size, "Regular")
        lines = wrap(probe, subtitle, small, width - 2 * PAD - 8)
    line_h = int(size * 1.35)
    h = 72 if not lines else 72 + line_h * len(lines) + 14
    img = Image.new("RGB", (width, h), TITLE_BG)
    d = ImageDraw.Draw(img)
    d.text((PAD + 4, 10), title, font=big, fill=WHITE)
    for i, line in enumerate(lines):
        d.text((PAD + 4, 72 + i * line_h), line, font=small, fill=SOFT)
    return img


def caption_strip(width, text):
    f = font(26, "SemiBold")
    img = Image.new("RGB", (width, 44), CAPTION_BG)
    ImageDraw.Draw(img).text((PAD, 6), text, font=f, fill=WHITE)
    return img


def band(height, spec):
    colour, head_size, body_size = BANDS.get(spec.get("style", "name"), BANDS["name"])
    img = Image.new("RGB", (BAND_W, height), colour)
    d = ImageDraw.Draw(img)
    lines = spec.get("lines", [])
    blocks = []  # (text, font, line height)
    if lines:
        head = font(head_size, "Bold")
        # A long single word (a variant name) shrinks until it fits the band.
        widest = max(lines[0].split(), key=lambda w: text_w(d, w, head))
        while head_size > 18 and text_w(d, widest, head) > BAND_W - 2 * PAD:
            head_size -= 1
            head = font(head_size, "Bold")
        for part in wrap(d, lines[0], head, BAND_W - 2 * PAD):
            blocks.append((part, head, int(head_size * 1.2)))
        blocks.append(("", head, 6))
    body = font(body_size, "Medium")
    for line in lines[1:]:
        for part in wrap(d, line, body, BAND_W - 2 * PAD):
            blocks.append((part, body, int(body_size * 1.3)))
    total = sum(b[2] for b in blocks)
    y = max(PAD, (height - total) // 2)
    for text, f, lh in blocks:
        if text:
            d.text((PAD, y), text, font=f, fill=WHITE)
        y += lh
    return img


def row_image(width, row):
    src = Image.open(path_of(row["image"])).convert("RGB")
    spec = row.get("band")
    inner = width - BAND_W if spec else width
    h = round(src.height * inner / src.width)
    src = src.resize((inner, h), Image.LANCZOS)
    parts = []
    if row.get("caption"):
        parts.append(caption_strip(width, row["caption"]))
    line = Image.new("RGB", (width, h), (0, 0, 0))
    if spec:
        line.paste(band(h, spec), (0, 0))
        line.paste(src, (BAND_W, 0))
    else:
        line.paste(src, (0, 0))
    parts.append(line)
    if row.get("below"):
        parts.append(label_strip(width, BAND_W if spec else 0, inner, row["below"]))
    return parts


def label_strip(width, x0, inner, below):
    """A caption strip under a row: each label centred on its subject (xs are 0..1
    across the row image), wrapped to the gap between neighbours."""
    labels, xs = below["labels"], below["xs"]
    f = font(22, "Medium")
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    gap = min((b - a) for a, b in zip(xs, xs[1:])) * inner if len(xs) > 1 else inner
    col_w = max(80, int(gap) - 12)
    wrapped = [wrap(probe, text, f, col_w) for text in labels]
    line_h = 28
    h = 14 + line_h * max(len(w) for w in wrapped)
    img = Image.new("RGB", (width, h), CAPTION_BG)
    d = ImageDraw.Draw(img)
    for x, lines in zip(xs, wrapped):
        cx = x0 + x * inner
        for i, text in enumerate(lines):
            d.text((cx - text_w(d, text, f) / 2, 6 + i * line_h), text, font=f, fill=WHITE)
    return img


def compose(sheet):
    width = int(sheet.get("width", 1600))
    parts = [title_strip(width, sheet["title"], sheet.get("subtitle"))]
    gap = Image.new("RGB", (width, 4), TITLE_BG)
    for i, row in enumerate(sheet["rows"]):
        if i > 0:
            parts.append(gap)
        parts.extend(row_image(width, row))
    out = Image.new("RGB", (width, sum(p.height for p in parts)))
    y = 0
    for p in parts:
        out.paste(p, (0, y))
        y += p.height
    dest = path_of(sheet["out"])
    out.save(dest)
    print("Saved", sheet["out"], out.size)


def main():
    with open(sys.argv[1], encoding="utf-8") as fh:
        manifest = json.load(fh)
    for sheet in manifest["sheets"]:
        compose(sheet)


if __name__ == "__main__":
    main()
