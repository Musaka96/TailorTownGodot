"""Cut the Steam store / library art from the plates rendered by
`shot_promo.gd -- art` (.dev/promo/art/), into .dev/promo/store/.

    python tools/compose_store_art.py [client]

`client` picks which pair_<n> / pair_close_<n> plate to use (default 4). Every asset
is a crop of a 3840x2160 plate, a forest-green wash where the wordmark sits, and the
game's own wordmark (logo.png) — nothing is drawn here that isn't in the game.

Steam sizes (2026): header 920x430, small 462x174, main 1232x706, vertical 748x896,
page background 1438x810, library capsule 600x900, library header 920x430, library
hero 3840x1240 (no logo), library logo 1280x720 (transparent), community icon 184x184.
"""

import os
import sys

from PIL import Image, ImageFilter

ART = os.path.join(".dev", "promo", "art")
OUT = os.path.join(".dev", "promo", "store")
FOREST = (30, 62, 42)
# Where the pair stand in the pair_<n> plate (3840x2160): centre x, head top, feet.
PAIR_X = 1900
PAIR_TOP = 660
PAIR_FEET = 1620
TAILOR_HEAD = (2225, 900, 270)  # centre x, centre y, half-size — the community icon
LOGO_NAME_ROWS = 745  # logo.png rows that hold the name + stitched needle, no tagline


def plate(name: str) -> Image.Image:
    return Image.open(os.path.join(ART, name + ".png")).convert("RGB")


def crop_to(img: Image.Image, box, size) -> Image.Image:
    return img.crop(tuple(round(v) for v in box)).resize(size, Image.LANCZOS)


def wash(img: Image.Image, side: str, reach: float, strength: float) -> Image.Image:
    """A forest-green gradient from one edge, fading out `reach` of the way across."""
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


def landscape(close: Image.Image, size, pair_at: float, rows, logo_box, tagline=True) -> Image.Image:
    """Pair on the right, wordmark on a green wash on the left."""
    w, h = size
    top, bottom = rows
    crop_w = (bottom - top) * w / h
    x0 = PAIR_X - pair_at * crop_w
    img = crop_to(close, (x0, top, x0 + crop_w, bottom), size)
    img = wash(img, "left", 0.62, 0.94)
    box = (logo_box[0] * w, logo_box[1] * h, logo_box[2] * w, logo_box[3] * h)
    return place_logo(img, box, tagline)


def portrait(close: Image.Image, size, rows, logo_rows) -> Image.Image:
    """Pair along the bottom, wordmark on a green wash across the top."""
    w, h = size
    crop_w = (rows[1] - rows[0]) * w / h
    img = crop_to(close, (PAIR_X - crop_w / 2, rows[0], PAIR_X + crop_w / 2, rows[1]), size)
    img = wash(img, "top", 0.5, 1.0)
    return place_logo(img, (w * 0.08, h * logo_rows[0], w * 0.92, h * logo_rows[1]), False)


def main() -> None:
    client = sys.argv[1] if len(sys.argv) > 1 else "4"
    os.makedirs(OUT, exist_ok=True)
    close = plate("pair_" + client)
    made = {}
    header = landscape(close, (920, 430), 0.68, (560, 1700), (0.03, 0.14, 0.43, 0.86), False)
    made["header_capsule_920x430"] = header
    made["library_header_920x430"] = header
    made["main_capsule_1232x706"] = landscape(
        close, (1232, 706), 0.69, (520, 1720), (0.04, 0.16, 0.4, 0.84)
    )
    made["small_capsule_462x174"] = landscape(
        close, (462, 174), 0.72, (620, 1300), (0.015, 0.04, 0.45, 0.96), False
    )
    made["vertical_capsule_748x896"] = portrait(close, (748, 896), (250, 1750), (0.03, 0.26))
    made["library_capsule_600x900"] = portrait(close, (600, 900), (150, 1800), (0.03, 0.29))
    wide = plate("street_wide_" + client)
    made["library_hero_3840x1240"] = wide.crop((0, 330, 3840, 1570))
    back = crop_to(plate("interior"), (0, 0, 3840, 2160), (1438, 810))
    back = back.filter(ImageFilter.GaussianBlur(5))
    made["page_background_1438x810"] = Image.blend(back, Image.new("RGB", back.size, FOREST), 0.62)
    cx, cy, half = TAILOR_HEAD
    made["community_icon_184x184"] = crop_to(close, (cx - half, cy - half, cx + half, cy + half), (184, 184))
    for name, img in made.items():
        img.save(os.path.join(OUT, name + ".png"))
    mark = logo(True)
    canvas = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    scale = min(1180 / mark.width, 640 / mark.height)
    mark = mark.resize((round(mark.width * scale), round(mark.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(mark, ((1280 - mark.width) // 2, (720 - mark.height) // 2))
    canvas.save(os.path.join(OUT, "library_logo_1280x720.png"))
    print("wrote %d assets to %s" % (len(made) + 1, OUT))


if __name__ == "__main__":
    main()
