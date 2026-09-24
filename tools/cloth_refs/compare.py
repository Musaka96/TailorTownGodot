"""Line cloth_refs renders up with the scanned sheets: measure, and build compare images.

Experiment helper for scenes/dev/cloth_refs. The scene frames the grid like the scan
(sheet aspect, centred in the viewport), so cropping the render to the sheet's aspect
and scaling it to the sheet's size puts every swatch on the same pixels as the scan.

  python tools/cloth_refs/compare.py measure <render.png> <sheet> [n ...]
      mean luma (0-255, sRGB) of scan vs render over each swatch's inset crop box
  python tools/cloth_refs/compare.py compose
      IMPORT/cloth_refs/compare_suitings.png  = scan / direct / game / direct flat=1
      IMPORT/cloth_refs/compare_shirtings.png = scan / direct
      (renders read from .dev/refs_<sheet>_<mode>.png)
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_grain as mg  # noqa: E402

ROOT = mg.ROOT
GAP = 12


def scan_path(sheet):
    return os.path.join(mg.SRC_DIR, "S_sheet_%s.webp" % sheet)


def aligned(render_path, size):
    """The render cropped to the sheet's aspect (centred) and scaled to `size`."""
    im = Image.open(render_path).convert("RGB")
    want = size[0] / size[1]
    w, h = im.size
    if w / h > want:
        cw = round(h * want)
        box = ((w - cw) // 2, 0, (w - cw) // 2 + cw, h)
    else:
        ch = round(w / want)
        box = (0, (h - ch) // 2, w, (h - ch) // 2 + ch)
    return im.crop(box).resize(size, Image.LANCZOS)


def measure(render_path, sheet, squares):
    scan = Image.open(scan_path(sheet)).convert("RGB")
    s = np.asarray(scan).astype(np.float64)
    r = np.asarray(aligned(render_path, scan.size)).astype(np.float64)
    boxes, _, _ = mg.find_squares(s)
    print("%s vs %s" % (os.path.basename(render_path), sheet))
    print("   n   scan  render  ratio")
    for n in squares:
        x0, y0, x1, y1 = boxes[n - 1]
        a = mg.luma(s[y0:y1, x0:x1]).mean()
        b = mg.luma(r[y0:y1, x0:x1]).mean()
        print("  %2d  %5.1f  %6.1f  %5.3f" % (n, a, b, b / a))


def stack(images, out):
    h = sum(i.height for i in images) + GAP * (len(images) - 1)
    canvas = Image.new("RGB", (images[0].width, h), (0, 0, 0))
    y = 0
    for i in images:
        canvas.paste(i, (0, y))
        y += i.height + GAP
    canvas.save(out)
    print(out, canvas.size)


def compose():
    dev = os.path.join(ROOT, ".dev")
    rows = {
        "suitings": ["direct", "game", "direct_flat"],
        "shirtings": ["direct"],
    }
    for sheet, modes in rows.items():
        scan = Image.open(scan_path(sheet)).convert("RGB")
        images = [scan]
        for mode in modes:
            path = os.path.join(dev, "refs_%s_%s.png" % (sheet, mode))
            images.append(aligned(path, scan.size))
        stack(images, os.path.join(mg.SRC_DIR, "compare_%s.png" % sheet))


def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "measure":
        squares = [int(a) for a in sys.argv[4:]] or list(range(1, 16))
        measure(sys.argv[2], sys.argv[3], squares)
    elif len(sys.argv) == 2 and sys.argv[1] == "compose":
        compose()
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
