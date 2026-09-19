"""Cut the Steam store / library art from the plates rendered by
`shot_promo.gd -- art` (.dev/promo/art/), into .dev/promo/store/<scene>/.

    python tools/compose_store_art.py [scene ...]

Scenes (default: all) — each is one 3840x2160 plate plus where its people stand:
  mirror  the tailor sizing up a client in a showcase suit at the fitting mirror
  work    the tailor at the cutting table with Percy the apprentice
  street  the tailor and a client outside the shopfront
Every asset is a crop of the plate, a forest-green wash where the wordmark sits, and
the game's own wordmark (logo.png) — nothing is drawn here that isn't in the game.

Steam sizes (2026): header 920x430, small 462x174, main 1232x706, vertical 748x896,
page background 1438x810, library capsule 600x900, library header 920x430, library
hero 3840x1240 (no logo), library logo 1280x720 (transparent), community icon 184x184.
"""

import os
import sys

from PIL import Image, ImageFilter, ImageOps

ART = os.path.join(".dev", "promo", "art")
OUT = os.path.join(".dev", "promo", "store")
FOREST = (30, 62, 42)
LOGO_NAME_ROWS = 745  # logo.png rows that hold the name + stitched needle, no tagline
# plate: file in ART. x / top / feet: the group's centre column, head-top and feet rows.
# logo: which side of a landscape capsule the wordmark takes. head: the tailor's face
# (centre x, centre y, half-size) for the community icon. hero: rows of the library hero.
# at: how far across a landscape capsule the group sits, away from the wordmark (default
# per capsule). small: overrides for the small capsule only.
SCENES = {
    "mirror": {
        "plate": "mirror_0a", "x": 1900, "top": 460, "feet": 1620, "logo": "left",
        "head": (1600, 770, 310), "hero": (380, 1620),
    },
    "work": {
        "plate": "work_a", "x": 2010, "top": 340, "feet": 1640, "logo": "right", "at": 0.7,
        "head": (1620, 750, 300), "hero": (300, 1540),
        # Two big heads leave no room for the name at 462x174: the tailor alone, name left.
        "small": {"x": 1620, "logo": "left", "at": 0.8},
        # The header crop spans nearly the whole plate, so the name gets the narrow end.
        "header_logo": (0.025, 0.2, 0.34, 0.8),
    },
    "street": {
        "plate": "pair_4", "x": 1900, "top": 660, "feet": 1620, "logo": "left",
        "head": (2225, 900, 270), "hero": None,
    },
}


def plate(name: str) -> Image.Image:
    return Image.open(os.path.join(ART, name + ".png")).convert("RGB")


def crop_to(img: Image.Image, box, size) -> Image.Image:
    return img.crop(tuple(round(v) for v in box)).resize(size, Image.LANCZOS)


def wash(img: Image.Image, side: str, reach: float, strength: float) -> Image.Image:
    """A forest-green gradient from one edge, fading out `reach` of the way across."""
    if side == "right":
        return ImageOps.mirror(wash(ImageOps.mirror(img), "left", reach, strength))
    w, h = img.size
    length = w if side == "left" else h
    ramp = Image.new("L", (length, 1))
    ramp.putdata(
        [round(255 * strength * max(0.0, 1.0 - i / (length * reach)) ** 1.4) for i in range(length)]
    )
    mask = ramp.resize((w, h)) if side == "left" else ramp.rotate(-90, expand=True).resize((w, h))
    return Image.composite(Image.new("RGB", (w, h), FOREST), img, mask)


def logo(tagline: bool) -> Image.Image:
    img = Image.open(os.path.join(ART, "logo.png")).convert("RGBA")
    if not tagline:
        img = img.crop((0, 0, img.width, LOGO_NAME_ROWS))
    return img.crop(img.getbbox())


def place_logo(img: Image.Image, box, tagline=True) -> Image.Image:
    """Fit the wordmark inside box (x0, y0, x1, y1), centred, with a soft shadow."""
    mark = logo(tagline)
    bw, bh = box[2] - box[0], box[3] - box[1]
    scale = min(bw / mark.width, bh / mark.height)
    mark = mark.resize((max(1, round(mark.width * scale)), max(1, round(mark.height * scale))), Image.LANCZOS)
    at = (round(box[0] + (bw - mark.width) / 2), round(box[1] + (bh - mark.height) / 2))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dark = Image.new("RGBA", mark.size, (12, 26, 18, 150))
    shadow.paste(dark, (at[0], at[1] + max(2, mark.height // 60)), mark)
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(2, mark.height // 40)))
    out = img.convert("RGBA")
    out.alpha_composite(shadow)
    out.alpha_composite(mark, at)
    return out.convert("RGB")


def landscape(scene, img: Image.Image, size, pair_at: float, pad, logo_box, tagline=True):
    """The group to one side, the wordmark on a green wash on the other."""
    w, h = size
    top, bottom = scene["top"] - pad[0], scene["feet"] + pad[1]
    crop_w = (bottom - top) * w / h
    right = scene["logo"] == "right"
    pair_at = scene.get("at", pair_at)
    x0 = scene["x"] - (1.0 - pair_at if right else pair_at) * crop_w
    x0 = min(max(x0, 0), img.width - crop_w)
    out = crop_to(img, (x0, top, x0 + crop_w, bottom), size)
    out = wash(out, scene["logo"], 0.62, 0.94)
    lx0, lx1 = (1.0 - logo_box[2], 1.0 - logo_box[0]) if right else (logo_box[0], logo_box[2])
    return place_logo(out, (lx0 * w, logo_box[1] * h, lx1 * w, logo_box[3] * h), tagline)


def portrait(scene, img: Image.Image, size, pad, logo_rows) -> Image.Image:
    """The group along the bottom, the wordmark on a green wash across the top."""
    w, h = size
    top, bottom = scene["top"] - pad[0], scene["feet"] + pad[1]
    crop_w = (bottom - top) * w / h
    out = crop_to(img, (scene["x"] - crop_w / 2, top, scene["x"] + crop_w / 2, bottom), size)
    out = wash(out, "top", 0.5, 1.0)
    return place_logo(out, (w * 0.08, h * logo_rows[0], w * 0.92, h * logo_rows[1]), False)


def compose(name: str) -> None:
    scene = SCENES[name]
    img = plate(scene["plate"])
    out_dir = os.path.join(OUT, name)
    os.makedirs(out_dir, exist_ok=True)
    made = {}
    header_logo = scene.get("header_logo", (0.03, 0.14, 0.43, 0.86))
    header = landscape(scene, img, (920, 430), 0.68, (100, 80), header_logo, False)
    made["header_capsule_920x430"] = header
    made["library_header_920x430"] = header
    made["main_capsule_1232x706"] = landscape(
        scene, img, (1232, 706), 0.69, (140, 100), (0.04, 0.16, 0.4, 0.84)
    )
    small = dict(scene, feet=scene["top"] + 640, **scene.get("small", {}))
    made["small_capsule_462x174"] = landscape(
        small, img, (462, 174), 0.72, (40, 0), (0.015, 0.04, 0.45, 0.96), False
    )
    made["vertical_capsule_748x896"] = portrait(scene, img, (748, 896), (410, 130), (0.03, 0.26))
    made["library_capsule_600x900"] = portrait(scene, img, (600, 900), (510, 180), (0.03, 0.29))
    if scene["hero"]:
        made["library_hero_3840x1240"] = img.crop((0, scene["hero"][0], 3840, scene["hero"][1]))
    else:
        made["library_hero_3840x1240"] = plate("street_wide_4").crop((0, 330, 3840, 1570))
    back = crop_to(plate("interior"), (0, 0, 3840, 2160), (1438, 810))
    back = back.filter(ImageFilter.GaussianBlur(5))
    made["page_background_1438x810"] = Image.blend(back, Image.new("RGB", back.size, FOREST), 0.62)
    cx, cy, half = scene["head"]
    made["community_icon_184x184"] = crop_to(img, (cx - half, cy - half, cx + half, cy + half), (184, 184))
    for file, art in made.items():
        art.save(os.path.join(out_dir, file + ".png"))
    mark = logo(True)
    canvas = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    scale = min(1180 / mark.width, 640 / mark.height)
    mark = mark.resize((round(mark.width * scale), round(mark.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(mark, ((1280 - mark.width) // 2, (720 - mark.height) // 2))
    canvas.save(os.path.join(out_dir, "library_logo_1280x720.png"))
    print("%s: wrote %d assets to %s" % (name, len(made) + 1, out_dir))


def main() -> None:
    for name in sys.argv[1:] or list(SCENES):
        if all(os.path.exists(os.path.join(ART, f + ".png")) for f in [SCENES[name]["plate"]]):
            compose(name)
        else:
            print("%s: plate %s.png missing - run shot_promo.gd -- art" % (name, SCENES[name]["plate"]))


if __name__ == "__main__":
    main()
