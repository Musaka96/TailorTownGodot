"""Grid the shoulder study renders of tools/shot_char2.gd (--only=shoulder_ --arm-drop)
into contact sheets: rows = arm drop in degrees, columns = variant, one sheet per view.

    python tools/shoulder_sheets.py [IMPORT/CHARREWORK/report/shoulder] [basic,capped,band] [0,45,90]

Every tile of a sheet is cropped to the same box (the union of what differs from the
background across that view), so the framing matches, then scaled to TILE_H tall.
Writes shoulder_sheet_<front|back|closeup>.png in the same folder.
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

TILE_H = 900
HEAD = 90


def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main(argv):
    folder = Path(argv[1] if len(argv) > 1 else "IMPORT/CHARREWORK/report/shoulder")
    variants = (argv[2] if len(argv) > 2 else "basic,capped,band").split(",")
    degrees = (argv[3] if len(argv) > 3 else "0,45,90").split(",")
    big = font(52)
    for view in ("front", "back", "closeup"):
        paths = {(d, v): folder / ("shoulder_%s_%s_%s.png" % (v, d, view))
                 for d in degrees for v in variants}
        images = {k: Image.open(p).convert("RGB") for k, p in paths.items() if p.is_file()}
        if not images:
            continue
        box = None
        for img in images.values():
            bg = Image.new("RGB", img.size, img.getpixel((2, 2)))
            b = ImageChops.difference(img, bg).convert("L").point(
                lambda x: 255 if x > 14 else 0).getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                             max(box[2], b[2]), max(box[3], b[3]))
        pad = 20
        any_img = next(iter(images.values()))
        box = (max(box[0] - pad, 0), max(box[1] - pad, 0),
               min(box[2] + pad, any_img.width), min(box[3] + pad, any_img.height))
        scale = TILE_H / float(box[3] - box[1])
        tile_w = int((box[2] - box[0]) * scale)
        sheet = Image.new("RGB", (HEAD * 3 + tile_w * len(variants),
                                  HEAD + TILE_H * len(degrees)), "white")
        draw = ImageDraw.Draw(sheet)
        for c, v in enumerate(variants):
            draw.text((HEAD * 3 + c * tile_w + 20, 18), v, fill="black", font=big)
        for r, d in enumerate(degrees):
            draw.text((16, HEAD + r * TILE_H + TILE_H // 2 - 30), "%s deg" % d, fill="black",
                      font=big)
            for c, v in enumerate(variants):
                img = images.get((d, v))
                if img is None:
                    continue
                tile = img.crop(box).resize((tile_w, TILE_H), Image.LANCZOS)
                sheet.paste(tile, (HEAD * 3 + c * tile_w, HEAD + r * TILE_H))
        out = folder / ("shoulder_sheet_%s.png" % view)
        sheet.save(out)
        print(out)


if __name__ == "__main__":
    main(sys.argv)
