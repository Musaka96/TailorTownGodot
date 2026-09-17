"""Turn the generated stage-curtain art into the textures ui/loading_curtain.gd loads.

The three source PNGs are made from the prompts in docs/UI_STYLE_GUIDE.md and dropped in
IMPORT/curtain (git-ignored) on a flat green background, because image models will not give
reliable transparency. This keys the green out, crops each one to its artwork, and makes the
braid and the pelmet tile - the braid down its length, the pelmet across the screen - by
cropping to a whole number of repeats (found by autocorrelation) and fading the wrap seam.

It prints the panel's hem share, which must match ART_HEM_SHARE in the curtain script.

  IMPORT/curtain/1curtain.png -> assets/textures/ui/curtain_panel.png
  IMPORT/curtain/2curtain.png -> assets/textures/ui/curtain_trim.png
  IMPORT/curtain/3curtain.png -> assets/textures/ui/curtain_valance.png

Run from the project root (needs pillow + numpy), then reimport in Godot:
  python tools/prep_curtain_art.py
"""
import numpy as np
from PIL import Image

SRC = "IMPORT/curtain/"
OUT = "assets/textures/ui/"
LO, HI = 10.0, 60.0  # green-dominance where alpha starts / finishes falling off


def keyed(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    other = np.maximum(r, b)
    dom = g - other
    alpha = np.clip(1.0 - (dom - LO) / (HI - LO), 0.0, 1.0)
    rgb[..., 1] = np.minimum(g, other)  # despill the green fringe
    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    return out


def bbox(img, thresh=16):
    a = img[..., 3]
    rows = np.where(a.max(axis=1) > thresh)[0]
    cols = np.where(a.max(axis=0) > thresh)[0]
    return rows[0], rows[-1] + 1, cols[0], cols[-1] + 1


def period(signal, lo, hi):
    """Best repeat length of a 1-D signal, by normalised autocorrelation."""
    s = signal - signal.mean()
    best, best_score = lo, -2.0
    for p in range(lo, hi):
        a, b = s[:-p], s[p:]
        denom = np.linalg.norm(a) * np.linalg.norm(b)
        if denom == 0:
            continue
        score = float(np.dot(a, b) / denom)
        if score > best_score:
            best, best_score = p, score
    return best, best_score


def seam_blend(img, axis, n, overlap):
    """Crop to `n` along `axis` and fade the wrapped tail in, so copies join cleanly."""
    img = np.moveaxis(img, axis, 0).astype(np.float32)
    out = img[:n].copy()
    tail = img[n:n + overlap]
    w = np.linspace(1.0, 0.0, len(tail))[:, None, None]
    out[:len(tail)] = tail * w + out[:len(tail)] * (1.0 - w)
    return np.moveaxis(out.astype(np.uint8), 0, axis)


# --- panel ------------------------------------------------------------------
p = keyed(SRC + "1curtain.png")
t, bm, l, r = bbox(p)
p = p[t:bm, l:r]
h, w = p.shape[:2]
solid = (p[..., 3] > 200).sum(axis=1)
full = np.where(solid >= w * 0.995)[0]
hem_share = (h - (full[-1] + 1)) / h
print("panel   %dx%d  (cropped %d,%d,%d,%d)  hem share %.3f" % (w, h, t, bm, l, r, hem_share))
Image.fromarray(p).save(OUT + "curtain_panel.png")

# --- trim -------------------------------------------------------------------
tr = keyed(SRC + "2curtain.png")
t, bm, l, r = bbox(tr)
tr = tr[t:bm, l:r]
h, w = tr.shape[:2]
lum = tr[..., :3].astype(np.float32).mean(axis=(1, 2))
per, score = period(lum, 24, h // 3)
tiles = max(1, (h - per) // per)
n = tiles * per
tr = seam_blend(tr, 0, n, max(4, per // 6))
scale = 64.0 / tr.shape[1]
img = Image.fromarray(tr).resize((64, max(1, int(round(tr.shape[0] * scale)))), Image.LANCZOS)
print("trim    %dx%d -> %s  period %d (r=%.3f) x%d" % (w, h, img.size, per, score, tiles))
img.save(OUT + "curtain_trim.png")

# --- valance ----------------------------------------------------------------
v = keyed(SRC + "3curtain.png")
t, bm, l, r = bbox(v)
v = v[t:bm, l:r]
h, w = v.shape[:2]
hang = (v[..., 3] > 128).sum(axis=0).astype(np.float32)  # how far the swag hangs per column
per, score = period(hang, 80, w // 2)
tiles = max(1, (w - per) // per)
n = tiles * per
v = seam_blend(v, 1, n, max(8, per // 8))
print("valance %dx%d -> %dx%d  period %d (r=%.3f) x%d" % (w, h, v.shape[1], v.shape[0], per, score, tiles))
Image.fromarray(v).save(OUT + "curtain_valance.png")
