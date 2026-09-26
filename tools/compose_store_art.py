"""Cut the Steam store / library art from the plates rendered by
`shot_promo.gd -- art` (.dev/promo/art/), into .dev/promo/store/<scene>/.

    python tools/compose_store_art.py [scene ...]

Each scene is one 3840x2160 plate plus where its people stand. Every asset is a crop of
the plate dressed with the game's own craft pieces, rendered by `-- art_badges`:
  sign_full.png / sign_name.png  the shop's walnut fascia sign with the gold wordmark,
                                 chains rising off the top (with / without the tagline)
  tape.png                       a tailor's tape measure (Craft.tape)
plus a cream running stitch sewn round the edge, drawn here the way Craft.stitch draws it.

Steam sizes (2026): header 920x430, small 462x174, main 1232x706, vertical 748x896,
page background 1438x810, library capsule 600x900, library header 920x430, library
hero 3840x1240 (no logo), library logo 1280x720 (transparent), community icon 184x184.
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ART = os.path.join(".dev", "promo", "art")
OUT = os.path.join(".dev", "promo", "store")
CREAM = (244, 234, 210)
WALNUT = (74, 56, 38)
SS = 2  # compose at this multiple, then downsample: smooth stitches and edges
SIGN_BOARD_TOP = 1200  # sign_*.png: rows above this are chain only (SIGN_CHAIN x LOGO_SCALE)

# plate: file in ART. x / top / feet: the group's centre column, head-top and feet rows.
# logo: which side of a landscape capsule the sign hangs on. head: the tailor's face
# (centre x, centre y, half-size) for the community icon. hero: rows of the library hero.
# at: how far across a landscape capsule the group's centre sits, measured from the sign
# side. small: overrides for the small capsule only.
SCENES = {
    # The tailor with a bolt and two clients in the workroom: racks of suits, the cloth
    # cabinet and a sewing machine behind them (shot_promo.gd -- art_shop).
    "shop": {
        "plate": "shop_1a", "x": 1580, "top": 465, "feet": 1470, "logo": "right",
        "head": (1590, 790, 330), "hero": (250, 1490),
    },
    # The same spot with two of the named cast: Mr. Dimmock and Mr. Pettigrew (-- art_named).
    "named": {
        "plate": "shop_named_0a", "x": 1580, "top": 465, "feet": 1470, "logo": "right",
        "head": (1590, 790, 330), "hero": (250, 1490),
    },
    "shop_alt": {
        "plate": "shop_0a", "x": 1580, "top": 465, "feet": 1470, "logo": "right",
        "head": (1590, 790, 330), "hero": (250, 1490),
    },
}

def plate(name: str) -> Image.Image:
    return Image.open(os.path.join(ART, name + ".png")).convert("RGB")


def badge(name: str) -> Image.Image:
    return Image.open(os.path.join(ART, name + ".png")).convert("RGBA")


def crop_to(img: Image.Image, box, size) -> Image.Image:
    return img.crop(tuple(round(v) for v in box)).resize(size, Image.LANCZOS)


def shade(img: Image.Image, centre, radius: float, strength: float) -> Image.Image:
    """Darken softly toward walnut around `centre`, so the sign stands off a busy wall."""
    w, h = img.size
    small = Image.new("L", (w // 8 + 1, h // 8 + 1))
    px = small.load()
    cx, cy = centre[0] / 8, centre[1] / 8
    r = radius / 8
    for y in range(small.height):
        for x in range(small.width):
            d = math.hypot(x - cx, y - cy) / r
            px[x, y] = round(255 * strength * max(0.0, 1.0 - d) ** 1.6)
    mask = small.resize((w, h), Image.BILINEAR).filter(ImageFilter.GaussianBlur(w / 60))
    return Image.composite(Image.new("RGB", (w, h), WALNUT), img, mask)


def vignette(img: Image.Image, strength: float) -> Image.Image:
    w, h = img.size
    small = Image.new("L", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            d = math.hypot((x - 31.5) / 31.5, (y - 31.5) / 31.5) / math.sqrt(2)
            px[x, y] = round(255 * strength * max(0.0, d - 0.55) / 0.45)
    mask = small.resize((w, h), Image.BILINEAR)
    return Image.composite(Image.new("RGB", (w, h), WALNUT), img, mask)


def hang_sign(img: Image.Image, name: str, centre_x: float, board_top: float, width: float):
    """Hang the sign with its board's top edge at board_top; the chains run up off the
    top of the image (cropped), or are cut short if the board sits high."""
    sign = badge(name)
    scale = width / sign.width
    sign = sign.resize((round(sign.width * scale), round(sign.height * scale)), Image.LANCZOS)
    at = (round(centre_x - sign.width / 2), round(board_top - SIGN_BOARD_TOP * scale))
    out = img.convert("RGBA")
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    dark = Image.new("RGBA", sign.size, (20, 12, 6, 120))
    drop = max(3, sign.width // 50)
    shadow.paste(dark, (at[0] + drop // 2, at[1] + drop), sign)
    shadow = shadow.filter(ImageFilter.GaussianBlur(drop))
    out.alpha_composite(shadow)
    out.alpha_composite(sign, at) if at[1] >= 0 else out.alpha_composite(
        sign.crop((0, -at[1], sign.width, sign.height)), (at[0], 0)
    )
    return out.convert("RGB")


def sign_height(name: str, width: float) -> float:
    """Height of the sign's board (no chains) at `width`."""
    sign = badge(name)
    return (sign.height - SIGN_BOARD_TOP) * width / sign.width


def lay_tape(img: Image.Image, start, angle_deg: float, length: float, thick: float):
    """A tape measure dropped across the art from `start` (its zero end), off the edge."""
    tape = badge("tape")
    scale = thick / tape.height
    tape = tape.resize((round(tape.width * scale), round(thick)), Image.LANCZOS)
    tape = tape.crop((0, 0, min(tape.width, round(length)), tape.height))
    rot = tape.rotate(angle_deg, expand=True, resample=Image.BICUBIC)
    # rotate() keeps the centre; place so the zero end lands on `start`.
    a = math.radians(angle_deg)
    half = tape.width / 2
    cx = start[0] + math.cos(a) * half
    cy = start[1] - math.sin(a) * half
    out = img.convert("RGBA")
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    pos = (round(cx - rot.width / 2), round(cy - rot.height / 2))
    dark = Image.new("RGBA", rot.size, (20, 12, 6, 110))
    shadow.paste(dark, (pos[0] + 2, pos[1] + round(thick * 0.18)), rot)
    shadow = shadow.filter(ImageFilter.GaussianBlur(thick * 0.12))
    out.alpha_composite(shadow)
    out.alpha_composite(rot, pos)
    return out.convert("RGB")


def stitch_edge(img: Image.Image, inset: float, width: float, dash: float) -> Image.Image:
    """A cream running stitch sewn round the capsule, like the menus' stitched borders."""
    w, h = img.size
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    r = inset * 1.6
    pts = []
    # A rounded rectangle traced as one path, so the dashes run evenly round the corners.
    box = (inset, inset, w - inset, h - inset)
    corners = [
        (box[2] - r, box[1] + r, -90), (box[2] - r, box[3] - r, 0),
        (box[0] + r, box[3] - r, 90), (box[0] + r, box[1] + r, 180),
    ]
    for cx, cy, a0 in corners:
        for i in range(13):
            a = math.radians(a0 + 90 * i / 12)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append(pts[0])
    run, on = 0.0, True
    for p, q in zip(pts, pts[1:]):
        seg = math.dist(p, q)
        t = 0.0
        while t < seg:
            step = min(dash - run, seg - t)
            a = (p[0] + (q[0] - p[0]) * t / seg, p[1] + (q[1] - p[1]) * t / seg)
            b = (p[0] + (q[0] - p[0]) * (t + step) / seg, p[1] + (q[1] - p[1]) * (t + step) / seg)
            if on:
                d.line([(a[0] + width * 0.4, a[1] + width * 0.6), (b[0] + width * 0.4, b[1] + width * 0.6)],
                       fill=(30, 20, 10, 90), width=round(width))
                d.line([a, b], fill=CREAM + (215,), width=round(width))
            t += step
            run += step
            if run >= dash - 1e-6:
                run, on = 0.0, not on
    out = img.convert("RGBA")
    out.alpha_composite(over)
    return out.convert("RGB")


def finish(img: Image.Image, size, stitch=True) -> Image.Image:
    if stitch:
        s = size[1] * SS
        img = stitch_edge(img, s * 0.03, max(2.0, s * 0.0045), s * 0.02)
    return img.resize(size, Image.LANCZOS)


def landscape(scene, img, size, at, pad, sign_w, sign_top, sign_name="sign_full", tape=True):
    """The group to one side; the shop sign hanging on the other."""
    w, h = size[0] * SS, size[1] * SS
    top, bottom = scene["top"] - pad[0], scene["feet"] + pad[1]
    crop_w = (bottom - top) * w / h
    right = scene["logo"] == "right"
    at = scene.get("at", at)
    x0 = scene["x"] - ((1.0 - at) if right else at) * crop_w
    x0 = min(max(x0, 0), img.width - crop_w)
    out = crop_to(img, (x0, top, x0 + crop_w, bottom), (w, h))
    out = vignette(out, 0.35)
    sx = (1.0 - sign_w[0]) * w if right else sign_w[0] * w
    sw = sign_w[1] * w
    out = shade(out, (sx, sign_top * h + sign_height(sign_name, sw) / 2), sw * 0.85, 0.55)
    out = hang_sign(out, sign_name, sx, sign_top * h, sw)
    if tape:
        th = h * 0.045
        if right:
            out = lay_tape(out, (w * 0.52, h * 1.02), 7.0, w * 0.6, th)
        else:
            out = lay_tape(out, (-w * 0.02, h * 0.9), -6.0, w * 0.55, th)
    return finish(out, size, tape)


def portrait(scene, img, size, pad, sign_w, sign_top, sign_name="sign_name") -> Image.Image:
    """The group along the bottom, the sign hanging over them."""
    w, h = size[0] * SS, size[1] * SS
    top, bottom = scene["top"] - pad[0], scene["feet"] + pad[1]
    crop_w = (bottom - top) * w / h
    x0 = min(max(scene["x"] - crop_w / 2, 0), img.width - crop_w)
    out = crop_to(img, (x0, top, x0 + crop_w, bottom), (w, h))
    out = vignette(out, 0.35)
    sw = sign_w * w
    out = shade(out, (w / 2, sign_top * h + sign_height(sign_name, sw) / 2), sw * 0.8, 0.5)
    out = hang_sign(out, sign_name, w / 2, sign_top * h, sw)
    out = lay_tape(out, (-w * 0.03, h * 0.955), 4.0, w * 1.2, h * 0.032)
    return finish(out, size)


def compose(name: str) -> None:
    scene = SCENES[name]
    img = plate(scene["plate"])
    out_dir = os.path.join(OUT, name)
    os.makedirs(out_dir, exist_ok=True)
    made = {}
    header = landscape(scene, img, (920, 430), 0.68, (300, 260), (0.22, 0.36), 0.1)
    made["header_capsule_920x430"] = header
    made["library_header_920x430"] = header
    made["main_capsule_1232x706"] = landscape(
        scene, img, (1232, 706), 0.66, (460, 420), (0.21, 0.34), 0.09
    )
    small = dict(scene, feet=scene["top"] + 640, **scene.get("small", {}))
    made["small_capsule_462x174"] = landscape(
        small, img, (462, 174), 0.78, (40, 0), (0.28, 0.54), 0.06, "sign_name", False
    )
    made["vertical_capsule_748x896"] = portrait(scene, img, (748, 896), (465, 70), 0.6, 0.035)
    made["library_capsule_600x900"] = portrait(scene, img, (600, 900), (465, 70), 0.68, 0.035)
    if scene["hero"]:
        made["library_hero_3840x1240"] = img.crop((0, scene["hero"][0], 3840, scene["hero"][1]))
    back = crop_to(img, (0, 0, img.width, img.height), (1438, 810)).filter(ImageFilter.GaussianBlur(6))
    made["page_background_1438x810"] = Image.blend(back, Image.new("RGB", back.size, WALNUT), 0.55)
    cx, cy, half = scene["head"]
    made["community_icon_184x184"] = crop_to(img, (cx - half, cy - half, cx + half, cy + half), (184, 184))
    for file, art in made.items():
        art.save(os.path.join(out_dir, file + ".png"))
    sign = badge("sign_full")
    canvas = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    board = sign.crop((0, SIGN_BOARD_TOP - 60, sign.width, sign.height))  # a stub of chain
    s = min(1180 / board.width, 660 / board.height)
    board = board.resize((round(board.width * s), round(board.height * s)), Image.LANCZOS)
    canvas.alpha_composite(board, ((1280 - board.width) // 2, (720 - board.height) // 2))
    canvas.save(os.path.join(out_dir, "library_logo_1280x720.png"))
    print("%s: wrote %d assets to %s" % (name, len(made) + 1, out_dir))


def main() -> None:
    for name in sys.argv[1:] or list(SCENES):
        if os.path.exists(os.path.join(ART, SCENES[name]["plate"] + ".png")):
            compose(name)
        else:
            print("%s: plate %s.png missing - run shot_promo.gd -- art" % (name, SCENES[name]["plate"]))


if __name__ == "__main__":
    main()
