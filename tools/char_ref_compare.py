"""Compare a character render with the owner's reference sheets: overlays, side-by-sides
and silhouette proportions. Plain Python (PIL + numpy), no Blender or Godot needed:

    python tools/char_ref_compare.py [--report IMPORT/CHARREWORK/report] [--ref IMPORT/CHARREWORK/ref]

Inputs (made by tools/blender/tripo_character.py --report and tools/shot_char2.gd):
  report/blender_ortho_rest_front.png   our model, rest (T) pose, orthographic, transparent
  report/engine_ortho_idle_front_new.png / _back_new.png   our rig in the game's idle
  report/engine_ortho_idle_front_old.png                   the owner's CHARTGEN1, same idle
  ref/ref_tpose.png                     reference, T-pose front
  ref/ref_arms_down_front_back.png      reference, arms down: left half front, right back
Outputs: report/overlay_*.png and report/overlay_measurements.txt.

Silhouettes are found by distance from the background (the render's alpha, or the
colour at the image border). Every reference is scaled so its top-to-sole height matches
ours and centred on the leg midline; the overlay draws it at 50% over our render.
Measurements are fractions of the total height H, taken from the silhouette alone, so a
feature the silhouette cannot see (a jacket hem the same colour as the trousers, say) is
found from where the outline steps in; the method for each is in measure().
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def load(path, half=None):
    img = Image.open(path).convert("RGBA")
    if half is not None:
        w = img.width // 2
        img = img.crop((0, 0, w, img.height) if half == "left" else (w, 0, img.width, img.height))
    return img


def mask_of(img, threshold=40):
    a = np.asarray(img).astype(np.int32)
    if (a[:, :, 3] < 250).any():  # a transparent render: the alpha is the silhouette
        return a[:, :, 3] > 128
    rgb = a[:, :, :3]
    # background per row, from the left and right border strips (the sheets have a
    # vertical gradient and soft floor shadows)
    strip = np.concatenate([rgb[:, :12], rgb[:, -12:]], axis=1)
    bg = np.median(strip, axis=1)[:, None, :]
    dist = np.abs(rgb - bg).max(axis=2)
    m = dist > threshold
    # drop speckle: a pixel needs 3+ set neighbours in its 3x3
    n = sum(np.roll(np.roll(m, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
    return m & (n >= 4)


def rows_cols(m):
    ys = np.where(m.any(axis=1))[0]
    return ys[0], ys[-1]


def runs(row):
    """(start, end) of each run of set pixels in a boolean row."""
    d = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
    return list(zip(np.where(d == 1)[0], np.where(d == -1)[0] - 1))


def midline(m):
    top, bottom = rows_cols(m)
    h = bottom - top
    band = m[int(top + 0.75 * h):int(top + 0.9 * h)]
    xs = np.where(band.any(axis=0))[0]
    return 0.5 * (xs[0] + xs[-1])


def central_run(row, mid):
    for a, b in runs(row):
        if a <= mid <= b:
            return a, b
    return None


def measure(m, img=None, tpose=True):
    """Proportions of a silhouette as fractions of its height H."""
    top, bottom = rows_cols(m)
    h = float(bottom - top)
    mid = midline(m)
    widths = [(y, runs(m[y])) for y in range(top, bottom + 1)]
    span = max(r[-1][1] - r[0][0] for _, r in widths if r)
    out = {"H px": h, "span / H (hand tip to hand tip)": span / h}
    # neck: the narrowest central run between 25% and 60% of H from the top
    best = None
    for y, r in widths:
        if not (top + 0.25 * h <= y <= top + 0.6 * h):
            continue
        c = central_run(m[y], mid)
        if c is not None and (best is None or c[1] - c[0] < best[1]):
            best = (y, c[1] - c[0])
    neck = best[0] if best else int(top + 0.4 * h)
    out["head height / H (top to neck)"] = (neck - top) / h
    out["head width / H (incl. ears, hair)"] = max(
        (r[-1][1] - r[0][0]) for y, r in widths if y < neck and r) / h
    if not tpose:
        # arms down: the hands touch the hips in the reference, so hips and hem cannot be
        # told from the arms; the span (hand to hand) is what shows how far the arms stand
        # out, and the leg gap how the legs stand
        y = int(top + 0.85 * h)
        r = runs(m[y])
        gaps = [b[0] - a[1] for a, b in zip(r, r[1:])]
        out["leg gap / H (15% above the soles)"] = (max(gaps) / h) if gaps else 0.0
        return out
    # T-pose: rows the arms fill run nearly hand to hand; the shoulder line is the torso
    # width at the armpit, just under the last of them
    arm_rows = [y for y, r in widths if r and (r[-1][1] - r[0][0]) > 0.8 * span]
    below = arm_rows[-1] + 3 if arm_rows else neck
    c = central_run(m[below], mid)
    out["torso width at the armpit / H"] = (c[1] - c[0]) / h if c else 0.0
    x_mid_arm = int(mid + 0.3 * span)
    col = m[top:bottom + 1, min(x_mid_arm, m.shape[1] - 1)]
    out["arm thickness / H (sleeve rows at mid-arm)"] = col.sum() / h
    # hips: widest central run between the arms and 80% down
    hip_y, hip_w = below, 0
    for y, r in widths:
        if below <= y <= top + 0.8 * h:
            c = central_run(m[y], mid)
            if c is not None and c[1] - c[0] > hip_w:
                hip_y, hip_w = y, c[1] - c[0]
    out["hip width / H (widest below the arms)"] = hip_w / h
    # jacket hem: first row under the hips where the outline steps in to 85% of it
    hem = hip_y
    for y in range(hip_y, bottom):
        c = central_run(m[y], mid)
        if c is None or c[1] - c[0] < 0.85 * hip_w:
            hem = y
            break
    out["jacket hem height / H (from the soles)"] = (bottom - hem) / h
    # trouser hem: lowest leg row that is bluer than it is red (navy cloth over brown
    # shoes) -- only when the image is in colour and the suit is navy
    if img is not None and tpose:
        a = np.asarray(img).astype(np.int32)
        th = None
        for y in range(bottom, hem, -1):
            sel = m[y]
            if sel.sum() < 4:
                continue
            px = a[y][sel][:, :3].mean(axis=0)
            if px[2] > px[0] + 4:
                th = y
                break
        if th is not None:
            out["trouser hem height / H (navy over shoes)"] = (bottom - th) / h
    # leg gap: widest gap between the two legs, half way between hem and soles
    y = int(hem + 0.5 * (bottom - hem))
    r = runs(m[y])
    gaps = [b[0] - a[1] for a, b in zip(r, r[1:])]
    out["leg gap / H (mid-shin)"] = (max(gaps) / h) if gaps else 0.0
    return out


def fit(ref_img, ref_mask, our_mask):
    """The reference scaled to our height, positioned sole-to-sole and midline-to-midline
    on our canvas; returns an RGBA image the size of our render."""
    rt, rb = rows_cols(ref_mask)
    ot, ob = rows_cols(our_mask)
    k = (ob - ot) / float(rb - rt)
    scaled = ref_img.resize((max(1, round(ref_img.width * k)), max(1, round(ref_img.height * k))),
                            Image.LANCZOS)
    dx = midline(our_mask) - midline(ref_mask) * k
    dy = ob - rb * k
    canvas = Image.new("RGBA", (our_mask.shape[1], our_mask.shape[0]), (0, 0, 0, 0))
    canvas.paste(scaled, (round(dx), round(dy)))
    return canvas


def on_white(img):
    base = Image.new("RGBA", img.size, (255, 255, 255, 255))
    return Image.alpha_composite(base, img)


def compare(name, ours_path, ref_path, half, out_dir, tpose, lines, extra=None):
    ours = on_white(load(ours_path))
    ours_mask = mask_of(load(ours_path))
    ref = load(ref_path, half)
    ref_mask = mask_of(ref)
    placed = fit(ref, ref_mask, ours_mask)
    ghost = placed.copy()
    ghost.putalpha(Image.eval(placed.getchannel("A"), lambda a: a // 2))
    Image.alpha_composite(ours, ghost).convert("RGB").save(out_dir / ("overlay_%s.png" % name))
    side = Image.new("RGB", (ours.width * 2, ours.height), (255, 255, 255))
    side.paste(ours.convert("RGB"), (0, 0))
    side.paste(on_white(placed).convert("RGB"), (ours.width, 0))
    side.save(out_dir / ("overlay_%s_side_by_side.png" % name))
    Image.fromarray((np.stack([ref_mask] * 3, axis=2) * 255).astype(np.uint8)).save(
        out_dir / ("overlay_%s_ref_mask.png" % name))
    a = measure(ref_mask, ref, tpose)
    b = measure(ours_mask, load(ours_path), tpose)
    cols = [("reference", a), ("ours", b)]
    if extra is not None:
        cols.append(("owner CHARTGEN1", measure(mask_of(load(extra)), None, tpose)))
    lines.append("\n%s (ref %s%s vs %s)" % (name, Path(ref_path).name,
                                             " %s half" % half if half else "",
                                             Path(ours_path).name))
    head = "  %-42s" % "measure" + "".join("%16s" % c for c, _ in cols) + "   ours vs ref"
    lines.append(head)
    for key in a:
        vals = [c.get(key) for _, c in cols]
        row = "  %-42s" % key + "".join(
            "%16s" % ("-" if v is None else ("%.0f" % v if key == "H px" else "%.3f" % v))
            for v in vals)
        if key != "H px" and a.get(key) and b.get(key) is not None:
            dev = (b[key] - a[key]) / a[key] * 100.0
            row += "   %+6.1f%%%s" % (dev, "  <-- past 5%" if abs(dev) > 5.0 else "")
        lines.append(row)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--report", default="IMPORT/CHARREWORK/report")
    p.add_argument("--ref", default="IMPORT/CHARREWORK/ref")
    ns = p.parse_args()
    rep = ROOT / ns.report
    ref = ROOT / ns.ref
    lines = [
        "Silhouette proportions, fractions of the total height H (head top to soles).",
        "Engine renders (idle) carry the game's black outline hull: widths read a few",
        "pixels fat and a narrow leg gap can close.",
    ]
    compare("tpose", rep / "blender_ortho_rest_front.png", ref / "ref_tpose.png", None,
            rep, True, lines)
    sheet = ref / "ref_arms_down_front_back.png"
    compare("idle_front", rep / "engine_ortho_idle_front_new.png", sheet, "left", rep, False,
            lines, extra=rep / "engine_ortho_idle_front_old.png")
    compare("idle_back", rep / "engine_ortho_idle_back_new.png", sheet, "right", rep, False,
            lines)
    text = "\n".join(lines)
    (rep / "overlay_measurements.txt").write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
