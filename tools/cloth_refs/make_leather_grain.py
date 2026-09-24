"""Procedural leather grain tiles for the shoe material (materials/leather.gdshader).

STAND-INS: these are drawn from noise until the scanned leather reference sheet
(IMPORT/cloth_refs/S_sheet_leather) is cut and promoted the way the cloth grains
were (make_grain.py + promote_grain.py). Then this script retires.

Writes, in assets/textures/grain/, the same format make_grain.py produces:
  leather_calf.png     fine tight calf grain: ~3.5 px Worley cells, soft dark
                       creases along the cell borders, a faint large-scale mottle,
                       low contrast (ratio about 0.85-1.15)
  leather_pebble.png   embossed pebble grain: ~17 px cells, each a rounded dome
                       that falls away into deep borders (ratio about 0.7-1.3)
  <name>_n.png         tangent-space normal map (OpenGL, +Y up), built with
                       make_grain.normal_map so the relief matches the cloth grains
Grain is a LINEAR ratio stored as ratio * GRAIN_MEAN (0.25): the shader's
leather_color * grain / grain_mean is the leather. Every PNG gets a Godot .import
(lossless, no sRGB, mipmaps, detect_3d off). Seamless by construction: the cell
lattice and the mottle both wrap on a torus, so no half-offset blend is needed.
Contact sheet IMPORT/cloth_refs/leather_grain_procedural.png: each grain tiled 2x2
at a mid-grey mean on top (seams would show), its normal map below.

Run from the repo root:  python tools/cloth_refs/make_leather_grain.py
"""

import hashlib
import os
import sys

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True  # don't churn make_grain's tracked __pycache__
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_grain import gaussian_wrap, normal_map, to_u8  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "textures", "grain")
OUT_RES = "res://assets/textures/grain"
CONTACT = os.path.join(ROOT, "IMPORT", "cloth_refs", "leather_grain_procedural.png")
GRAIN_TEMPLATE = os.path.join(ROOT, "assets", "textures", "fabrics", "worsted.png.import")
NORMAL_TEMPLATE = os.path.join(ROOT, "assets", "textures", "fabrics", "worsted_n.png.import")

TILE = 512
GRAIN_MEAN = 0.25  # must match make_grain.py and the shader
CELL = 256


def worley(cells, seed):
    """F1 and F2 distances (in cell units) to jittered points on a cells x cells
    lattice that wraps, sampled at TILE x TILE pixels. Seamless on the torus."""
    rng = np.random.default_rng(seed)
    jitter = rng.random((cells, cells, 2))
    coord = (np.arange(TILE) + 0.5) * cells / TILE
    py, px = np.meshgrid(coord, coord, indexing="ij")
    iy = np.floor(py).astype(int)
    ix = np.floor(px).astype(int)
    f1 = np.full((TILE, TILE), np.inf)
    f2 = np.full((TILE, TILE), np.inf)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cy = iy + dy
            cx = ix + dx
            j = jitter[cy % cells, cx % cells]
            d = np.hypot(cy + j[..., 0] - py, cx + j[..., 1] - px)
            f2 = np.where(d < f1, f1, np.minimum(f2, d))
            f1 = np.minimum(f1, d)
    return f1, f2


def mottle(sigma, seed):
    """Large-scale soft noise with wraparound, normalised to mean 0, peak 1."""
    rng = np.random.default_rng(seed)
    m = gaussian_wrap(rng.standard_normal((TILE, TILE)), sigma)
    m -= m.mean()
    return m / np.abs(m).max()


def fit_range(field, lo, hi):
    """Map a field to a ratio with mean 1 whose extremes sit near lo and hi."""
    f = field - field.mean()
    span = max(f.max(), -f.min())
    return 1.0 + f / span * (hi - lo) * 0.5


def calf():
    f1, f2 = worley(TILE * 2 // 7, 11)  # 146 cells: ~3.5 px each
    edge = f2 - f1  # 0 on a border, rising into the cell
    crease = np.exp(-edge / 0.18)  # soft dark line along each border
    field = -crease + 0.35 * mottle(40.0, 12)
    return fit_range(field, 0.85, 1.15)


def pebble():
    f1, f2 = worley(30, 21)  # 30 cells: ~17 px each
    edge = np.clip((f2 - f1) / 0.9, 0.0, 1.0)
    dome = 1.0 - (1.0 - edge) ** 2  # rounded top, steep fall into the border
    groove = np.exp(-(f2 - f1) / 0.07)  # the deep crease between pebbles
    field = dome - 0.35 * groove + 0.12 * mottle(60.0, 22)
    return fit_range(field, 0.7, 1.3)


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


def write_pair(name, ratio):
    """<name>.png (grey grain, ratio * GRAIN_MEAN) + <name>_n.png from the same field."""
    rgb = np.repeat(ratio[..., None], 3, axis=-1)
    to_u8(rgb * GRAIN_MEAN).save(os.path.join(OUT_DIR, name + ".png"))
    # Height in make_grain's convention: the ratio at a mean of 0.5.
    to_u8(normal_map(np.clip(rgb * 0.5, 0.0, 1.0))).save(os.path.join(OUT_DIR, name + "_n.png"))
    write_import(name + ".png", GRAIN_TEMPLATE)
    write_import(name + "_n.png", NORMAL_TEMPLATE)
    print("%-16s ratio %.3f-%.3f  mean %.3f" % (name, ratio.min(), ratio.max(), ratio.mean()))


def contact_sheet(names):
    sheet = Image.new("RGB", (CELL * len(names), CELL * 2))
    for i, name in enumerate(names):
        grain = Image.open(os.path.join(OUT_DIR, name + ".png")).convert("RGB")
        a = np.asarray(grain).astype(np.float64) / 255.0 / GRAIN_MEAN * 0.5
        a = np.tile(np.clip(a, 0.0, 1.0), (2, 2, 1))
        sheet.paste(to_u8(a).resize((CELL, CELL), Image.LANCZOS), (i * CELL, 0))
        normal = Image.open(os.path.join(OUT_DIR, name + "_n.png")).convert("RGB")
        sheet.paste(normal.resize((CELL, CELL), Image.LANCZOS), (i * CELL, CELL))
    os.makedirs(os.path.dirname(CONTACT), exist_ok=True)
    sheet.save(CONTACT)
    print("wrote", CONTACT)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_pair("leather_calf", calf())
    write_pair("leather_pebble", pebble())
    contact_sheet(["leather_calf", "leather_pebble"])


if __name__ == "__main__":
    main()
