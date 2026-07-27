# Adding a new scene to the ForgeVault world

Worked example: adding **AI Print Assistant** to the portfolio.

---

## The one rule that determines cost

The film is a single continuous camera flight. Leg 0 opens inside the forge; **every later
leg starts from the previous leg's actual last rendered frame**. That frame handoff is the
only reason the seams are invisible.

The consequence: **inserting a scene invalidates every leg after it.** Not because the
tooling is lazy — the downstream legs literally begin on a frame that no longer exists in
the chain. Legs *before* the insertion point are untouched and cost nothing.

```
forge → vault → bioprint → igniteregen → workshop → hall
                                ▲
                     insert aiprint here
                     ├── forge, vault, bioprint, igniteregen   unchanged, free
                     └── aiprint, workshop, hall               must re-render
```

### Cost by insertion point

| Insert before | Legs to re-render | Approx credits |
|---|---|---|
| `workshop` (with the other apps — **recommended**) | aiprint, workshop, hall | ~225 |
| `hall` (after "What's Next") | aiprint, hall | ~150 |
| after `hall` (new finale) | aiprint only | ~80 |

At ~7 credits per still and ~72 per 1080p leg. The recommended slot costs more because it
reads correctly: portfolio apps grouped together, "What's Next" and the closing hall last.
Putting a shipped product *after* "What's Next" saves ~75 credits and reads wrong.

---

## Steps

### 1. Add the scene id to the order

In `build/10_render.sh`:

```bash
NAMES="forge vault bioprint igniteregen aiprint workshop hall"
```

### 2. Write the two prompt files

Add to `build/00_prompts.sh`, keeping `$PREAMBLE` and `$TAIL` **byte-identical** — that
shared preamble is the entire reason the world looks like one place.

```bash
# ---- AI PRINT ASSISTANT ----------------------------------------------------
still aiprint 'A precision additive-fabrication bay, a large glass-walled print chamber at the centre holding a partially formed geometric object suspended mid-build on a lit platform, holographic wireframe meshes floating alongside it showing the same form being refined and optimised, tool heads and material spools racked along the walls under cold blue light.'
leg aiprint 'pushing in slowly toward the glass print chamber until the forming object nearly fills the frame, then easing gently back out' 'the fabrication bay' 'the half-built object suspended in the print chamber' 'a lit doorway beyond the material racks'
```

Then regenerate: `bash build/00_prompts.sh`

Rules that matter for the prompt:
- **Centre the focal subject.** The page renders every clip `object-fit: cover`, so
  anything at the far edges is cropped on narrower viewports.
- **Keep `empty and unoccupied, no people, no figures`** (it's already in `$PREAMBLE`).
  It suppresses Seedance's NSFW false-positives on interiors and keeps the RUO discipline
  IgniteRegen's brief requires.
- **Never remove the two bolded motion clauses** in the leg template ("Continue the same
  slow, steady forward glide" / "In the final second, settle back into..."). They are the
  handoff contract; without them a leg can end mid-motion and poison the next one.

### 3. Render

```bash
bash build/10_render.sh stills from=aiprint
```

Look at `build/still_aiprint.png` before spending on video — it must sit convincingly
beside the other five. If it drifts in palette or light, re-roll it (optionally passing an
approved scene as `--image` to lock the style).

```bash
TIER=standard bash build/10_render.sh legs from=aiprint
```

This re-chains `aiprint → workshop → hall`, starting from `build/last_igniteregen.png`,
which already exists. It runs sequentially and takes ~5 min per leg.

### 4. Verify the seams

```bash
python3 build/30_seamsheet.py
```

Open `build/seam_sheet.png`. In each row the left and middle images must be
**geometrically identical** — same architecture, same perspective. Ignore the `rms`
number; it tracks how detailed the scene is, not how good the seam is. A dense scene
scores higher than a dark one at identical quality. Judge the pictures: thin edge outlines
in the diff map are fine (re-render noise), doubled or displaced structures are a real pop.

### 5. Encode

```bash
bash build/10_render.sh encode from=aiprint
```

### 6. Wire it into the page

In `site/index.html`, add the section **in the same position** as in `NAMES`:

```js
{
  id: 'aiprint', label: 'AI Print Assistant',
  still: 'assets/aiprint.webp',
  clip:  'assets/vid/aiprint.mp4',
  accent: '#3FDFFF',
  scroll: 1.6, linger: 0.4,
  eyebrow: 'Portfolio — in development',
  title: 'Better models, automatically.',
  body: 'Upload a model and get it print-ready — geometry cleaned, supports resolved, settings tuned to your machine.',
  tags: ['In development'],
},
```

Order in `sections[]` must match `NAMES` exactly, or clips play against the wrong copy.

`connectors: []` stays empty — this architecture has no connector clips.

Add it to the footer portfolio grid too, once it has a public URL.

---

## Verify before you ship

Serve the site and check, in the browser console:

```js
[...document.querySelectorAll('video')].map(v => v.seekable.length && v.seekable.end(0))
```

Every entry must be non-zero. A `0` means the clip is being served over plain HTTP without
byte-range support and will freeze at frame 0 — the engine loads clips as blobs
specifically to avoid this, so a zero means something changed in how assets are served.

Then scroll the whole page and confirm exactly one clip sits at full opacity at a time.
Note the engine animates the **parent wrapper's** opacity, not the `<video>` element's —
reading `video.style.opacity` will mislead you.

---

## When the scene count grows past ~8

Each 8s 1080p leg is ~13–15 MB. At six scenes the page carries 83 MB of video. Two levers
before adding many more:

- Re-encode at `crf 23` (~10 MB/clip, ~35% lighter, near-invisible difference on footage
  this dark). Costs no credits — the encode step re-runs on masters you already have.
- Shorten transit legs to 5s. Dwell scenes (`scroll`/`linger` in the config) carry the
  pacing; the camera does not need 8s to cross a corridor.
