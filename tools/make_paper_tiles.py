"""Slice the owner's 2 x 2 paper sheet (GPT Image, green gutters) into four tiling world
papers for assets/shaders/paper_world.gdshader, each an albedo plus an OpenGL normal map.

    python tools/make_paper_tiles.py [sheet.jpg]

Per quadrant: crop inside the gutter glow, even out the light (divide by a wide blur, so a
lit-from-one-side band does not repeat across a wall), make it tile (cross-fade with its
half-offset copy, which is continuous across the wrap), resize to SIZE. The normal comes
from the luminance as a height, high-passed at HP_SIGMA px, slope x STRENGTH (the same
recipe as the mache_gpt and piece_paper normals). Writes assets/textures/paper/world_*.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "IMPORT/papers.jpeg"  # the owner's 4096 px sheet
OUT = ROOT / "assets/textures/paper"
SIZE = 2048  # the build caps textures at 2048
# how far the green gutters' glow reaches past the solid green, and the sheet's own edge
# (px per 1000 px of sheet); the gutters themselves are found in the image
GLOW = 13.0
EDGE = 3.0
# name, quadrant (col, row), light evening blur (fraction of the tile), normal strength,
# how it is made to tile: "fade" (cross-fade) or "mirror" (2 x 2 mirrored: straight folds
# would break at a cross-fade, mirrored they run on), extra crop past the gutter glow
TILES = [
    ("world_crumple", (0, 0), 0.18, 5.0, "fade", 0, 2.0),
    ("world_kraft", (1, 0), 0.12, 4.0, "fade", 0, 5.0),
    ("world_folded", (0, 1), 0.25, 6.0, "mirror", 14, 3.0),
    ("world_coated", (1, 1), 0.15, 6.0, "fade", 0, 6.0),
]
# the last field: how much of the paper's fine tooth is smoothed away (px per 1024, in
# the relief and, at half, in the colour). On a bin or a door seen from the gameplay
# camera the tooth reads as felt, so the coated and kraft papers keep only their shapes.
HP_SIGMA = 36.0
TOOTH_BLUR = 2.0
FADE = 0.22  # the seam cross-fade, fraction of the tile from each edge


def gutters(img: np.ndarray) -> tuple:
    """The solid green gutters: (first, last) column, (first, last) row."""
    g = (img[..., 1] > 0.8) & (img[..., 0] < 0.47) & (img[..., 2] < 0.47)
    cols = np.nonzero(g.mean(0) > 0.5)[0]
    rows = np.nonzero(g.mean(1) > 0.5)[0]
    return (cols[0], cols[-1]), (rows[0], rows[-1])


def crop(img: np.ndarray, col: int, row: int, extra: int, gut: tuple) -> np.ndarray:
    n = img.shape[0]
    k = n / 1000.0
    glow = round(GLOW * k)
    edge = round(EDGE * k)
    extra = round(extra * k / 2.0)
    (c0, c1), (r0, r1) = gut
    x0 = edge if col == 0 else c1 + glow
    x1 = c0 - glow if col == 0 else n - edge
    y0 = edge if row == 0 else r1 + glow
    y1 = r0 - glow if row == 0 else n - edge
    x0, y0, x1, y1 = x0 + extra, y0 + extra, x1 - extra, y1 - extra
    s = min(x1 - x0, y1 - y0)
    return img[y0 : y0 + s, x0 : x0 + s]


def mirror_tile(a: np.ndarray) -> np.ndarray:
    top = np.concatenate([a, a[:, ::-1]], axis=1)
    return np.concatenate([top, top[::-1]], axis=0)


def even_light(rgb: np.ndarray, frac: float) -> np.ndarray:
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    sigma = frac * rgb.shape[0]
    low = ndimage.gaussian_filter(lum, sigma, mode="wrap")
    return np.clip(rgb * (lum.mean() / np.maximum(low, 1e-3))[..., None], 0.0, 1.0)


def make_tile(a: np.ndarray) -> np.ndarray:
    n = a.shape[0]
    shifted = np.roll(a, (n // 2, n // 2), axis=(0, 1))
    t = np.minimum(np.arange(n), np.arange(n)[::-1]) / (FADE * n)
    w1 = np.clip(t, 0.0, 1.0)
    w1 = w1 * w1 * (3 - 2 * w1)
    w = np.outer(w1, w1)
    if a.ndim == 3:
        w = w[..., None]
    return a * w + shifted * (1 - w)


def normal_map(rgb: np.ndarray, strength: float, tooth: float = TOOTH_BLUR) -> np.ndarray:
    h = rgb @ np.array([0.299, 0.587, 0.114])
    h = h - ndimage.gaussian_filter(h, HP_SIGMA * rgb.shape[0] / 1024.0, mode="wrap")
    # the paper's fine tooth off: from a room away it only sparkles
    h = ndimage.gaussian_filter(h, tooth * rgb.shape[0] / 1024.0, mode="wrap")
    # slope per 1/1024 of the tile, so the relief is the same at any output size
    k = rgb.shape[0] / 1024.0
    dx = ndimage.sobel(h, axis=1, mode="wrap") / 8.0 * k
    dy = ndimage.sobel(h, axis=0, mode="wrap") / 8.0 * k
    # OpenGL: green points up the image, so a height rising down the image tilts it up
    n = np.dstack([-dx * strength * 255.0 / 32.0, dy * strength * 255.0 / 32.0, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


# Cardboard for the walls and the roof (not on the owner's sheet): the ambientCG
# Cardboard002 scan's mottling, the flutes of the corrugation showing through the liner
# (FLUTES per tile, a faint stripe in the colour and a clear ripple in the relief) and the
# crumpled sheet's creases, much softer, so it looks handled.
CARDBOARD_SCAN = ROOT / "assets/textures/paper/cardboard002_albedo.jpg"
FLUTES = 28
FLUTE_TONE = 0.05
FLUTE_RELIEF = 0.6
CARDBOARD_CREASE = 0.35


def make_cardboard(crumple: np.ndarray) -> None:
    scan = Image.open(CARDBOARD_SCAN).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    a = even_light(np.asarray(scan).astype(np.float64) / 255.0, 0.2)
    x = np.arange(SIZE) / SIZE
    flute = 0.5 + 0.5 * np.cos(2.0 * np.pi * FLUTES * x)
    flute = np.tile(flute, (SIZE, 1))
    a = np.clip(a * (1.0 - FLUTE_TONE * flute)[..., None], 0.0, 1.0)
    im = Image.fromarray((a * 255).round().astype(np.uint8))
    im.save(OUT / "world_cardboard_albedo.jpg", quality=92)
    # the relief: flutes plus the crumple's high-passed light, as one height
    lum = crumple @ np.array([0.299, 0.587, 0.114])
    lum = lum - ndimage.gaussian_filter(lum, HP_SIGMA * SIZE / 1024.0, mode="wrap")
    h = FLUTE_RELIEF * 0.08 * flute + CARDBOARD_CREASE * lum
    n = normal_map(np.dstack([h, h, h]) + 0.5, 5.0)
    Image.fromarray((n * 255).round().astype(np.uint8)).save(OUT / "world_cardboard_normal.jpg", quality=92)
    rep = np.tile(np.asarray(im), (2, 2, 1))
    Image.fromarray(rep).resize((1024, 1024)).save(ROOT / "IMPORT/paper_world/src/world_cardboard_repeat.png")
    print("world_cardboard ok")


def main() -> None:
    sheet = Path(sys.argv[1]) if len(sys.argv) > 1 else SHEET
    img = np.asarray(Image.open(sheet).convert("RGB")).astype(np.float64) / 255.0
    gut = gutters(img)
    print("gutters", gut)
    for name, (col, row), frac, strength, mode, extra, tooth in TILES:
        a = even_light(crop(img, col, row, extra, gut), frac)
        a = mirror_tile(a) if mode == "mirror" else make_tile(a)
        im = Image.fromarray((a * 255).round().astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS)
        a = np.asarray(im).astype(np.float64) / 255.0
        n = normal_map(a, strength, tooth)
        soft = tooth * 0.5 * SIZE / 1024.0
        a = np.dstack([ndimage.gaussian_filter(a[..., c], soft, mode="wrap") for c in range(3)])
        im = Image.fromarray((np.clip(a, 0, 1) * 255).round().astype(np.uint8))
        im.save(OUT / f"{name}_albedo.jpg", quality=92)
        Image.fromarray((n * 255).round().astype(np.uint8)).save(OUT / f"{name}_normal.jpg", quality=92)
        # a 2 x 2 repeat, to check the seams by eye
        rep = np.tile(np.asarray(im), (2, 2, 1))
        Image.fromarray(rep).resize((1024, 1024)).save(ROOT / f"IMPORT/paper_world/src/{name}_repeat.png")
        print(name, "ok")
        if name == "world_crumple":
            crumple = a
    make_cardboard(crumple)


if __name__ == "__main__":
    main()
