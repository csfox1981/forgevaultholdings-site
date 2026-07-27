# Forge Vault Holdings — scroll-through world

The landing page for **forgevaultholdings.com**. Scroll drives a camera through a
continuous flight: forge → vault → BioPrint → IgniteRegen → workshop → portfolio hall,
with no cuts between scenes.

Not part of the FoxSpringer / peptide platform monorepo.

## Deploy

Static. No build step — the site is plain HTML + a vanilla-JS engine + pre-rendered video.

**Cloudflare Pages settings:**

| Setting | Value |
|---|---|
| Build command | *(none)* |
| Build output directory | `site` |
| Root directory | `/` |

> The output directory **must** be `site`, not the repo root. Pointing it at the root
> would publish `build/` alongside the site.

Largest asset is ~10 MB (Cloudflare Pages' per-file limit is 25 MB).

## Layout

```
site/                     ← everything that gets served
├── index.html            page + brand tokens + dark-theme corrections + footer
├── scrub-engine.js       scroll-scrub engine (vanilla, no dependencies)
└── assets/
    ├── *.webp            scene posters (each clip's own first frame)
    ├── logo-*.webp       portfolio logos
    └── vid/*.mp4         the six camera legs, 1080p

build/                    ← source of truth for regenerating the film (not served)
├── 00_prompts.sh         writes every Higgsfield prompt; edit here, not the .txt files
├── 10_render.sh          stills → legs → encode  (supports from=<scene>)
├── 20_seamcheck.sh       numeric seam continuity check
├── 30_seamsheet.py       visual seam sheet — the one that actually matters
├── still_*.txt           scene prompts
└── leg_*.txt             camera-move prompts
```

Rendered masters and extracted frames (~193 MB) are gitignored — they are reproducible
from the prompts and scripts above.

## How the film works

One continuous forward flight. Leg 0 opens inside the forge; **every later leg starts from
the previous leg's actual last rendered frame**, which is why the seams are invisible. Each
leg also carries its own scene still as an `--end-image` so the camera actually *arrives*
in that scene rather than drifting into generic corridors.

Consequence: inserting a scene invalidates every leg after it. See
[ADDING-A-SCENE.md](ADDING-A-SCENE.md) — it documents the cost, the `from=` resume flag,
and a worked example.

## Regenerating

Requires the [Higgsfield CLI](https://higgsfield.ai) (authenticated, with credits),
`ffmpeg`, `jq`, and Python 3 with Pillow.

```bash
bash build/10_render.sh stills            # review these before spending on video
TIER=standard bash build/10_render.sh legs
python3 build/30_seamsheet.py             # verify seams visually
CRF=23 bash build/10_render.sh encode
```

A full six-scene render is roughly 480 credits at 1080p (~7/still, ~72/leg).

## Local preview

```bash
python3 -m http.server 4321 --directory site
```

Video is loaded as blobs, so scrubbing does not depend on the host supporting HTTP
byte-range requests.
