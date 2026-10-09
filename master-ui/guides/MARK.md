# The mark

Every app in the family has one mark: an ink square carrying a paper diagram of **what the app acts on**. It is the app icon, the title-bar wordmark, the favicon and the installer icon.

The marks are siblings because they share a square, two fills and a construction grammar — **not** because they share a shape. Each one is a different picture. If two apps in the family could be confused at 16px, at least one of them is wrong.

## 1. The law that this replaces

Early marks were "five paper bars whose heights spell the app's initial". That was a mistake and it produced the failure this guide exists to prevent: Music Master `0.9 0.45 0.7 0.45 0.9` and Visual Master `0.9 0.6 0.3 0.6 0.9` are both a symmetrical valley of five bars, indistinguishable in a dock or a task bar, and neither depicts anything. Letters do not survive being drawn as bar heights, and an initial says nothing about what an app does.

**Do not spell the initial. Draw the subject.**

## 2. The brief

Answer these three, in writing, before you open an editor.

1. **What noun does this app act on?** Not the technology, not the verb — the thing the user works with. Music Master: a song, heard as levels. Visual Master: a picture. Sort Master: an ordered list. A time tracker: elapsed time.
2. **What is the most reduced diagram of that noun?** The version a signwriter would cut from one sheet of paper. Remove everything that is not load-bearing; if removing a part does not change what it says, it was decoration.
3. **Does it collide with a sibling?** Put it next to every other mark in the family at 16px. If the silhouettes rhyme, change the axis: vertical vs horizontal, solid vs framed, symmetrical vs weighted to one side.

## 3. The grammar

These constraints are what make the marks read as one family. They are not style preferences; a mark that breaks them will not sit next to the others.

| Rule | Value |
|---|---|
| Canvas | 100×100 `viewBox`, ink square, full bleed, no radius, no border, no padding around the square itself |
| Field | geometry lives inside 68×68 — `x`, `y` from 16 to 84 |
| Fills | paper on ink. No alpha, no grey, no stroke colour, no gradient |
| Grid | snap coordinates to even numbers (the parametric `bars()` constructor is the one exception) |
| Weight | one element weight per mark — every bar, rule and frame edge the same thickness |
| Geometry | straight lines, 45° diagonals, full circles. No arbitrary curves, no arcs under 90°, no rounded joins |
| Elements | 2–5. Four is usually one too many |
| Minimum element | 8 units (1.3px at 16px). Below 12, the silhouette has to carry the mark on its own |
| Letterforms | none — unless letters are literally the subject (a typography app) |
| Centring | optical, not mathematical. A heavy base wants 2–4 units more room above than below |

Dark mode needs no separate artwork: the shapes are `fill-ink` / `fill-paper`, so the mark inverts with the theme. Exported icon files are always the light version (paper on an ink square) — a desktop icon does not follow the app's theme.

## 4. The tests

A mark ships only when it passes all four.

1. **16px test.** Render at 16, 20 and 32px. Every element must still be separable. Most failures are here: an element under 8 units, or five elements where three would do.
2. **Cover test.** Hide the wordmark. Can someone who has not seen the app name a plausible subject? "Sound", "a picture", "a list" is a pass. "A shape" is a fail.
3. **Sibling test.** Line it up with the rest of the family at 16px. Different silhouette, different axis, different mass distribution.
4. **Photocopy test.** It is already two-tone, so this is about mass: squint. The mark should hold together as one gesture, not scatter into parts.

## 5. Worked examples

All four are in `../react/Mark.tsx` as `MARKS`, with their coordinates.

**`levels` — Music Master.** Five vertical bars, heights `0.9 0.45 0.7 0.45 0.9`, sitting on the baseline. Sound drawn as a meter. This is the origin mark and the one case where bars are right: the subject genuinely is levels. Built with `bars()`.

**`frame` — Visual Master.** A paper frame (68×56 with a 52×40 ink hole) containing a 45° horizon — `24,70 → 46,48 → 68,70`. The universal picture diagram: a framed image with something in it. Two masses, no detail to lose at 16px, and it cannot be mistaken for bars.

**`list` — Sort Master.** Three horizontal bars, left-aligned, widths `68 46 24`, height 16, gap 10 — the bars and gaps fill the 68 field exactly. An ordered list. It shares "bars" with Music Master but on the other axis, left-weighted rather than symmetrical, so the two never read the same. An earlier version used four 10-unit bars with 9-unit gaps; at 16px the gaps closed up and it turned into a solid block, which is the failure mode the minimum-element rule exists to catch.

**`page` — a document app.** A rectangle with a 45° corner fold (`22,16 → 62,16 → 78,32 → 78,84 → 22,84`) and two ink rules cut into it for text.

**`dial` — a time app.** A paper disc with an ink disc inside it (a ring), plus two hands at 12 and 3. The only sanctioned circle: it is the whole subject, not an ornament.

## 6. Building one

```tsx
import { Mark, MARKS, bars, markToSvg } from './master-ui/react/Mark'

// From the registry
<Mark shape="frame" className="size-5" />

// One-off, declared inline
<Mark
  className="size-5"
  shape={{
    subject: 'a stack of layers',
    shapes: [
      { poly: [50, 18, 82, 36, 50, 54, 18, 36] },
      { poly: [50, 58, 66, 67, 50, 76, 34, 67] }
    ]
  }}
/>
```

Shapes are drawn in order. `ink: true` cuts a hole in what is already there — that is how a frame or a ring is made. Add your app's mark to `MARKS` with a `subject` string so the next person knows what it depicts.

## 7. Exporting the icon files

`markToSvg()` returns a standalone SVG with literal black and white (no CSS variables), which is what icon tooling needs.

```js
import { writeFileSync } from 'node:fs'
import { markToSvg } from './master-ui/react/Mark.js'
writeFileSync('build/icon.svg', markToSvg('frame', { size: 1024 }))
```

Then, with ImageMagick (or any rasteriser):

```bash
magick -background none build/icon.svg -resize 512x512 build/icon.png
magick build/icon.png -define icon:auto-resize=256,128,64,48,32,16 build/icon.ico
```

What each target needs:

| Target | File | Notes |
|---|---|---|
| electron-builder (Windows) | `build/icon.ico` | multi-size, 16 through 256 |
| electron-builder (macOS) | `build/icon.icns` | 1024 source |
| electron-builder (Linux) | `build/icon.png` | 512×512 |
| Web favicon | `favicon.svg` + `favicon.ico` | the SVG is the same file; no `prefers-color-scheme` variant |
| Installer / store art | 512 or 1024 PNG | the mark alone, never the mark plus the name |

The mark never gets a rounded container, a shadow, a background colour, a gradient sheen or a "macOS squircle" treatment. The square is the container. Windows and macOS will mask it themselves; that is fine and expected.

## 8. Never

- A letter drawn as bars, or a letter at all
- A variation on a sibling's mark (recolour, mirror, reorder — the family is not a colourway set)
- A lucide icon used as the app mark
- Colour of any kind, including a single accent element
- Detail that dies at 16px: thin rules, small squares, more than five elements, text
- Rounded corners, shadows, gradients, outlines, 3D, perspective, isometric
- Emoji or a rendered glyph from a font
- An abstract shape chosen because it looks nice — the mark has to mean the subject
