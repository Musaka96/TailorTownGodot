"""Measure how many motif repeats a game pattern tile holds across its width.

Experiment helper for scenes/dev/cloth_refs (mode=game). Autocorrelates the R channel
(accent coverage) of assets/textures/patterns/<name>.png along x, averaged over rows,
and takes the strongest peak after the zero-lag lobe as the horizontal period.

Run from the repo root:  python tools/cloth_refs/tile_period.py
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PATTERNS = ["pinstripe", "herringbone", "houndstooth", "windowpane"]


def period_x(r):
    """Horizontal period in px of a wrapping tile, by circular autocorrelation."""
    r = r - r.mean()
    spec = np.fft.fft(r, axis=1)
    ac = np.real(np.fft.ifft(spec * np.conj(spec), axis=1)).mean(axis=0)
    ac /= ac[0]
    w = r.shape[1]
    # skip the zero-lag lobe: start after the first dip below zero
    start = 1
    while start < w // 2 and ac[start] > 0.0:
        start += 1
    lag = start + int(np.argmax(ac[start : w // 2 + 1]))
    return lag, float(ac[lag])


def main():
    for name in PATTERNS:
        path = os.path.join(ROOT, "assets", "textures", "patterns", name + ".png")
        img = np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255.0
        lag, strength = period_x(img[..., 0])
        w = img.shape[1]
        print("%-12s %dpx tile  period %3d px  -> %.2f motifs across  (ac %.2f)" % (
            name, w, lag, w / lag, strength))


if __name__ == "__main__":
    main()
