"""Tile the per-bone weight renders of tools/blender/weight_renders.py into one contact
sheet per mesh: a row per bone (front | back, each cropped to the mesh), labelled with
the bone's name.

    python tools/weight_sheets.py IMPORT/CHARREWORK/report/weights [more dirs...]

Writes <dir>/<mesh>__sheet.png next to the renders.
"""

import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

TILE_W, TILE_H = 900, 700
LABEL_H = 64


def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def sheet(folder: Path) -> list:
    groups = defaultdict(dict)
    for f in sorted(folder.glob("*__*__*.png")):
        mesh, bone, view = f.stem.split("__")
        groups[mesh].setdefault(bone, {})[view] = f
    out = []
    big = font(40)
    for mesh, bones in groups.items():
        rows = sorted(bones)
        img = Image.new("RGB", (TILE_W * 2, len(rows) * (TILE_H + LABEL_H) + LABEL_H), "white")
        draw = ImageDraw.Draw(img)
        draw.text((12, 10), "%s   (front | back, weight 0 blue .. 1 red)" % mesh, fill="black",
                  font=big)
        for r, bone in enumerate(rows):
            y = LABEL_H + r * (TILE_H + LABEL_H)
            draw.text((12, y + 10), bone, fill="black", font=big)
            for c, view in enumerate(("front", "back")):
                path = bones[bone].get(view)
                if path is None:
                    continue
                tile = Image.open(path).convert("RGB")
                # crop to the mesh (the renders are portrait; a T-posed jacket is a band)
                diff = ImageChops.difference(tile, Image.new("RGB", tile.size, "white"))
                bbox = diff.convert("L").point(lambda v: 255 if v > 12 else 0).getbbox()
                if bbox:
                    tile = tile.crop(bbox)
                tile.thumbnail((TILE_W - 20, TILE_H - 10))
                img.paste(tile, (c * TILE_W + (TILE_W - tile.width) // 2, y + LABEL_H))
        path = folder / ("%s__sheet.png" % mesh)
        img.save(path)
        out.append(str(path))
    return out


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        for p in sheet(Path(arg)):
            print(p)
