"""Cut the scanned cloth-swatch reference sheets into neutral grain + normal tiles.

Experiment only (scenes/dev/cloth_refs.tscn). Reads the reference sheets in
IMPORT/cloth_refs/ (see SHEETS): the cloth scans have a 3x5 grid of swatches on a
black lid, found by thresholding it; the environment sheets (street, interior) are a
fixed grid of cells butting edge to edge, cut into equal cells. Writes for every
swatch, in assets/dev/cloth_refs/:
  <sheet>_<n>.png          raw grain: the crop, one tile = one swatch (no wrap blend)
  <sheet>_<n>_n.png        its tangent-space normal map (OpenGL, +Y up)
  <sheet>_<n>_tile.png     seamless grain (half-offset blend), for repeating use
  <sheet>_<n>_tile_n.png   its normal map
Grain is LINEAR light: ratio = crop_linear / mean_linear per channel, stored as
ratio * GRAIN_MEAN (0.25, so 4x headroom before clipping). Sheets with "flatten"
divide by a wide blur (sigma = side / 6) instead of the mean, so the photo's
lighting gradient drops out; tall/wide cells are cut to their centred square. The shader's
cloth_color (source_color, sRGB -> linear) times grain / grain_mean rebuilds the
crop. refs.json has each swatch's mean colour (sRGB hex of the linear mean) and
the sheet's grid layout (cell aspect, gap, framing). Every PNG gets a Godot
.import (lossless, mipmaps, no VRAM compression). Contact sheets
IMPORT/cloth_refs/crops_<sheet>.png show crop | rebuilt raw | rebuilt tile, and
IMPORT/cloth_refs/env_grain_preview.png shows each environment tile repeated 2x2.

Run from the repo root:  python tools/cloth_refs/make_grain.py [sheet ...]
"""

import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(ROOT, "IMPORT", "cloth_refs")
OUT_DIR = os.path.join(ROOT, "assets", "dev", "cloth_refs")
OUT_RES = "res://assets/dev/cloth_refs"
GRAIN_TEMPLATE = os.path.join(ROOT, "assets", "textures", "fabrics", "worsted.png.import")
NORMAL_TEMPLATE = os.path.join(ROOT, "assets", "textures", "fabrics", "worsted_n.png.import")

# Per-sheet config. No "grid": the scan's swatches sit on a black lid and are found by
# thresholding it (find_squares). "grid": (cols, rows) means the cells butt edge to edge
# and the squares are simply the image cut into equal cells (grid_squares).
# "flatten": divide by a wide blur instead of the mean (photos with a lighting gradient).
SHEETS = {
    "suitings": {},
    "shirtings": {},
    "street": {"grid": (5, 3), "flatten": True},
    "interior": {"grid": (5, 3), "flatten": True},
}
LID_LUMA = 40.0  # below this a pixel is scanner lid
SPAN_FILL = 0.15  # a column/row is "cloth" when more than this fraction is non-lid
INSET = 0.05  # drop the pinked edge (lid sheets) / the seam bleed between cells (grid sheets)
SQUARE_ASPECT = (0.9, 1.1)  # sheet cells outside this w/h are cut to their largest centred square
FLATTEN_DIV = 6.0  # flatten blur sigma = crop side / this
TILE = 512
GRAIN_MEAN = 0.25  # stored mean of the linear grain ratio (must match the shader)
BLUR_SIGMA = 6.0
NORMAL_K = 4.0
CONTACT_CELL = 192
PREVIEW_TILE = 256  # env_grain_preview.png: each seamless tile at this size, repeated 2x2
PREVIEW_SHEETS = ["street", "interior"]


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1.0 / 2.4) - 0.055)


def spans(profile, count):
    """The `count` widest runs where profile > SPAN_FILL, in position order."""
    on = profile > SPAN_FILL
    runs = []
    start = None
    for i, v in enumerate(on):
        if v and start is None:
            start = i
        elif not v and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(on)))
    runs.sort(key=lambda r: r[1] - r[0], reverse=True)
    runs = runs[:count]
    if len(runs) != count:
        raise RuntimeError("found %d spans, wanted %d" % (len(runs), count))
    return sorted(runs)


def find_squares(rgb):
    cloth = luma(rgb) >= LID_LUMA
    cols = spans(cloth.mean(axis=0), 5)
    rows = spans(cloth.mean(axis=1), 3)
    boxes = []
    for r0, r1 in rows:
        for c0, c1 in cols:
            dy = int(round((r1 - r0) * INSET))
            dx = int(round((c1 - c0) * INSET))
            boxes.append((c0 + dx, r0 + dy, c1 - dx, r1 - dy))
    return boxes, cols, rows


def grid_squares(width, height, n_cols, n_rows):
    """Equal cells over the whole image (no lid between them), each inset by INSET."""
    xs = [int(round(width * k / n_cols)) for k in range(n_cols + 1)]
    ys = [int(round(height * k / n_rows)) for k in range(n_rows + 1)]
    cols = list(zip(xs[:-1], xs[1:]))
    rows = list(zip(ys[:-1], ys[1:]))
    boxes = []
    for r0, r1 in rows:
        for c0, c1 in cols:
            dy = int(round((r1 - r0) * INSET))
            dx = int(round((c1 - c0) * INSET))
            boxes.append((c0 + dx, r0 + dy, c1 - dx, r1 - dy))
    return boxes, cols, rows


def square_box(box):
    """The largest centred square of `box`, so a tall/wide cell isn't stretched onto
    the square tile (used when the sheet's cells are outside SQUARE_ASPECT)."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    side = min(w, h)
    sx = x0 + (w - side) // 2
    sy = y0 + (h - side) // 2
    return (sx, sy, sx + side, sy + side)


def blur_reflect(a, sigma):
    """Gaussian blur of an HxWxC array with reflect padding (FFT on the padded array)."""
    pad = int(np.ceil(3.0 * sigma))
    p = np.pad(a, ((pad, pad), (pad, pad), (0, 0)), mode="reflect")
    out = np.stack([gaussian_wrap(p[..., c], sigma) for c in range(a.shape[-1])], axis=-1)
    return out[pad:pad + a.shape[0], pad:pad + a.shape[1]]


def layout(cols, rows, width, height, gap):
    """Grid shape and framing of the scan, for the scene to copy."""
    cell_w = float(np.mean([c1 - c0 for c0, c1 in cols]))
    cell_h = float(np.mean([r1 - r0 for r0, r1 in rows]))
    grid_w = cols[-1][1] - cols[0][0]
    grid_h = rows[-1][1] - rows[0][0]
    return {
        "cell_aspect": round(cell_w / cell_h, 4),
        "gap": gap,  # of the cell height
        "sheet_aspect": round(width / height, 4),
        "fill_h": round(grid_h / height, 4),  # grid height / sheet height
        # grid centre offset from the sheet centre, in sheet heights (+x right, +y down)
        "offset_x": round(((cols[0][0] + cols[-1][1]) * 0.5 - width * 0.5) / height, 4),
        "offset_y": round(((rows[0][0] + rows[-1][1]) * 0.5 - height * 0.5) / height, 4),
        "grid_px": [grid_w, grid_h],
    }


def triangle(n):
    """1 at the centre, 0 at both edges."""
    x = (np.arange(n) + 0.5) / n
    return 1.0 - np.abs(x - 0.5) * 2.0


def make_seamless(img):
    shifted = np.roll(img, (TILE // 2, TILE // 2), axis=(0, 1))
    w = np.outer(triangle(TILE), triangle(TILE))[..., None]
    return img * w + shifted * (1.0 - w)


def resize_float(a, size):
    """Lanczos resize of a float HxWxC array, channel by channel."""
    chans = [
        np.asarray(Image.fromarray(a[..., c].astype(np.float32), "F").resize(size, Image.LANCZOS))
        for c in range(a.shape[-1])
    ]
    return np.stack(chans, axis=-1).astype(np.float64)


def gaussian_wrap(h, sigma):
    """Gaussian blur with wraparound, via FFT."""
    fy = np.fft.fftfreq(h.shape[0])[:, None]
    fx = np.fft.fftfreq(h.shape[1])[None, :]
    kernel = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(h) * kernel))


def normal_map(height_rgb):
    """Normal map from a mean-0.5 sRGB-domain grain (same relief scale as round 1)."""
    h = luma(height_rgb)
    h = h - gaussian_wrap(h, BLUR_SIGMA)

    def at(dy, dx):
        # value of the neighbour at (row + dy, col + dx), wrapping
        return np.roll(h, (-dy, -dx), axis=(0, 1))

    # Sobel, normalised by 8 so it is a per-pixel slope.
    d_col = (
        at(-1, 1) + 2.0 * at(0, 1) + at(1, 1) - at(-1, -1) - 2.0 * at(0, -1) - at(1, -1)
    ) / 8.0
    d_row = (
        at(1, -1) + 2.0 * at(1, 0) + at(1, 1) - at(-1, -1) - 2.0 * at(-1, 0) - at(-1, 1)
    ) / 8.0
    dx = d_col
    dy = -d_row  # image rows run down; +Y is up (OpenGL)
    n = np.stack([-dx * NORMAL_K, -dy * NORMAL_K, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def to_u8(a):
    return Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGB")


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


def grain_pair(ratio, height, name, clips):
    """Write <name>.png (grain) + <name>_n.png; ratio has per-channel mean 1.

    `height` is the sRGB-domain grain (mean 0.5) the normal map is built from, so the
    relief keeps the round-1 scale instead of the stronger linear-light contrast."""
    grain = ratio * GRAIN_MEAN
    clips.append(float((grain > 1.0).any(axis=-1).mean()))
    to_u8(grain).save(os.path.join(OUT_DIR, name + ".png"))
    to_u8(normal_map(np.clip(height, 0.0, 1.0))).save(
        os.path.join(OUT_DIR, name + "_n.png")
    )
    write_import(name + ".png", GRAIN_TEMPLATE)
    write_import(name + "_n.png", NORMAL_TEMPLATE)
    return np.clip(grain, 0.0, 1.0) / GRAIN_MEAN


def process_sheet(sheet, cfg):
    """Cut one sheet; returns (refs entries, layout, rebuilt sRGB colour tiles)."""
    src = os.path.join(SRC_DIR, "S_sheet_%s.webp" % sheet)
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float64) / 255.0
    if "grid" in cfg:
        n_cols, n_rows = cfg["grid"]
        boxes, cols, rows = grid_squares(rgb.shape[1], rgb.shape[0], n_cols, n_rows)
        gap = 0.0  # cells butt edge to edge
    else:
        n_cols, n_rows = 5, 3
        boxes, cols, rows = find_squares(rgb * 255.0)
        gap = 0.015  # the scan's lid gaps are ~1-2% of the cell height
    lay = layout(cols, rows, rgb.shape[1], rgb.shape[0], gap)
    # Decided per sheet (mean inset-cell aspect) so a 1 px rounding difference between
    # rows can't square some cells and stretch others.
    aspect = float(np.mean([(x1 - x0) / (y1 - y0) for x0, y0, x1, y1 in boxes]))
    if not SQUARE_ASPECT[0] <= aspect <= SQUARE_ASPECT[1]:
        boxes = [square_box(b) for b in boxes]
        sides = [x1 - x0 for x0, y0, x1, y1 in boxes]
        lay["crop_px"] = int(round(float(np.mean(sides))))  # side of the square crops
    flatten = cfg.get("flatten", False)
    print("%s: columns %s rows %s" % (sheet, cols, rows))
    print("  layout %s  flatten %s" % (lay, flatten))
    entries = []
    tiles = []
    contact = Image.new("RGB", (CONTACT_CELL * 3 * n_cols, CONTACT_CELL * n_rows))
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        n = i + 1
        crop = rgb[y0:y1, x0:x1]
        lin = srgb_to_linear(crop)
        mean_lin = lin.reshape(-1, 3).mean(axis=0)  # the dye: plain linear mean
        mean_srgb = linear_to_srgb(mean_lin)
        hex_col = "#%02x%02x%02x" % tuple(int(round(c * 255.0)) for c in mean_srgb)

        if flatten:
            # Divide by a wide blur instead of the mean, so the photo's lighting
            # gradient / vignette drops out before the half-offset blend.
            sigma = (x1 - x0) / FLATTEN_DIV
            ratio = lin / np.maximum(blur_reflect(lin, sigma), 1e-6)
            raw = np.maximum(resize_float(ratio, (TILE, TILE)), 0.0)
            h_src = crop / np.maximum(blur_reflect(crop, sigma), 1e-6)
        else:
            big = np.maximum(resize_float(lin, (TILE, TILE)), 0.0)
            raw = big / np.maximum(mean_lin, 1e-6)
            h_src = crop
        raw = raw / raw.reshape(-1, 3).mean(axis=0)
        tiled = make_seamless(raw)
        tiled = tiled / tiled.reshape(-1, 3).mean(axis=0)
        mean_s = h_src.reshape(-1, 3).mean(axis=0)
        h_raw = resize_float(h_src, (TILE, TILE)) / mean_s * 0.5
        h_tile = make_seamless(h_raw)
        h_tile = h_tile / h_tile.reshape(-1, 3).mean(axis=0) * 0.5

        name = "%s_%d" % (sheet, n)
        clips = []
        raw_kept = grain_pair(raw, h_raw, name, clips)
        tile_kept = grain_pair(tiled, h_tile, name + "_tile", clips)
        entries.append({"n": n, "color": hex_col})
        print("  %-12s %s  crop %dx%d  clipped raw %.2f%%  tile %.2f%%" % (
            name, hex_col, x1 - x0, y1 - y0, clips[0] * 100.0, clips[1] * 100.0))

        cx = (i % n_cols) * 3 * CONTACT_CELL
        cy = (i // n_cols) * CONTACT_CELL
        cell = (CONTACT_CELL, CONTACT_CELL)
        crop_img = to_u8(rgb[y0:y1, x0:x1])
        contact.paste(crop_img.resize(cell, Image.LANCZOS), (cx, cy))
        for k, kept in enumerate([raw_kept, tile_kept]):
            rebuilt = to_u8(linear_to_srgb(kept * mean_lin))
            contact.paste(rebuilt.resize(cell, Image.LANCZOS), (cx + (k + 1) * CONTACT_CELL, cy))
            if k == 1:
                tiles.append(rebuilt)
    contact.save(os.path.join(SRC_DIR, "crops_%s.png" % sheet))
    return entries, lay, tiles


def write_preview(all_tiles):
    """IMPORT/cloth_refs/env_grain_preview.png: one row per sheet, each seamless colour
    tile repeated 2x2, so a seam or a doubled feature shows at a glance."""
    sheets = [s for s in PREVIEW_SHEETS if s in all_tiles]
    if not sheets:
        return
    cell = PREVIEW_TILE * 2
    pad = 8
    width = max(len(all_tiles[s]) for s in sheets) * (cell + pad) + pad
    preview = Image.new("RGB", (width, len(sheets) * (cell + pad) + pad), (24, 24, 24))
    for r, sheet in enumerate(sheets):
        for c, tile in enumerate(all_tiles[sheet]):
            small = tile.resize((PREVIEW_TILE, PREVIEW_TILE), Image.LANCZOS)
            x = pad + c * (cell + pad)
            y = pad + r * (cell + pad)
            for oy in (0, PREVIEW_TILE):
                for ox in (0, PREVIEW_TILE):
                    preview.paste(small, (x + ox, y + oy))
    path = os.path.join(SRC_DIR, "env_grain_preview.png")
    preview.save(path)
    print("wrote", path)


def main():
    """python make_grain.py [sheet ...]; no names = every sheet. refs.json is merged,
    so re-cutting some sheets keeps the others' entries."""
    os.makedirs(OUT_DIR, exist_ok=True)
    names = sys.argv[1:] or list(SHEETS)
    for name in names:
        if name not in SHEETS:
            raise SystemExit("unknown sheet %r (have %s)" % (name, ", ".join(SHEETS)))
    refs_path = os.path.join(OUT_DIR, "refs.json")
    refs = {"layout": {}}
    if os.path.exists(refs_path):
        with open(refs_path, "r", encoding="utf-8") as f:
            refs = json.load(f)
        refs.setdefault("layout", {})
    all_tiles = {}
    for sheet in names:
        refs[sheet], refs["layout"][sheet], all_tiles[sheet] = process_sheet(sheet, SHEETS[sheet])
    with open(refs_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(refs, f, indent=1)
        f.write("\n")
    print("wrote", refs_path)
    write_preview(all_tiles)


if __name__ == "__main__":
    main()
