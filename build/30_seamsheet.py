#!/usr/bin/env python3
"""Builds a visual seam sheet for the chain.

For each adjacent pair it shows, side by side:
  - leg N's LAST frame   (what we fed forward as the next leg's start image)
  - leg N+1's FIRST frame (what the model actually rendered)
  - an amplified difference map

If the chain is frame-locked those two frames are near-identical, the diff map is
near-black, and the seam is invisible on the page. A bright diff map with visible
STRUCTURE (edges, displaced geometry) means a real pop -> re-roll that leg.
A diff that is only a soft glow//exposure shift is fine; the engine crossfade hides it.
"""
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance

HERE = Path(__file__).parent
NAMES = "forge vault bioprint igniteregen workshop hall".split()
SCALE = 0.26


def frame(video: Path, out: Path, last: bool) -> bool:
    if not video.exists():
        return False
    cmd = ["ffmpeg", "-v", "error", "-y"]
    cmd += ["-sseof", "-0.15", "-i", str(video)] if last else ["-ss", "0", "-i", str(video)]
    cmd += ["-frames:v", "1", str(out)]
    subprocess.run(cmd, check=True)
    return True


def main() -> int:
    pairs = []
    for a, b in zip(NAMES, NAMES[1:]):
        va, vb = HERE / f"leg_{a}.mp4", HERE / f"leg_{b}.mp4"
        fa, fb = HERE / f"_seam_{a}_last.png", HERE / f"_seam_{b}_first.png"
        if not (frame(va, fa, last=True) and frame(vb, fb, last=False)):
            print(f"  skip {a}->{b} (missing render)")
            continue
        ia = Image.open(fa).convert("RGB")
        ib = Image.open(fb).convert("RGB").resize(ia.size)
        diff = ImageChops.difference(ia, ib)
        hist = diff.convert("L").histogram()
        n = sum(hist)
        rms = math.sqrt(sum(i * i * c for i, c in enumerate(hist)) / n)
        pairs.append((a, b, ia, ib, ImageEnhance.Brightness(diff).enhance(4.0), rms))

    if not pairs:
        print("no seams to render")
        return 1

    w, h = pairs[0][2].size
    W, H = int(w * SCALE), int(h * SCALE)
    pad, head = 6, 26
    sheet = Image.new("RGB", (W * 3 + pad * 4, (H + head + pad) * len(pairs) + pad), (8, 6, 26))
    d = ImageDraw.Draw(sheet)

    for r, (a, b, ia, ib, dm, rms) in enumerate(pairs):
        y = pad + r * (H + head + pad)
        verdict = "LOCKED" if rms < 18 else ("SOFT DRIFT" if rms < 30 else "POP - RE-ROLL")
        colour = (120, 230, 140) if rms < 18 else ((255, 200, 80) if rms < 30 else (255, 90, 90))
        d.text((pad, y + 6), f"{a}  ->  {b}     rms {rms:5.2f}   {verdict}", fill=colour)
        for c, im in enumerate((ia, ib, dm)):
            sheet.paste(im.resize((W, H)), (pad + c * (W + pad), y + head))
        for c, lbl in enumerate((f"{a} LAST", f"{b} FIRST", "diff x4")):
            d.text((pad + c * (W + pad) + 5, y + head + 4), lbl, fill=(230, 240, 255))
        print(f"  {a:>12} -> {b:<12} rms {rms:6.2f}  {verdict}")

    out = HERE / "seam_sheet.png"
    sheet.save(out)
    print(f"\nsaved {out}  {sheet.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
