#!/bin/bash
# ForgeVault scroll-world — architecture A (one continuous forward flight).
#
#   bash build/10_render.sh stills             # step 1: scene stills (parallel)
#   bash build/10_render.sh legs               # step 2: camera legs (SEQUENTIAL — see below)
#   bash build/10_render.sh encode             # step 3: encode for scrubbing + webp posters
#   bash build/10_render.sh all                # all three
#
# Partial runs — for adding or replacing a scene without re-rendering the world:
#   bash build/10_render.sh stills from=aiprint    # just this still (and any after it)
#   bash build/10_render.sh legs   from=aiprint    # re-chain from here to the end
#   bash build/10_render.sh encode from=aiprint
#
# `from=` re-renders that leg and EVERY leg after it. That is not laziness — each leg
# starts from the previous leg's last frame, so inserting or changing a scene invalidates
# every downstream start image. Legs BEFORE the insertion point are untouched and cost
# nothing. See ADDING-A-SCENE.md.
#
# Tier:  TIER=draft (default, seedance_2_0_mini 720p) | TIER=standard (seedance_2_0 1080p)
#
# Why legs are sequential: leg 0 starts from the forge still; every later leg starts
# from the PREVIOUS leg's actual last rendered frame. That frame handoff is the entire
# reason the seams are invisible. It cannot be parallelised.
set -u
export PATH="$PATH:/opt/homebrew/bin"

WORK="$(cd "$(dirname "$0")" && pwd)"
SITE="$(cd "$WORK/.." && pwd)/site"
ASSETS="$SITE/assets"
mkdir -p "$ASSETS/vid"

# The scene order. To add a scene, insert its id here and write build/still_<id>.txt
# and build/leg_<id>.txt (see ADDING-A-SCENE.md), then run with from=<id>.
NAMES="forge vault bioprint igniteregen workshop hall"

# --- optional `from=<name>` -------------------------------------------------
# Splits NAMES into everything before the marker (kept) and the marker onward (rendered).
FROM=""
for arg in "$@"; do case "$arg" in from=*) FROM="${arg#from=}" ;; esac; done
PRE_FROM=""          # the leg immediately before the marker — supplies the start frame
if [ -n "$FROM" ]; then
  case " $NAMES " in
    *" $FROM "*) ;;
    *) echo "from=$FROM is not in NAMES ($NAMES)"; exit 1 ;;
  esac
  _kept=""; _rest=""; _hit=0
  for n in $NAMES; do
    if [ "$n" = "$FROM" ]; then _hit=1; fi
    if [ $_hit -eq 1 ]; then _rest="$_rest $n"; else _kept="$_kept $n"; PRE_FROM="$n"; fi
  done
  NAMES="$(echo $_rest)"
  echo "[from] resuming at '$FROM'; upstream leg = '${PRE_FROM:-<none, chain head>}'"
fi

TIER="${TIER:-draft}"
# Verified against `higgsfield model get <model>` on CLI 1.1.19:
#   seedance_2_0       has `mode` (std|fast), resolution up to 4k
#   seedance_2_0_mini  has NO `mode` param  — passing it errors "Unknown params: mode"
# Both default generate_audio=true; we mute and strip audio anyway, so turn it off.
case "$TIER" in
  standard) VMODEL=seedance_2_0;      VOPTS="--mode std --resolution 1080p" ;;
  draft|*)  VMODEL=seedance_2_0_mini; VOPTS="--resolution 720p"             ;;
esac
VOPTS="$VOPTS --generate-audio=false"
DUR=8
# Encode quality. 20 = reference, ~15 MB/clip. 23 = shipping default, ~10 MB/clip and
# near-indistinguishable on footage this dark. Raise toward 26 if page weight matters more.
CRF="${CRF:-23}"
echo "[tier] $TIER -> $VMODEL $VOPTS   [crf] $CRF"

# --------------------------------------------------------------------------
gen_still () { # name
  local n="$1" try=0
  while [ $try -lt 3 ]; do
    try=$((try+1))
    higgsfield generate create gpt_image_2 \
      --prompt "$(cat "$WORK/still_$n.txt")" \
      --aspect_ratio 3:2 --resolution 2k --quality high \
      --wait --wait-timeout 15m --json > "$WORK/still_$n.json" 2>"$WORK/still_$n.err"
    local url; url=$(jq -r '.[0].result_url // empty' "$WORK/still_$n.json" 2>/dev/null)
    if [ -n "$url" ]; then
      curl -fsSL "$url" -o "$WORK/still_$n.png" && { echo "  still $n ok (try $try)"; return 0; }
    fi
    echo "  still $n retry $try — $(head -c 160 "$WORK/still_$n.err" 2>/dev/null)"
    sleep 5
  done
  echo "  still $n FAILED"; return 1
}

# --------------------------------------------------------------------------
# The leg for scene N travels FROM scene N-1 INTO scene N:
#   --start-image = previous leg's ACTUAL last frame  (locks the seam)
#   --end-image   = this scene's own still            (guarantees it ARRIVES)
# Without the end-image the model drifts into generic corridors and the scene
# stills never appear on screen — verified empirically, see build/compare_endimage.png.
# The skill warns end-images cause pull-back; that applies to wide EXTERIOR
# establishing shots. These end-images are interiors the camera moves INTO, so the
# motion stays forward and the seam stays frame-locked.
gen_leg () { # name  start_png  [end_png]
  local n="$1" start="$2" end="${3:-}" try=0 endflag=""
  [ -n "$end" ] && endflag="--end-image $end"
  while [ $try -lt 3 ]; do
    try=$((try+1))
    higgsfield generate create "$VMODEL" \
      --prompt "$(cat "$WORK/leg_$n.txt")" \
      --start-image "$start" $endflag \
      $VOPTS --aspect_ratio 16:9 --duration "$DUR" \
      --wait --wait-timeout 20m --json > "$WORK/leg_$n.json" 2>"$WORK/leg_$n.err"
    local url; url=$(jq -r '.[0].result_url // empty' "$WORK/leg_$n.json" 2>/dev/null)
    if [ -n "$url" ]; then
      curl -fsSL "$url" -o "$WORK/leg_$n.mp4" && {
        # the handoff frame for the NEXT leg
        ffmpeg -v error -y -sseof -0.15 -i "$WORK/leg_$n.mp4" -frames:v 1 -q:v 2 "$WORK/last_$n.png"
        echo "  leg $n ok (try $try) -> last_$n.png"; return 0; }
    fi
    # NSFW false-positives are common on interiors; a re-roll usually clears it.
    echo "  leg $n retry $try — $(head -c 160 "$WORK/leg_$n.err" 2>/dev/null)"
    sleep 5
  done
  echo "  leg $n FAILED"; return 1
}

# --------------------------------------------------------------------------
do_stills () {
  echo "== stills (parallel) =="
  for n in $NAMES; do gen_still "$n" & done; wait
  echo "Review $WORK/still_*.png for cohesion BEFORE running legs."
}

do_legs () {
  echo "== legs (sequential — frame handoff) =="
  # On a `from=` run the chain does not start at the head — it continues from the
  # last frame of the leg that precedes the marker, which already exists on disk.
  local prev="$PRE_FROM" start="" end=""
  for n in $NAMES; do
    if [ -z "$prev" ]; then
      # leg 0 already opens inside its own scene, so it needs no destination
      start="$WORK/still_$n.png"; end=""
    else
      start="$WORK/last_$prev.png"; end="$WORK/still_$n.png"
    fi
    [ -f "$start" ] || { echo "  MISSING start image $start — stopping"; return 1; }
    echo "  -> leg $n  (start: $(basename "$start")${end:+ , end: $(basename "$end")})"
    gen_leg "$n" "$start" "$end" || { echo "  chain broken at $n"; return 1; }
    prev="$n"
  done
}

do_encode () {
  echo "== encode =="
  for n in $NAMES; do
    [ -f "$WORK/leg_$n.mp4" ] || { echo "  skip $n (no render)"; continue; }
    ffmpeg -v error -y -i "$WORK/leg_$n.mp4" -an -vf "unsharp=5:5:0.8:5:5:0.0" \
      -c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p \
      -g 8 -keyint_min 8 -sc_threshold 0 -movflags +faststart "$ASSETS/vid/$n.mp4"
    echo "  vid/$n.mp4 $(du -h "$ASSETS/vid/$n.mp4" | cut -f1)"
    # poster = the leg's OWN first frame, so the still never mismatches frame 0.
    # NB: homebrew ffmpeg ships without a webp encoder — extract PNG, convert via PIL.
    ffmpeg -v error -y -ss 0 -i "$WORK/leg_$n.mp4" -frames:v 1 \
      -vf "scale=1800:-2" "$WORK/poster_$n.png"
    python3 -c "
from PIL import Image; import sys
im = Image.open(sys.argv[1]).convert('RGB')
im.save(sys.argv[2], 'WEBP', quality=84, method=6)" "$WORK/poster_$n.png" "$ASSETS/$n.webp"
    echo "  $n.webp $(du -h "$ASSETS/$n.webp" | cut -f1)"
  done
}

case "${1:-all}" in
  stills) do_stills ;;
  legs)   do_legs ;;
  encode) do_encode ;;
  all)    do_stills && do_legs && do_encode ;;
  *) echo "usage: $0 {stills|legs|encode|all}"; exit 1 ;;
esac
