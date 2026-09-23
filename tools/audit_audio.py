"""Measure every wav in assets/audio for the things that make a sound feel harsh."""
import glob
import os
import sys
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def load(path):
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        ch = w.getnchannels()
        width = w.getsampwidth()
        n = w.getnframes()
        raw = w.readframes(n)
    if width == 2:
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    elif width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        x = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        x = np.where(x >= 1 << 23, x - (1 << 24), x).astype(np.float64) / (1 << 23)
    elif width == 1:
        x = (np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128) / 128.0
    else:
        x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return rate, ch, width * 8, x


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def stats(path):
    rate, ch, bits, x = load(path)
    n = len(x)
    dur = n / rate
    peak = np.abs(x).max() if n else 0
    rms = np.sqrt(np.mean(x ** 2)) if n else 0
    # clipping: consecutive samples pinned at |x| >= 0.99
    clip = int(np.sum(np.abs(x) >= 0.99))
    # spectrum
    win = x[: min(n, rate * 8)]
    spec = np.abs(np.fft.rfft(win * np.hanning(len(win)))) ** 2 if len(win) > 16 else np.zeros(2)
    freqs = np.fft.rfftfreq(len(win), 1 / rate) if len(win) > 16 else np.array([0, 1])
    tot = spec.sum() + 1e-12
    centroid = float((freqs * spec).sum() / tot)
    hi = float(spec[freqs > 4000].sum() / tot)
    vhi = float(spec[freqs > 8000].sum() / tot)
    # attack: time to reach 90% of peak
    env = np.abs(x)
    i90 = int(np.argmax(env >= 0.9 * peak)) if peak > 0 else 0
    attack_ms = 1000 * i90 / rate
    # leading/trailing silence below -50 dBFS
    thr = 10 ** (-50 / 20)
    loud = np.where(env > thr)[0]
    lead = 1000 * loud[0] / rate if len(loud) else dur * 1000
    trail = 1000 * (n - 1 - loud[-1]) / rate if len(loud) else 0
    # abrupt end: level in the last 5 ms
    tail = x[-max(1, rate // 200):]
    tail_db = db(np.sqrt(np.mean(tail ** 2)))
    dc = float(np.mean(x))
    return dict(
        file=os.path.basename(path), rate=rate, ch=ch, bits=bits, dur=dur, peak=db(peak), rms=db(rms),
        crest=db(peak) - db(rms), clip=clip, centroid=centroid, hi4k=hi, hi8k=vhi, attack_ms=attack_ms,
        lead_ms=lead, trail_ms=trail, tail_db=tail_db, dc=dc,
    )


rows = []
for p in sorted(glob.glob(os.path.join(ROOT, "*.wav"))):
    try:
        rows.append(stats(p))
    except Exception as e:  # noqa
        print("ERR", p, e)

hdr = "%-26s %6s %2s %3s %6s %6s %6s %5s %5s %6s %5s %5s %6s %6s %6s %6s"
print(hdr % ("file", "rate", "ch", "bit", "dur", "peak", "rms", "crest", "clip", "cent", ">4k", ">8k", "atk", "lead", "trail", "tail"))
for r in rows:
    print(
        hdr
        % (
            r["file"][:26], r["rate"], r["ch"], r["bits"], "%.2f" % r["dur"], "%.1f" % r["peak"], "%.1f" % r["rms"],
            "%.0f" % r["crest"], r["clip"], "%.0f" % r["centroid"], "%.2f" % r["hi4k"], "%.2f" % r["hi8k"],
            "%.0f" % r["attack_ms"], "%.0f" % r["lead_ms"], "%.0f" % r["trail_ms"], "%.0f" % r["tail_db"],
        )
    )
