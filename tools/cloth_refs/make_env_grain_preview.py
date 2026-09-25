"""Photo grain on the town kit, the stations and the shop looks: a PREVIEW only.

Multiplies each environment texture set's albedo by one of the seamless photo grain
tiles in assets/dev/cloth_refs/ (make_grain.py), and adds that tile's normal map to
the set's own, at the grain's real physical size. Nothing in the game is touched:
the results go to .dev/env_grain/<set>_{albedo,normal}.png, and
tools/shot_env_grain.gd swaps them in at runtime for before/after shots.

    python tools/cloth_refs/make_env_grain_preview.py [short]           # grained textures
    python tools/cloth_refs/make_env_grain_preview.py compose [short]   # the review sheet

Presets (PRESETS at the bottom): "full" (default) is every mapped set into
.dev/env_grain/; "short" is the recommended subset only, into .dev/env_grain_short/.

Sizes. One grain tile covers:
  interior sheet  10 cm per cell width (grid_px / 5 columns), cut to a square of
                  crop_px, so crop_px / cell_px * 10 cm  (about 9 cm)
  street sheet    30 cm per cell, less the 5% inset each side: 27 cm
  cloth scans     9 cm (the swatch scan, as materials/cloth.gdshader states)
One albedo tile covers the set's "metres per tile" from IMPORT/town_kit/build_*.py
(TEX_SETS), or the station scale from build_stations_v1.py, or for a shop look the
slot's kit tile over the look's uv_scale. The grain repeats a whole number of times
across the albedo (rounded), so the result still tiles.

Output set names: kit sets keep their name, station sets are st_<set>, shop-look
textures are sl_<set>. Kit `plaster` is the render on the street fronts (wall_*);
the interior plaster is the shop look's (sl_plaster).
"""

import glob
import json
import os
import re
import sys
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REFS = os.path.join(ROOT, "assets", "dev", "cloth_refs")
KIT_TEX = os.path.join(ROOT, "IMPORT", "town_kit", "textures")
STATION_TEX = os.path.join(ROOT, "assets", "models", "stations")
LOOK_TEX = os.path.join(ROOT, "assets", "textures", "shop_looks")
LOOK_DIR = os.path.join(ROOT, "data", "shop_looks")
OUT = os.path.join(ROOT, ".dev", "env_grain")
GRAIN_MEAN = 0.25  # make_grain.py
INSET = 0.05  # make_grain.py
CLOTH_SCAN_M = 0.09  # materials/cloth.gdshader: "9 cm scan"
STREET_CELL_M = 0.30
INTERIOR_CELL_M = 0.10
CONTACT_CELL = 256

# kit set -> (metres per albedo tile, grain tile, strength); scales from TEX_SETS
KIT = {
    "plaster": (3.0, "street_3_tile", 1.0),  # wall_*: the render on the street fronts
    "brick": (1.0, "street_1_tile", 0.5),
    "stone_dressed": (1.2, "street_2_tile", 0.5),
    "cobble": (2.0, "street_8_tile", 1.0),
    "asphalt": (4.0, "street_10_tile", 1.0),
    "grain_oak": (1.0, "interior_4_tile", 0.6),
    "grain_walnut": (1.0, "interior_6_tile", 1.0),
    "grain_mahogany": (1.0, "interior_5_tile", 1.0),
    "floor_planks": (2.0, "interior_4_tile", 0.6),
    "parquet": (2.0, "interior_4_tile", 0.6),
    "velvet": (1.0, "interior_11_tile", 0.5),
    "plush": (0.5, "interior_11_tile", 0.5),
    "cork": (0.3, "interior_13_tile", 1.0),
    "cardboard": (0.5, "interior_14_tile", 1.0),
    "fabric": (0.5, "suitings_2_tile", 1.0),
    "canvas": (0.5, "shirtings_3_tile", 0.7),  # awnings; the workshop's felt roof is 1.0 m
}
# station set -> (metres per albedo tile, grain tile, strength); build_stations_v1.py
# uses several scales per set, the one taken here is the main body's
STATIONS = {
    "st_grain": (0.7, "interior_6_tile", 1.0),  # st_walnut (st_oak is 0.5)
    "st_steel": (0.15, "interior_9_tile", 1.0),
    "st_enamel": (0.35, "interior_10_tile", 0.7),  # st_machine/st_cream (0.2-0.3 trims)
    "st_iron": (0.3, "interior_8_tile", 0.7),  # the stand (st_belt is 0.2)
    "st_weave": (0.1, "shirtings_3_tile", 1.0),  # cloth (st_paper is 0.3)
}
# shop-look texture -> (grain tile, strength); the scale comes from the looks' uv_scale
LOOKS = {
    "plaster": ("interior_2_tile", 1.0),  # the interior walls
    "floor_planks": ("interior_4_tile", 0.6),
    "parquet": ("interior_4_tile", 0.6),
    "velvet": ("interior_11_tile", 0.5),
}
# kit metres per tile for each shop-look slot (build_v7.py / build_town_kit.py)
LOOK_SLOT_M = {"wall": 2.0, "wainscot": 2.0, "floor": 2.0, "drape": 1.0}


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1.0 / 2.4) - 0.055)


def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255.0


def save_rgb(a, path):
    Image.fromarray(np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8)).save(path)


def grain_tile_m(tile):
    """Physical side of one seamless grain tile, from refs.json's sheet layout."""
    sheet = tile.split("_")[0]
    with open(os.path.join(REFS, "refs.json"), encoding="utf-8") as fh:
        lay = json.load(fh)["layout"][sheet]
    if sheet == "interior":
        cell_px = lay["grid_px"][0] / 5.0
        return INTERIOR_CELL_M * lay["crop_px"] / cell_px
    if sheet == "street":
        return STREET_CELL_M * (1.0 - 2.0 * INSET)
    return CLOTH_SCAN_M


def resize_float(a, size):
    chans = [
        np.asarray(Image.fromarray(a[..., c].astype(np.float32), "F").resize(size, Image.LANCZOS))
        for c in range(a.shape[2])
    ]
    return np.stack(chans, axis=-1).astype(np.float64)


def wrap_sample(tile, h, w, repeats):
    """`tile` repeated `repeats` times across an h x w image, sampled bilinearly with
    wraparound (after a Lanczos prefilter to the per-repeat pixel size)."""
    th = max(2, int(round(h / repeats)))
    tw = max(2, int(round(w / repeats)))
    small = resize_float(tile, (tw, th)) if (th, tw) != tile.shape[:2] else tile
    ys = (np.arange(h) + 0.5) * th * repeats / h - 0.5
    xs = (np.arange(w) + 0.5) * tw * repeats / w - 0.5
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None, None]
    fx = (xs - x0)[None, :, None]
    y0, y1 = y0 % th, (y0 + 1) % th
    x0, x1 = x0 % tw, (x0 + 1) % tw
    top = small[y0][:, x0] * (1 - fx) + small[y0][:, x1] * fx
    bot = small[y1][:, x0] * (1 - fx) + small[y1][:, x1] * fx
    return top * (1 - fy) + bot * fy


def grain_one(name, albedo_path, normal_path, metres, tile, strength):
    tile_m = grain_tile_m(tile)
    repeats = max(1, int(round(metres / tile_m)))
    grain = load_rgb(os.path.join(REFS, tile + ".png"))
    grain_n = load_rgb(os.path.join(REFS, tile + "_n.png")) * 2.0 - 1.0
    albedo = load_rgb(albedo_path)
    h, w = albedo.shape[:2]
    g = wrap_sample(grain, h, w, repeats) / GRAIN_MEAN
    lin = srgb_to_linear(albedo) * (1.0 + strength * (g - 1.0))
    save_rgb(linear_to_srgb(lin), os.path.join(OUT, name + "_albedo.png"))
    if normal_path and os.path.exists(normal_path):
        base = load_rgb(normal_path) * 2.0 - 1.0
        nh, nw = base.shape[:2]
        gn = wrap_sample(grain_n, nh, nw, repeats)
        n = np.stack(
            [
                base[..., 0] + strength * gn[..., 0],
                base[..., 1] + strength * gn[..., 1],
                base[..., 2],
            ],
            axis=-1,
        )
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
        save_rgb(n * 0.5 + 0.5, os.path.join(OUT, name + "_normal.png"))
    info = {
        "set": name,
        "albedo_m": round(metres, 4),
        "grain": tile,
        "grain_m": round(tile_m, 4),
        "repeats": repeats,
        "grain_m_effective": round(metres / repeats, 4),
        "strength": strength,
        "source": os.path.relpath(albedo_path, ROOT).replace("\\", "/"),
    }
    print(
        "  %-16s albedo %.2f m  %-17s %.3f m  x%-3d (%.3f m)  s=%.1f"
        % (name, metres, tile, tile_m, repeats, metres / repeats, strength)
    )
    return info


def look_scales():
    """Shop-look texture -> metres per albedo tile, from the looks' slot uv_scale."""
    found = {}
    for path in sorted(glob.glob(os.path.join(LOOK_DIR, "*.tres"))):
        text = open(path, encoding="utf-8").read()
        ext = dict(re.findall(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"', text))
        ext = {v: k for k, v in ext.items()}
        subs = {}
        for block in re.split(r"\n(?=\[)", text):
            m = re.match(r'\[sub_resource [^\]]*id="([^"]+)"', block)
            if not m:
                continue
            alb = re.search(r'albedo_texture = ExtResource\("([^"]+)"\)', block)
            scale = re.search(r"uv_scale = ([0-9.]+)", block)
            subs[m.group(1)] = (
                ext.get(alb.group(1)) if alb else None,
                float(scale.group(1)) if scale else 1.0,
            )
        for slot, sub in re.findall(r'\n(\w+) = SubResource\("([^"]+)"\)', text):
            tex, scale = subs.get(sub, (None, 1.0))
            if tex is None or slot not in LOOK_SLOT_M:
                continue
            stem = os.path.basename(tex).replace("_albedo.png", "")
            found.setdefault(stem, []).append(LOOK_SLOT_M[slot] / scale)
    return {k: Counter(v).most_common(1)[0][0] for k, v in found.items()}


def make_all(preset):
    only = PRESETS[preset]["sets"]
    os.makedirs(OUT, exist_ok=True)
    infos = []
    print("kit sets (IMPORT/town_kit/textures):")
    for name, (metres, tile, s) in KIT.items():
        if only is not None and name not in only:
            continue
        base = os.path.join(KIT_TEX, name)
        infos.append(
            grain_one(name, base + "_albedo.png", base + "_normal.png", metres, tile, s)
        )
    print("station sets (assets/models/stations, sewing_v1 copies; all three are identical):")
    for name, (metres, tile, s) in STATIONS.items():
        if only is not None and name not in only:
            continue
        base = os.path.join(STATION_TEX, "sewing_v1_" + name)
        infos.append(
            grain_one(name, base + "_albedo.jpg", base + "_normal.jpg", metres, tile, s)
        )
    print("shop looks (assets/textures/shop_looks):")
    scales = look_scales()
    for name, (tile, s) in LOOKS.items():
        if only is not None and "sl_" + name not in only:
            continue
        if name not in scales:
            print("  %-16s no shop look uses it, skipped" % ("sl_" + name))
            continue
        base = os.path.join(LOOK_TEX, name)
        infos.append(
            grain_one(
                "sl_" + name, base + "_albedo.png", base + "_normal.png", scales[name], tile, s
            )
        )
    with open(os.path.join(OUT, "sets.json"), "w", encoding="utf-8") as fh:
        json.dump(infos, fh, indent=1)
    contact(infos)


def contact(infos):
    cols = 4
    pair_w = CONTACT_CELL * 2 + 8
    label_h = 30
    rows = (len(infos) + cols - 1) // cols
    size = (cols * pair_w + (cols + 1) * 12, rows * (CONTACT_CELL + label_h + 12) + 12)
    sheet = Image.new("RGB", size, (24, 26, 30))
    d = ImageDraw.Draw(sheet)
    for i, info in enumerate(infos):
        x = 12 + (i % cols) * (pair_w + 12)
        y = 12 + (i // cols) * (CONTACT_CELL + label_h + 12)
        src = Image.open(os.path.join(ROOT, info["source"])).convert("RGB")
        new = Image.open(os.path.join(OUT, info["set"] + "_albedo.png")).convert("RGB")
        cell = (CONTACT_CELL, CONTACT_CELL)
        sheet.paste(src.resize(cell, Image.LANCZOS), (x, y))
        sheet.paste(new.resize(cell, Image.LANCZOS), (x + CONTACT_CELL + 8, y))
        label = "%s  <- %s x%d  s%.1f" % (
            info["set"], info["grain"], info["repeats"], info["strength"]
        )
        d.text((x, y + CONTACT_CELL + 8), label, fill=(230, 230, 230))
    sheet.save(os.path.join(OUT, "contact.png"))
    print("Saved", os.path.join(OUT, "contact.png"), sheet.size)


def compose(preset):
    """The before/after review sheet from tools/shot_env_grain.gd's frames. Rows whose
    frames are missing (an optional view) are left out."""
    sys.dont_write_bytecode = True  # no tools/__pycache__ from the import
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import cloth_sheets as cs  # noqa: E402

    cfg = PRESETS[preset]
    shots = os.path.join(ROOT, ".dev", cfg["shots"])
    half = 940
    band_h = 40
    width = half * 2 + 12
    parts = [cs.title_strip(width, cfg["title"], None)]
    for key, caption in cfg["rows"]:
        paths = [os.path.join(shots, "%s_%s.png" % (key, tag)) for tag in ("before", "after")]
        if not all(os.path.exists(p) for p in paths):
            print("  no frames for %s, row left out" % key)
            continue
        before, after = (Image.open(p).convert("RGB") for p in paths)
        h = round(before.height * half / before.width)
        parts.append(cs.caption_strip(width, caption))
        line = Image.new("RGB", (width, band_h + h), cs.TITLE_BG)
        d = ImageDraw.Draw(line)
        pairs = ((before, "before", "BEFORE"), (after, "after", "AFTER"))
        for i, (img, style, text) in enumerate(pairs):
            x = i * (half + 12)
            d.rectangle((x, 0, x + half - 1, band_h - 1), fill=cs.BANDS[style][0])
            d.text((x + cs.PAD, 4), text, font=cs.font(28, "Bold"), fill=cs.WHITE)
            line.paste(img.resize((half, h), Image.LANCZOS), (x, band_h))
        parts.append(line)
    out = Image.new("RGB", (width, sum(p.height for p in parts)), cs.TITLE_BG)
    y = 0
    for p in parts:
        out.paste(p, (0, y))
        y += p.height
    dest = os.path.join(ROOT, ".dev", cfg["sheet"])
    out.save(dest)
    print("Saved", dest, out.size)


PRESETS = {
    "full": {
        "sets": None,  # everything in KIT / STATIONS / LOOKS
        "out": "env_grain",
        "shots": "env_grain_shots",
        "sheet": "env_grain_compare.png",
        "title": "PHOTO GRAIN ON THE SHOP AND STREET (runtime preview)",
        "rows": [
            ("env_shop_game", "Gameplay camera, front shop from the door"),
            ("env_shop_close", "Inside, low and level: wall, wainscot, floor, worktable"),
            ("env_street", "The street: shop front, pavement, door"),
        ],
    },
    # the recommended subset: same tiles and strengths as the full list, nothing else
    "short": {
        "sets": {
            "grain_walnut",
            "grain_mahogany",
            "plaster",
            "sl_plaster",
            "cobble",
            "cork",
            "cardboard",
            "st_grain",
            "st_steel",
            "st_enamel",
            "fabric",
        },
        "out": "env_grain_short",
        "shots": "env_grain_shots_short",
        "sheet": "env_grain_short_compare.png",
        "title": "PHOTO GRAIN, SHORT LIST (runtime preview)",
        "rows": [
            ("short_game_workroom", "Gameplay camera, the player at the worktable"),
            ("short_close_stations", "Close: worktable, sewing machine, the bolts"),
            ("short_close_wall", "Close: the render pier east of the door, the plinth, the paving"),
            ("short_close_cobbles", "Close: the nearest cobbles"),
            ("short_street_customer", "Street framing (shot_mirror mode=street), seed 19"),
        ],
    },
}


if __name__ == "__main__":
    argv = sys.argv[1:]
    mode = "compose" if argv and argv[0] == "compose" else "make"
    if mode == "compose":
        argv = argv[1:]
    chosen = argv[0] if argv else "full"
    if chosen not in PRESETS:
        sys.exit("unknown preset %r (full, short)" % chosen)
    OUT = os.path.join(ROOT, ".dev", PRESETS[chosen]["out"])
    if mode == "compose":
        compose(chosen)
    else:
        make_all(chosen)
