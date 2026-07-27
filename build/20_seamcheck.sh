#!/bin/bash
# Verifies each seam: leg N's last frame (fed as leg N+1's start) vs leg N+1's ACTUAL first
# rendered frame. Low rms = the model honoured the start image = invisible seam.
cd "$(dirname "$0")"
export PATH="$PATH:/opt/homebrew/bin"
NAMES="forge vault bioprint igniteregen workshop hall"
prev=""
for n in $NAMES; do
  if [ -n "$prev" ] && [ -f "leg_$n.mp4" ]; then
    ffmpeg -v error -y -ss 0 -i "leg_$n.mp4" -frames:v 1 "first_$n.png"
    python3 - "$prev" "$n" <<'PY'
from PIL import Image, ImageChops
import sys, math
a_name, b_name = sys.argv[1], sys.argv[2]
a = Image.open(f'last_{a_name}.png').convert('RGB')
b = Image.open(f'first_{b_name}.png').convert('RGB').resize(a.size)
d = ImageChops.difference(a, b).convert('L')
h = d.histogram(); n = sum(h)
mean = sum(i*c for i, c in enumerate(h))/n
rms  = math.sqrt(sum(i*i*c for i, c in enumerate(h))/n)
verdict = 'SEAM OK' if rms < 18 else ('MARGINAL' if rms < 30 else 'POP — RE-ROLL')
print(f'  {a_name:>12} -> {b_name:<12} mean {mean:6.2f}  rms {rms:6.2f}   {verdict}')
PY
  fi
  prev="$n"
done
