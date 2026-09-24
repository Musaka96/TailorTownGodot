"""Promote the seamless scanned-grain tiles for the eight game fabrics.

Copies <sheet>_<n>_tile.png / _tile_n.png from assets/dev/cloth_refs/ (made by
make_grain.py) into assets/textures/grain/ as <fabric>.png / <fabric>_n.png, and
writes each a Godot .import with the same settings make_grain.py uses (lossless,
mipmaps, detect_3d off; grain is linear data). Also writes a contact sheet
IMPORT/cloth_refs/grain_promoted.png: grain scaled to a mid-grey mean (stored
0.25 -> 0.5) on top, normal maps below.

Run from the repo root:  python tools/cloth_refs/promote_grain.py
"""

import hashlib
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(ROOT, "assets", "dev", "cloth_refs")
OUT_DIR = os.path.join(ROOT, "assets", "textures", "grain")
OUT_RES = "res://assets/textures/grain"
CONTACT = os.path.join(ROOT, "IMPORT", "cloth_refs", "grain_promoted.png")
GRAIN_TEMPLATE = os.path.join(ROOT, "assets", "textures", "fabrics", "worsted.png.import")
NORMAL_TEMPLATE = os.path.join(ROOT, "assets", "textures", "fabrics", "worsted_n.png.import")

# game fabric <- source tile
FABRICS = [
    ("worsted", "suitings_1_tile"),
    ("flannel", "suitings_2_tile"),
    ("tweed", "suitings_3_tile"),
    ("mohair", "suitings_4_tile"),
    ("linen", "suitings_5_tile"),
    ("cotton", "suitings_9_tile"),
    ("poplin", "shirtings_1_tile"),
    ("oxford", "shirtings_3_tile"),
]
GRAIN_MEAN = 0.25  # must match make_grain.py
CELL = 256


def write_import(png_name, template):
    res_path = "%s/%s" % (OUT_RES, png_name)
    md5 = hashlib.md5(res_path.encode("utf-8")).hexdigest()
    dest = "res://.godot/imported/%s-%s.ctex" % (png_name, md5)
    with open(template, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    out = []
    for line in lines:
        if line.startswith("uid="):
            continue  # Godot assigns a fresh uid on import
        if line.startswith("path="):
            line = 'path="%s"' % dest
        elif line.startswith("source_file="):
            line = 'source_file="%s"' % res_path
        elif line.startswith("dest_files="):
            line = 'dest_files=["%s"]' % dest
        elif line.startswith("detect_3d/compress_to="):
            line = "detect_3d/compress_to=0"  # stay lossless: grain is linear data
        out.append(line)
    path = os.path.join(OUT_DIR, png_name + ".import")
    # Keep the uid Godot assigned on an earlier import, so re-runs don't churn it.
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            old_uid = [ln for ln in f.read().splitlines() if ln.startswith("uid=")]
        if old_uid:
            out.insert(out.index('type="CompressedTexture2D"') + 1, old_uid[0])
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


def contact_sheet():
    sheet = Image.new("RGB", (CELL * len(FABRICS), CELL * 2))
    for i, (name, _src) in enumerate(FABRICS):
        grain = Image.open(os.path.join(OUT_DIR, name + ".png")).convert("RGB")
        a = np.asarray(grain).astype(np.float64) / 255.0 / GRAIN_MEAN * 0.5
        a = (np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
        top = Image.fromarray(a, "RGB").resize((CELL, CELL), Image.LANCZOS)
        normal = Image.open(os.path.join(OUT_DIR, name + "_n.png")).convert("RGB")
        sheet.paste(top, (i * CELL, 0))
        sheet.paste(normal.resize((CELL, CELL), Image.LANCZOS), (i * CELL, CELL))
    sheet.save(CONTACT)
    print("wrote", CONTACT)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, src in FABRICS:
        for suffix, src_suffix, template in [
            ("", "", GRAIN_TEMPLATE),
            ("_n", "_n", NORMAL_TEMPLATE),
        ]:
            png = name + suffix + ".png"
            shutil.copyfile(
                os.path.join(SRC_DIR, src + src_suffix + ".png"), os.path.join(OUT_DIR, png)
            )
            write_import(png, template)
        print("  %-8s <- %s" % (name, src))
    contact_sheet()


if __name__ == "__main__":
    main()
