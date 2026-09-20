"""Turn the frames from tools/shot_renovation_gif.gd into a captioned GIF.

    godot --path . --script res://tools/shot_renovation_gif.gd     (NOT headless)
    python tools/make_renovation_gif.py [out.gif] [width]

Every frame is one step of the renovation; its caption (the job, and how far along it is)
is drawn on a strip under the picture and its hold time comes from the manifest. One
palette is shared by all frames and nothing is dithered, so still areas don't shimmer.
"""
import glob
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = ".dev/reno_gif"
OUT = sys.argv[1] if len(sys.argv) > 1 else "docs/media/renovation_greybox.gif"
WIDTH = int(sys.argv[2]) if len(sys.argv) > 2 else 800
STRIP = 44  # caption strip height, px
PAPER = (247, 240, 225)
INK = (58, 44, 36)
BAR_BG = (214, 200, 176)
BAR_FG = (150, 96, 52)


def font(size):
    for path in sorted(glob.glob("assets/fonts/*.ttf")):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    steps = json.load(open(os.path.join(SRC, "manifest.json"), encoding="utf-8"))
    face = font(22)
    frames = []
    for i, step in enumerate(steps):
        shot = Image.open(os.path.join(SRC, step["file"])).convert("RGB")
        height = round(shot.height * WIDTH / shot.width)
        shot = shot.resize((WIDTH, height), Image.LANCZOS)
        page = Image.new("RGB", (WIDTH, height + STRIP), PAPER)
        page.paste(shot, (0, 0))
        draw = ImageDraw.Draw(page)
        draw.text((14, height + STRIP // 2), step["caption"], font=face, fill=INK, anchor="lm")
        # how far through the whole job we are
        x0, x1, y = WIDTH - 214, WIDTH - 14, height + STRIP // 2
        draw.rounded_rectangle((x0, y - 4, x1, y + 4), 4, fill=BAR_BG)
        done = x0 + round((x1 - x0) * i / max(len(steps) - 1, 1))
        if done > x0 + 8:
            draw.rounded_rectangle((x0, y - 4, done, y + 4), 4, fill=BAR_FG)
        frames.append(page)

    # one palette for every frame, taken from a sheet of samples across the whole run
    picks = frames[:: max(len(frames) // 8, 1)]
    sheet = Image.new("RGB", (WIDTH, picks[0].height * len(picks)))
    for n, pick in enumerate(picks):
        sheet.paste(pick, (0, n * pick.height))
    palette = sheet.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    paletted = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]

    os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
    paletted[0].save(
        OUT,
        save_all=True,
        append_images=paletted[1:],
        duration=[int(s["ms"]) for s in steps],
        loop=0,
        optimize=True,
        disposal=1,
    )
    secs = sum(int(s["ms"]) for s in steps) / 1000.0
    print("%s: %d frames, %.1f s, %.2f MB" % (OUT, len(steps), secs, os.path.getsize(OUT) / 1e6))


main()
