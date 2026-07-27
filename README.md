# Forge Vault Holdings — scroll-through world

The landing page for **forgevaultholdings.com**. Scroll drives a camera through a
continuous flight: forge → vault → BioPrint → IgniteRegen → workshop → portfolio hall,
with no cuts between scenes.

Not part of the FoxSpringer / peptide platform monorepo.

## Deploy

Static. No build step — the site is plain HTML + a vanilla-JS engine + pre-rendered video.

`www.forgevaultholdings.com` is served by an existing **Cloudflare Worker** with static
assets, named **`snowy-sound-6985`** — *not* a Pages project, and not connected to this
repo. It was originally uploaded by hand through the dashboard.

`wrangler.toml` targets that same Worker, so deploying from here replaces the placeholder
while the custom domain stays attached. No DNS or domain changes required.

```bash
npx wrangler@3 login      # must be the account that owns snowy-sound-6985
npx wrangler@3 deploy
```

> **The `name` in `wrangler.toml` must stay `snowy-sound-6985`.** If it differs — or you
> authenticate to a different Cloudflare account — wrangler creates a *second* Worker and
> the live domain keeps serving the old page.

Wrangler v4 requires Node 22+; this machine has Node 20, hence `wrangler@3`. v3.114
supports `[assets]` (verified). Once on Node 22, plain `npx wrangler deploy` works.

To preview before it goes live:

```bash
npx wrangler@3 versions upload     # returns a preview URL, live domain untouched
npx wrangler@3 versions deploy     # promote once it looks right
```

Limits: 16 files, ~58 MB total, largest 10 MB (Workers allows 20,000 files, 25 MiB each).

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

## Local modifications to scrub-engine.js

`site/scrub-engine.js` is vendored from the scroll-world skill and has **four local
patches** — search for `FORGEVAULT PATCH`. If you re-copy the engine from upstream,
re-apply all of them:

1. **Hold the final segment.** The engine fades every segment out past its end, which is
   right mid-chain because the next one is fading in underneath — but the last has
   nothing behind it and dissolved to empty sky before the footer.
2. **`aria-hidden` on scene videos.** They are decorative; without it a screen reader
   announces each as an unlabelled media element.
3. **`newTab` on CTA buttons.** The engine hard-coded plain anchors, so portfolio links
   replaced the page and lost the visitor's place in the flight.
4. **`tertiary` CTA slot.** The engine supported only primary + secondary; the finale
   needs both portfolio links *and* the About button.

Two engine behaviours are worth knowing but are **not** patched:
- Per-section `cta` works on **any** section, not just the last, despite the doc comment
  in the engine header saying otherwise. The hero's "Our mission" button relies on this.
- The engine never creates anchor targets for section `id`s — sections are scroll
  segments, not DOM anchors. A `href="#bioprint"` silently does nothing. The Portfolio
  button points at `#portfolio`, which is a real `id` on the footer element.

`index.html` loads the engine as `scrub-engine.js?v=2`. **Bump that number whenever the
engine changes**, or browsers and the Cloudflare edge will keep serving the cached copy.

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
