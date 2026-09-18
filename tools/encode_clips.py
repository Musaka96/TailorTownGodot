"""Turn the frame folders recorded by tools/shot_promo.gd (`-- clips`) into looping
animations for the Steam "About This Game" section.

    python tools/encode_clips.py [clip ...]

For every folder in .dev/promo/clips/ (or just the named ones) writes:
  <clip>.webp  1170px wide, 30 fps, lossy — the one to upload (Steam animates WebP
               and it's a fraction of the GIF's size)
  <clip>.gif   780px wide, 15 fps — fallback for places that only take GIF
Steam's limits: <=12 s per animation, keep the whole page under ~15 MB.
"""

import glob
import math
import os
import sys

from PIL import Image

CLIPS_DIR = os.path.join(".dev", "promo", "clips")
FPS = 30
# Clips re-timed on output (fewer frames = smaller file). The mirror reel is already
# sped up and changes every frame, so 20 fps keeps it well inside the page budget; the
# v2 benches turn the camera with the tool, so they re-time the same way.
OUT_FPS = {"mirror": 20, "cutting": 20, "sewing": 20}
QUALITY = {"mirror": 70, "cutting": 72, "sewing": 72}
WEBP_QUALITY = 78
GIF_WIDTH = 780
GIF_STEP = 2  # every 2nd frame -> 15 fps


def encode(name: str) -> None:
    frames_dir = os.path.join(CLIPS_DIR, name)
    paths = sorted(glob.glob(os.path.join(frames_dir, "f*.jpg")))
    if not paths:
        print(f"{name}: no frames, skipped")
        return
    fps = OUT_FPS.get(name, FPS)
    count = round(len(paths) * fps / FPS)
    paths = [paths[min(round(i * FPS / fps), len(paths) - 1)] for i in range(count)]
    frames = [Image.open(p).convert("RGB") for p in paths]

    webp = os.path.join(CLIPS_DIR, f"{name}.webp")
    frames[0].save(
        webp,
        save_all=True,
        append_images=frames[1:],
        duration=round(1000 / fps),
        loop=0,
        quality=QUALITY.get(name, WEBP_QUALITY),
        method=6,
    )

    w, h = frames[0].size
    size = (GIF_WIDTH, round(h * GIF_WIDTH / w))
    step = max(1, math.ceil(fps * GIF_STEP / FPS))  # GIF stays at <= 15 fps
    small = [f.resize(size, Image.LANCZOS) for f in frames[::step]]
    # One shared palette (built from a spread of frames) so colours don't flicker.
    probe = Image.new("RGB", (size[0], size[1] * 4))
    for i, f in enumerate(small[:: max(1, len(small) // 4)][:4]):
        probe.paste(f, (0, size[1] * i))
    palette = probe.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    gif_frames = [f.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for f in small]
    gif = os.path.join(CLIPS_DIR, f"{name}.gif")
    gif_frames[0].save(
        gif,
        save_all=True,
        append_images=gif_frames[1:],
        duration=round(1000 * step / fps),
        loop=0,
        optimize=True,
    )

    secs = len(frames) / fps
    print(
        f"{name}: {secs:.1f}s  webp {os.path.getsize(webp) / 1e6:.1f} MB"
        f"  gif {os.path.getsize(gif) / 1e6:.1f} MB"
    )


def main() -> None:
    names = sys.argv[1:] or sorted(
        d for d in os.listdir(CLIPS_DIR) if os.path.isdir(os.path.join(CLIPS_DIR, d))
    )
    for name in names:
        encode(name)


if __name__ == "__main__":
    main()
