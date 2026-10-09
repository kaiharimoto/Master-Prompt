# Master UI

The design language of the Master family of apps (Music Master and its siblings). Brutalist Swiss Minimal: paper and ink, nothing else. This document is the specification. An LLM or an engineer given only this file must be able to build a screen that sits next to Music Master without a seam.

**How to use this file**

- If you are an LLM applying this to a project: read the whole file once, then keep §15 (Do / Don't) and §16 (Checklist) in mind while you work. The exact values in §2–§7 are not suggestions; copy them. When something is not covered, derive it from the laws in §1 and ask "what would a Swiss typographer do with one ink and one paper".
- If you are an engineer: §2–§7 are the spec; `css/master-ui.css` and `css/master-ui.components.css` are the implementation; `react/` is a reference build; `examples/specimen.html` shows every part in every state. `guides/` go deeper on layout, components, motion, voice, fonts and converting an existing app.
- Run `master-ui check <dir>` to catch anything that breaks the laws.

---

## 1. Philosophy

The system is built from as little as possible: two fills, one typeface, one easing, straight edges. Everything a designer would normally reach for colour to do — state, emphasis, hierarchy, identity — is done with inversion, hatching, weight, size and motion instead. The result feels like a printed Swiss poster that happens to be interactive.

### The laws

1. **Two fills.** Paper (`#ffffff`) and ink (`#000000`). Secondary text and rules are ink at 70 / 45 / 25 / 12 / 6 percent alpha. There is no third colour, no accent, no brand colour, no grey palette. Not for errors, not for success, not for links, not for charts.
2. **Zero radius.** Nothing is ever rounded. Not a button, not a tile, not a scrollbar thumb, not a checkbox, not a toast. `* { border-radius: 0 !important }` is the safety net.
3. **No depth tricks.** No shadows, no blur, no gradients (except the 45° hatch and two 1px utility gradients), no glassmorphism, no elevation. Layers are separated by rules and by the paper overlay at 85%.
4. **Emphasis is inversion, hatching or motion.** Selected = inverted (ink block, paper text). Running = animated hatch or a breathing 6px square. Danger = weight and a `✕` glyph. Never a colour.
5. **Type does the work.** Hierarchy comes from a strict scale (96 / 56 / 32 / 20 / 14 / 12 / 11) and from three treatments: tight-tracked display, micro caps labels, tabular mono numerals. Pages are numbered `01`, `02`.
6. **Rules, not gaps.** Sections, rows, grid cells and panes are divided by 1px lines, not by whitespace or cards. Whitespace is used inside a region; lines separate regions.
7. **Light is default; dark is the exact inversion.** Swap `--paper` and `--ink`; nothing else changes. No tinted darks, no dimmed whites.
8. **Quiet voice.** Sentence case. Micro caps for labels. No exclamation marks, no emoji, no marketing. Numbers first, units spaced, estimates with `≈`.

### What it is not

Not "dark mode with white text". Not minimalism with soft greys and 8px radii. Not brutalism with clashing colours and raw HTML. Not a terminal aesthetic (the mono face is for numbers, not prose). If a screen could be mistaken for a Linear, Notion, Vercel or Material app, it is wrong.

### The family test

Put the screen beside Music Master. Same paper, same ink, same rules, same type, same 6px breathing square, same `01` numerals, same `→` arrows. If there is a seam — a rounded corner, a coloured badge, a drop shadow, a Title Case button, an exclamation mark — fix it.

---

## 2. Tokens

CSS custom properties on `:root`. Theme via `data-theme="light|dark"` on `<html>`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `--paper` | `#ffffff` | `#000000` | every background |
| `--ink` | `#000000` | `#ffffff` | text, rules, fills, inversion |
| `--ink-70` | `rgba(0,0,0,.7)` | `rgba(255,255,255,.7)` | secondary text, labels |
| `--ink-45` | `rgba(0,0,0,.60)` | `rgba(255,255,255,.50)` | secondary text (meta, stat lines, hints, numerals), placeholders, inactive tabs, **form-field borders at rest**. The name is historical: at .45 it was 3.4:1 on paper and failed WCAG 1.4.3; .60 / .50 give 5.7:1 / 5.3:1 (Music Master changed this first, the kit follows) |
| `--ink-25` | `rgba(0,0,0,.25)` | `rgba(255,255,255,.25)` | field borders, unplayed bars, scrollbar thumb |
| `--ink-12` | `rgba(0,0,0,.12)` | `rgba(255,255,255,.12)` | hairline rules between rows, progress track |
| `--ink-06` | `rgba(0,0,0,.06)` | `rgba(255,255,255,.06)` | hover wash, skeleton base |
| `--overlay` | `rgba(255,255,255,.85)` | `rgba(0,0,0,.85)` | behind dialogs and drawers |

| Token | Value | Use |
|---|---|---|
| `--rule` | `1px solid var(--ink-12)` | hairline |
| `--rule-strong` | `2px solid var(--ink)` | the footer/transport bar and sticky action bars; nowhere else |
| `--ease` | `cubic-bezier(0.2, 0, 0, 1)` | the only easing |
| `--dur-fast` | `120ms` | colour, background, chevrons, arrows |
| `--dur` | `180ms` | link underline, drawers |
| `--dur-slow` | `320ms` | glyph transforms; the largest transition |
| `--shell-top-h` | `40px` | title bar |
| `--shell-bottom-h` | `88px` | transport / footer bar |
| `--sidebar-w` | `232px` | index rail |
| `--font-sans` | `'Neue Haas Grotesk Display Pro', 'Inter Variable', 'Helvetica Neue', Helvetica, Arial, sans-serif` | |
| `--font-mono` | `'Cascadia Mono', Consolas, 'JetBrains Mono', ui-monospace, monospace` | |
| `--s-1 … --s-16` | 4 8 12 16 20 24 32 40 48 64 | spacing scale |
| `--z-sticky … --z-palette` | 10 30 40 50 60 70 | sticky bars · footer · title bar & drawer backdrop · dialogs/menus/drawer · tooltips · command palette |

Radius tokens: all `0`. Shadow tokens: all `none`. There is no spacing outside the scale; there are no colour tokens beyond this table. Tailwind users get `bg-paper text-ink text-ink-45 border-ink-12 bg-overlay ease-swiss` from `css/master-ui.tailwind.css`.

---

## 3. Typography

**Body**: `font-family: var(--font-sans); font-size: 14px; line-height: 1.4; font-feature-settings: 'ss01', 'cv11'; font-variant-numeric: tabular-nums; -webkit-font-smoothing: antialiased; user-select: none`. Text is selectable only in inputs, editors and elements marked `.selectable` (logs, lyrics, prose); the chrome is not.

**Fonts**: Neue Haas Grotesk Display Pro when installed locally; Inter Variable bundled as the fallback (`@fontsource-variable/inter`). Both get `ss01` (single-storey a) and `cv11`. See `guides/FONTS.md`.

### Scale

| Class | Size | Weight | Tracking | Leading | Use |
|---|---|---|---|---|---|
| `.t-display-xl` | 96px | 700 | −0.035em | 0.88 | one word on a welcome or install screen |
| `.t-display` | 56px | 700 | −0.03em | 0.92 | empty-state sentence, install state (`Ready.`), the biggest thing on a page |
| `.t-h1` | 32px | 500 | −0.02em | 1.05 | page title (with a numeral) |
| `.t-h2` | 20px | 500 | −0.01em | 1.15 | section title, rail item, dialog title, card name |
| `.t-body` | 14px | 400 | 0 | 1.45 | prose |
| `.t-small` | 12px | 400 | 0 | 1.4 | secondary lines under a title |
| `.t-micro` | 11px | 500 | +0.08em | 1.2 | **uppercase**. labels, kickers, button text, tabs, badges, chips, stat labels |
| `.t-mono` | inherit | 400 | 0 | — | `--font-mono` + tabular-nums. every number, index, duration, seed, path, shortcut |

Inline sizes used in components: 15px (feed row title, palette input), 13px (rows, menus, dialogs' descriptions, selects), 12px (meta line under a title, tooltips), 11px (helper text, numerals), 10px (Kbd, segmented-sm, score chips), 9px (section labels on a waveform).

### Rules

- **Micro caps** are the label voice. A field label, a section kicker (`Latest`, `Up next`), a status word (`Playing`, `Queued`), a button. When a number or user text sits inside a micro-caps element, wrap it so it keeps its case: `<span class="t-mono normal">2:34</span>` (`normal-case tracking-normal` in Tailwind).
- **Mono** is for data, never prose. Durations, percentages, counts, seeds, file paths, keyboard keys, `01` indexes, stage glyphs. Mono text is usually 11px and `--ink-45` or `--ink-70`.
- **Negative tracking** on everything 20px and up; the bigger, the tighter. **Positive tracking** only on micro caps and button labels (+0.08em) and star ratings (+0.1em).
- **Weights**: 400 body, 500 headings/labels/buttons, 700 display/wordmark/tiles. 600 does not exist in the app (it is reserved for the guest room). Never 800/900, never thin.
- **Numerals**: pages, sections, rail items, list rows, setup steps and stage lists are indexed `01`, `02`… in `.t-mono` 11px `--ink-45` (`Numeral`). It is the family's signature.
- **Line length**: prose blocks are capped (`max-w-xs/sm/md/lg` — 320/384/448/512px). Empty-state titles cap at 672px.
- No italics in the UI. No underlines except the sliding link underline. No text shadows. No letter-spacing on body text.

---

## 4. Layout and shell

### App shell (desktop)

```
┌──────────────────────────────────────────────────────────┐ 40px  title bar   z40  border-b ink   drag-region
│ ■ MUSIC MASTER   [● Generating 57%]   [Search Ctrl K] ● Engine ready │
├──────────┬───────────────────────────────────────────────┤
│ 01 Create│                                               │
│ 02 Covers│   main  (pages swap with a 100ms fade)        │  index rail 232px, border-r ink
│ 03 …     │                                               │  optional guest panel on the right, border-l ink
│          │                                               │
│ Settings │                                               │
├──────────┴───────────────────────────────────────────────┤ 88px  footer / transport   z30  border-t 2px ink
│ [tile] Title      ◁ ▶ ▷   0:42 ▁▂▃▅▂▁ 3:12       ─── ♪  │
└──────────────────────────────────────────────────────────┘
```

- **Title bar** (`.shell-top`, 40px, `border-b 1px ink`, `-webkit-app-region: drag`): wordmark left; then a running-job pill (`● title 57%`, `hover-invert`); right side has update pills, the search trigger (`Search` + `Kbd Ctrl K`, ink-25 border, ink-45 text, both go to ink on hover) and the system status in micro caps with a 6px square that breathes while something runs (`Engine ready · YuE2-3B · 4.2 / 24 GB`, joined by ` · `). In Electron: `titleBarStyle: 'hidden'`, `titleBarOverlay: { color: paper, symbolColor: ink, height: 40 }`, reserve 150px right padding on Windows, and re-set the overlay + `backgroundColor` on theme change.
- **Index rail** (`.rail`, 232px, `border-r 1px ink`): top block is the page list, each row 56px (`h-14`), `px-5`, hairline between rows: numeral `01` (mono 11 ink-45) · label in `.t-h2` · optional mono count · a `→` that slides in 4px on hover. Active row is fully inverted (numeral at 60% paper). Hover on inactive is the ink-06 wash. Bottom block (`mt-auto`): a "now playing" strip (tile 48px + micro status + title) with `border-t ink`, then a footer row `border-t ink px-5 py-3` of micro-caps links: `Settings · Setup · Dark`.
- **Footer / transport bar** (`.shell-bottom`, 88px, **`border-t 2px ink`** — the only strong rule in the shell): left 280px identity (tile 56px + marquee title + style line), centre transport (ghost icon buttons, a 48px primary square play button, then `0:42 [waveform 28px] 3:12` capped at 768px), right 220px (mute, 96px slider, queue popover).
- **Guest panel** (optional): a right aside, width animated 0 → 360–480px over 220ms, `border-l ink`, with a 4px resize handle.
- Window: 1440×900 default, 1024×680 minimum, `backgroundColor` = paper.

### Page anatomy

```
┌ px-8 pt-8 pb-4 border-b ink ──────────────────────────────┐
│ 03 Library                                [Search…] [All ▼] [Newest ▼] [Compare] [Grid|List] │
│ 128 SONGS · 12 LIKED · 7 RATED 4+                          │   ← t-micro ink-45, mt-2
├────────────────────────────────────────────────────────────┤
│ body: flex-1 overflow-y-auto  (px-8 pb-8 pt-8 gap-8 for forms; edge-to-edge for lists/grids) │
│                                                            │
│ ── section: border-t ink pt-6 ─────────────────────────    │
│                                                            │
├ sticky bottom-0 border-t-2 ink bg-paper px-8 py-3 ─────────┤   ← action footer, only on pages with a primary action
│ VARIATIONS [1|2|4|8]   ≈ 2:40 · ≈ 3m 05s render         [CREATE →] │
└────────────────────────────────────────────────────────────┘
```

- **Header**: `<h1 class="t-h1"><Numeral n/> Title</h1>` with `items-baseline gap-4`; subtitle in `.t-micro ink-45 mt-2` (a stat line or one sentence); actions `ml-auto flex gap-3`: inputs (`w-72`), small selects (`w-36`/`w-40`), `sm` secondary/ghost buttons, a segmented view switch, micro links (`Reset`, `Start over`), the guest button last.
- **Sections**: separated by `border-t 1px ink; padding-top 24px`, never by a card. A titled section uses `SectionTitle`: `.t-h2` with numeral, `border-b ink pb-2 mb-4`, optional right-side control.
- **Forms**: two-column grid `grid-cols-2 gap-x-10 gap-y-6`. Each field is a `stack` (`gap-2`): `Label` (micro caps, ink-70, optional right-aligned normal-case hint such as `<span class="t-mono">3:00</span>`), then the control, then optional help (`11px ink-45`). Full-width items span both columns. Labels sit above, never beside, except in Settings rows.
- **Settings**: left rail 224px (`w-56`, `border-r ink`, `.t-h1` "Settings", section list with numerals, active in ink and others in ink-45); content `px-8 pt-8 pb-16 gap-8`; numbered sections (`.t-h2` + numeral, `border-b ink`), rows `grid-cols-[260px_1fr] gap-6 py-3` with hairlines: label 13px + help 11px ink-45 on the left, control(s) on the right (slider 256px + mono number input 64px + unit in micro caps).
- **Lists**: edge to edge. Rows `px-6 py-3` with hairline dividers (`border-b ink-12`), wash on hover, inversion when current/selected. List section headers are micro-caps strips (`.strip`: `px-8 py-3 border-b ink ink-45`, `Active` … `3`).
- **Grids**: rules, not gaps. `grid-cols-[repeat(auto-fill,minmax(200px,1fr))] border-l ink-12`, each cell `border-b border-r ink-12 p-4`, wash on hover.
- **Split panes**: form `flex-[7]` with `border-r ink`, feed `flex-[5] min-w-[380px]`; the feed hides under 1040px container width.
- **Wizard / install**: centred column `max-w-3xl p-12`; a numbered n-up frame (`.cells`: one ink frame, `border-r ink` dividers, each cell `01` numeral / `.t-h2` title / 12px ink-70 line / micro-caps estimate); footer `.bar` with a caveat left and `Install →` right.
- **Step strip** (`.steps`): one ink frame, `h-8` cells `01 Source | 02 Melody | 03 Style`, current inverted, done cells wash on hover, future cells ink-45.
- **Spacing**: 4 / 8 / 12 / 16 / 24 / 32 / 40 / 48. Page padding 32. Section gap 32. Field stack 8. Row padding 12 × 24. Large frames 40 (`p-10`), setup 48 (`p-12`). Nothing at 6, 10, 14, 18 or 28 except control heights.
- **Widths**: fixed Tailwind widths for controls — 64 (`w-16`, number), 80, 112, 144, 160, 176, 288 (`w-72`, search), 320, 384. Dialogs 384 / 512 / 672 / 896. Drawer `min(800px, 85vw)`. Palette `min(640px, 90vw)`.

---

## 5. Material

| Thing | Recipe |
|---|---|
| Hairline | `1px solid var(--ink-12)` — between rows, list items, grid cells, settings rows, menu items |
| Field border | `1px solid var(--ink-25)` — inputs, selects, tags and chips at rest; becomes `--ink` on hover/focus/open |
| Structural rule | `1px solid var(--ink)` — page header bottom, section tops, rail edges, frames, dialogs, popovers, menus, tooltips' neighbours |
| Strong rule | `2px solid var(--ink)` — the footer bar and sticky action bars only |
| Frame | `.box` = 1px ink border, no fill. Cards do not exist; frames do, sparingly (empty states, setup cells, sound cards) |
| Inversion | `.invert` = ink background, paper text. Selected rows, active rail item, primary buttons, failed rows, error banners, running setup step, tooltips, toasts |
| Wash | `--ink-06` background — hover on rows, cells, ghost buttons, segmented cells |
| Hatch | `repeating-linear-gradient(45deg, var(--ink) 0 1px, transparent 1px 8px)`, `background-size 16px 16px`. Static (`.hatch`) = instrumental / placeholder / missing; live (`.hatch-live`, drifts 16px every 0.6s) = running / indeterminate / pending tile. A label on a hatch sits in a paper block: `<span class="t-micro bg-paper px-1">` |
| Skeleton | `.skeleton` = ink-06 fill + ink-06 hatch drifting at 1.4s |
| Overlay | `--overlay` (paper at 85%), no blur, no dark scrim |
| Scrollbar | 8px, thumb ink-25 with a 2px paper border, ink on hover, transparent track, square |
| Selection | inverted (`::selection` ink on paper) |
| Focus | `outline: 2px solid var(--ink); outline-offset: 1px` on `:focus-visible`; fields use border → ink instead |
| Disabled | `opacity: .3` on controls, `.4` on fields, `pointer-events: none` on buttons |
| Dividers inside a toolbar | `mx-1 h-5 w-px bg-ink-25` |
| Media | `audio, video { filter: grayscale(1) }` in apps where media is incidental. Images are rare; when present, monochrome or set inside an ink frame. **Apps whose product is pictures follow §17: content keeps its colour, chrome never gets any** |

---

## 6. Components

Tailwind recipes are exact strings from the reference build; plain-CSS classes are in `css/master-ui.components.css`. Full anatomy and states in `guides/COMPONENTS.md`.

### Button

Base: `inline-flex select-none items-center justify-center gap-2 whitespace-nowrap font-medium transition-colors duration-[120ms] disabled:pointer-events-none disabled:opacity-30 [&_svg]:pointer-events-none [&_svg]:shrink-0 no-drag`

| Variant | Classes | Plain |
|---|---|---|
| primary | `border border-ink bg-ink text-paper hover:bg-paper hover:text-ink` | `.btn.btn-primary` |
| secondary (default) | `border border-ink bg-paper text-ink hover:bg-ink hover:text-paper` | `.btn` |
| subtle | `border border-ink-25 bg-paper text-ink hover:border-ink hover:bg-ink hover:text-paper` | `.btn.btn-subtle` |
| ghost | `border border-transparent text-ink-70 hover:text-ink hover:bg-ink-06` | `.btn.btn-ghost` |
| link | `link h-auto p-0 text-ink` | `.btn-link` / `.link` |

There is no danger variant. Destructive actions are a secondary/primary button labelled plainly (`Delete`), a menu item in `font-medium` prefixed `✕`, or a ghost `X`.

| Size | Classes |
|---|---|
| sm | `h-8 px-3 text-[11px] font-medium uppercase tracking-[0.08em] [&_svg]:size-3.5` |
| md | `h-9 px-4 text-[12px] uppercase tracking-[0.08em] [&_svg]:size-4` |
| lg | `h-12 px-6 text-[13px] uppercase tracking-[0.08em] [&_svg]:size-4` |
| icon / icon-sm / icon-lg | `size-9 [&_svg]:size-4` / `size-7 [&_svg]:size-3.5` / `size-12 [&_svg]:size-5` |

Labels are uppercase micro caps. Icons lead (`<Sparkles/> Write it`); arrows trail (`Create <ArrowRight/>`). `loading` swaps in a spinning `Loader2` and disables. A toggled ghost button (shuffle, repeat) stays inverted: `bg-ink text-paper hover:bg-ink hover:text-paper`. The one big CTA on a page is `primary lg min-w-44` in the sticky footer.

### Fields

- **Input** (single line, underline only): `h-9 w-full border-0 border-b border-ink-25 bg-transparent px-0 text-[14px] text-ink placeholder:text-ink-45 transition-colors focus:border-ink focus:outline-none disabled:opacity-40`. Numeric/path/seed inputs add `t-mono` and a fixed width. Compact rows use `h-7 text-[11px]`.
- **Textarea** (boxed): `w-full resize-none border border-ink-25 bg-transparent px-3 py-2 text-[14px] leading-relaxed text-ink placeholder:text-ink-45 focus:border-ink focus:outline-none disabled:opacity-40`. Editors add `t-mono text-[13px]` and `line-height 1.55; tab-size 2`.
- **Label**: `t-micro flex items-center justify-between text-ink-70`; hint `normal-case tracking-normal text-ink-45`, usually mono (`3:00`, `12 steps`). Help text under a control: `text-[11px] leading-snug text-ink-45`. Unit after a number input: `t-micro text-ink-45` (`GB`, `LUFS`).
- **Select**: trigger `inline-flex w-full items-center justify-between gap-2 border border-ink-25 bg-paper px-3 text-left text-[13px] text-ink hover:border-ink focus:border-ink focus:outline-none data-[placeholder]:text-ink-45 data-[state=open]:border-ink`, `h-9` (`sm`: `h-8 text-[12px]`); the caret is a text glyph `▼` at 10px ink-70. Popup: `border border-ink bg-paper`, items `border-b border-ink-12 px-3 py-2 text-[13px] last:border-b-0 data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[state=checked]:font-medium`, optional help line `text-[11px] opacity-60`. `sideOffset -1` so the popup's border overlaps the trigger's.
- **Segmented**: `inline-flex border border-ink`; cells `px-3 font-medium uppercase tracking-[0.08em]` + `border-l border-ink` between, `h-9 text-[11px]` (`sm`: `h-7 text-[10px]`); selected `bg-ink text-paper`, others `hover:bg-ink-06`. For 2–5 exclusive options (view mode, quality, tab).
- **Tabs**: list `flex items-end gap-6 border-b border-ink-12`; trigger `t-micro -mb-px border-b-2 border-transparent pb-2 text-ink-45 hover:text-ink data-[state=active]:border-ink data-[state=active]:text-ink`. For switching content within a panel (Lyrics · Score · Details).
- **Switch**: root `h-[18px] w-9 border border-ink bg-paper data-[state=checked]:bg-ink disabled:opacity-30`; thumb `size-3 translate-x-[2px] bg-ink data-[state=checked]:translate-x-[20px] data-[state=checked]:bg-paper`. Square thumb, 120ms.
- **Checkbox**: native, 14px square, ink border, filled when checked.
- **Slider**: native range; 1px track (`ink` up to `--pct`, `ink-25` after), 10px square ink thumb with a 1px paper border, `ew-resize`. Always paired with a mono readout (label hint or 64px number input). Never a knob.
- **Meter**: `flex gap-[2px]` of cells `h-2 flex-1 border border-ink`, on = `bg-ink`. For discrete levels (VRAM 12 cells, prompt quality 6 cells).

### Overlays

- **Tooltip**: `bg-ink px-3 py-2 text-[12px] leading-snug text-paper max-w-xs`, no arrow, `sideOffset 6`, 300ms delay. Copy: a short sentence or a shortcut (`Ctrl + Enter`). Tooltips explain disabled states.
- **Menu**: `min-w-52 border border-ink bg-paper text-[13px]`, `sideOffset 4`, `align end`; items `flex items-center gap-3 px-3 py-2 data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[disabled]:opacity-30 [&_svg]:size-3.5`; separator `h-px bg-ink-12`; group label `t-micro px-3 pb-1 pt-2 text-ink-45`; submenus `min-w-44`, `sideOffset -1`. Trigger is a ghost `icon-sm` `MoreHorizontal`.
- **Popover**: `border border-ink bg-paper p-3` (`p-0` when it contains a list with its own header strip).
- **Dialog**: overlay `fixed inset-0 z-50 bg-overlay`; content `fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[calc(100%-2rem)] border border-ink bg-paper p-6` with `max-w-sm | max-w-lg | max-w-2xl | max-w-4xl`; title `t-h2 pr-8`; description `mt-1 text-[13px] text-ink-70`; body `mt-5`; close `absolute right-4 top-4 p-1 text-ink-45 hover:text-ink` with a 16px `X`. Footer: `flex justify-end gap-2` — ghost `Cancel` then the primary. Big dialogs use the strong-rule `.bar` (`border-t-2 border-ink pt-4`, caveat left, CTA right). Only destructive actions get a confirmation dialog (`sm`).
- **Drawer**: right-anchored `absolute inset-y-0 right-0 w-[min(800px,85vw)] border-l border-ink bg-paper`, enters from `x: 24, opacity: 0` over 180ms with `--ease`; backdrop `bg-overlay` fades in 120ms; `Esc` closes; header `flex items-start gap-5 border-b border-ink p-6`; a "next actions" rail `grid-cols-4 border-b border-ink` of `NextAction` cells (`border-r border-ink p-3 hover:bg-ink hover:text-paper`, micro title with `→`, 11px body at 70%).
- **Command palette** (`Ctrl K`): `fixed left-1/2 top-[15vh] w-[min(640px,90vw)] -translate-x-1/2 border border-ink bg-paper`; input row `flex items-center gap-3 border-b border-ink px-4` with a blinking `→` (`t-mono blink text-ink-45`), `h-12 text-[15px]` input, `Kbd Esc`; results `max-h-[50vh]`, rows `gap-4 border-b border-ink-12 px-4 py-2.5 text-[13px]`, selected row inverted; each row = group (`t-micro w-12`) · label · mono hint. Groups: `Go`, then object actions, `App`, then search results. Empty: `No matches.`
- **Toast**: bottom-right, offset above the footer bar (`offset 104`), an ink box: `bg ink, text paper, border ink, radius 0, shadow none, 13px`, action button inverted (paper on ink box). Success, error, info and warning look identical.

### Small parts

- **Badge**: `t-micro inline-flex h-5 items-center border px-1.5`; neutral `border-ink-25 text-ink-70`; invert `border-ink bg-ink text-paper`. Accent / success / warning collapse to neutral.
- **Chip** (kind marker on a row that may be inverted): `t-micro shrink-0 border border-current px-1` (`Cover`, `Remix`, `Var.`, `Instr.`).
- **Tag** (selectable): `h-7 border border-ink-25 px-2.5 text-[12px] text-ink-70 hover:border-ink hover:text-ink`; selected `border-ink bg-ink text-paper`. Insert chips in editors: `t-mono h-7 border border-ink-25 px-2 text-[11px]` → invert on hover.
- **Kbd**: `t-mono border border-ink-25 px-1.5 py-0.5 text-[10px] text-ink-70`, text `Ctrl K`, `Esc` (space, no plus).
- **Numeral**: `t-mono text-[11px] text-ink-45`, `String(n).padStart(2, '0')`.
- **Rule**: `<hr>` `h-px bg-ink-12` or strong `h-[2px] bg-ink`.
- **Progress**: `h-[3px] w-full bg-ink-12` track, `bg-ink` fill with `transition-[width] duration-300 ease-linear`; indeterminate = `hatch-live` filling the track; install pages use `h-[6px]`. Always accompanied by mono text: `57% · 1m 20s left`.
- **Skeleton**: `.skeleton` blocks sized like the content they replace (`h-8 w-48`, `h-24 w-full`), `gap-6 p-8`.
- **Spinner**: `Loader2 size-4 animate-spin text-ink-70`. Prefer the breathing square for "running"; the spinner is for an in-flight button.
- **Live dot**: `size-1.5 bg-ink breathe` (6px). On an inverted surface `bg-paper`; inside a chip `bg-current`.
- **Marquee**: overflowing titles scroll (12s linear, text repeated twice with `pr-8`); short titles truncate.
- **Empty state**: `flex flex-col items-start gap-4 px-8 py-16`; title `.t-display max-w-2xl` — a two-or-three-word sentence with a full stop (`Nothing yet.`, `Empty.`, `No matches.`, `Drop a song.`); one line `max-w-md text-[14px] text-ink-70`; optional primary button. Boxed variant `border border-ink p-10`. Never an illustration, never an icon.
- **Stat stack**: `t-micro ink-45` label over a 14px value; in a `grid-cols-2 gap-x-8 gap-y-3`.
- **Stage list**: rows `flex items-center gap-3 py-1 text-[12px]`; glyph column `t-mono w-3 text-[11px]` from `✓ ● – ✕ ○` (done, running, skipped, failed, pending); running swaps the glyph for the breathing square and shows a `Progress` indented `pl-6`; pending/skipped rows are ink-45; right side mono `120/400 tokens · 8.3/s` or `45s`.
- **Log**: `<pre class="selectable t-mono max-h-48 overflow-auto border border-ink-12 p-2 text-[11px] leading-relaxed text-ink-70">` inside a `<details>` whose summary is `t-micro text-ink-45 hover:text-ink` (`Log (60)`).
- **Notice bar**: inverted (`bg-ink px-4 py-2 text-[13px] text-paper`) for problems and system state, with a micro-caps kicker (`Engine`) and micro-caps `link` actions (`Restart`, `Logs`, `Open setup →`); outlined (`border border-ink px-4 py-3`) for information; both full width with `gap-4`.
- **Drop zone**: `flex flex-col items-start gap-4 border border-ink p-10`; inverts while a file is over it; copy `Drop a song.` / formats line / `Choose file` button.
- **Feed row**: `group flex items-center gap-4 border-b border-ink-12 px-6 py-3` + `hover:bg-ink-06`; current → `bg-ink text-paper`; tile 64px (48 compact) with a hover play overlay (`bg-paper/85`); title 15px medium + chips; style line 12px ink-70; meta line `t-mono mt-1 text-[11px] text-ink-45` joined by ` · `; right-side actions `opacity-0 group-hover:opacity-100`. On an inverted row, secondary text is `text-paper/70`, meta `text-paper/60`, borders `border-paper/20–60`.
- **Grid tile**: `flex flex-col border-b border-r border-ink-12 p-4 hover:bg-ink-06`; square art; play square `absolute bottom-2 right-2 size-10 border border-ink bg-paper opacity-0 group-hover:opacity-100 hover:bg-ink hover:text-paper`; title 14 medium, subtitle 12 ink-70, mono meta 11 ink-45.
- **Typographic tile** (identity without colour): an ink square with a seed-derived raster (lines / dots / cross / diag / bars; density from a tempo-like number, angle from a key-like number; foreground paper at 50%) and the title set in paper, bold uppercase, `leading-[0.9] tracking-[-0.03em]`, bottom-left, size in container-query units (`46cqw` initial, `19cqw` two words, `13–22cqw` full title); a "cover"/derived variant is outlined paper with ink text; pending = `hatch-live` with no label; playing = a breathing square top-left at 10%.
- **Wordmark**: `Mark` (20px) + `text-[13px] font-bold uppercase tracking-[-0.02em]`; stacked variant `leading-[0.85] tracking-[-0.04em]`. The Mark is an ink square carrying a paper diagram of what the app acts on — one per app, never a letter (§13, `guides/MARK.md`).

---

## 7. Motion

One easing (`cubic-bezier(0.2, 0, 0, 1)`), three durations. Motion is small, fast and functional; nothing bounces, springs, scales on hover or floats.

| What | Recipe |
|---|---|
| Colour / background / border change | `transition-colors duration-[120ms]` |
| Reveal on hover (row actions, play overlay) | `opacity-0 group-hover:opacity-100 transition-opacity duration-[120ms]` |
| Arrow on a rail item | `-translate-x-1 opacity-0` → `translate-x-0 opacity-100`, 120ms |
| Chevron | `rotate-180` 120ms |
| Link underline | background-size 0% → 100% × 1px, 180ms |
| Progress width | 300ms linear |
| Page swap | 100ms fade (`animate-[fade_100ms_ease-out]`, keyed on the page) |
| Drawer | x 24 → 0 + fade, 180ms; backdrop fade 120ms |
| Side panel | width 0 → w, 220ms |
| Live hatch | background-position 16px per 0.6s, linear, infinite |
| Skeleton | same, 1.4s |
| Breathe | opacity 1 → .35 → 1, 2.4s ease-in-out — **only on squares ≤ 6px (10% of a tile), never on text** |
| Blink | steps(1), 1s — a prompt caret, a playhead |
| Marquee | translateX −50%, 12s linear |
| Typewriter (machine fills a field) | `400ms + 6ms/char`, capped at 2.4s, quadratic ease-out, rAF |
| Spinner | `animate-spin`, only inside a busy button |

`prefers-reduced-motion: reduce` stops every loop (hatch, skeleton, marquee, breathe, blink, spark) and makes the typewriter instant. Transitions stay (they are ≤ 320ms).

Not allowed: hover scale, press scale (except the guest spark), ripple, parallax, spring physics, staggered list entrances, skeleton shimmer gradients, bouncing dots, animated gradients, confetti.

---

## 8. Iconography

- **Library**: [lucide](https://lucide.dev) at the default stroke (2). No filled, duotone or brand icon sets; no custom pictograms except the app's mark and a guest's monogram.
- **The app mark is not an icon from the set.** It is drawn per app as a diagram of the app's subject — see §13 and `guides/MARK.md`. Never use a lucide glyph as the app icon, and never use the mark as a UI icon inside the app (it appears in the wordmark, the window chrome and the icon files only).
- **Size by slot**: 12px (`size-3`) inline in chips, 14px (`size-3.5`) in `sm`/`icon-sm` buttons and menus, 16px (`size-4`) in `md`/`icon` buttons, 20px (`size-5`) in `icon-lg`. Set by the button size, not on the icon.
- **Fills**: `fill-current` on play/pause and on a liked heart; `Play` nudged `ml-0.5`.
- **Pairing**: icon leads a label with `gap-2`; forward actions end with `ArrowRight` or a `→` glyph.
- **Text glyphs are icons** and are preferred when they read at 11px: `→ ←` navigation, `✓ ● – ✕ ○` stage states, `★ ☆` rating, `♥` liked, `▼` select caret, `·` separator, `≈` estimate, `×` multiplier, `└ •` tree, `!` check failed (the only sanctioned exclamation mark, as a glyph in a mono column).
- **Never**: emoji, coloured icons, icon-only empty states, icons as decoration, icon badges with counts (use a mono number).

---

## 9. Voice

Quiet, exact, a little dry. Written by someone who respects the reader's time.

- **Sentence case** everywhere: titles, buttons, menu items, dialog titles, tabs. Micro caps are a typographic treatment (`.t-micro`), not a writing style — the source text is still sentence case.
- **No exclamation marks. No emoji. No "Oops", no "Awesome", no "Let's".** No trailing "…" except the literal `compiling…` while something is compiling.
- **British spelling**: randomise, normalised, licence, colour, grey.
- **Buttons**: verb first, one or two words. `Create`, `Create 4`, `Write it`, `Train a sound`, `Choose file`, `Clear finished`, `Run again`, `Save draft`. Forward motion gets an arrow: `Begin →`, `Install →`, `Render cover →`, `Choose a style →`; back is `← Back`. The one CTA on a page may carry its count: `Create 4`.
- **Micro links**: `Switch to custom`, `All songs →`, `Show log` / `Hide log`, `Skip for now`, `Start over`.
- **Empty states**: a short sentence with a full stop, then one explanatory line. `Nothing yet.` / `Describe a song on the left, or write the lyrics and a style, then create.` — `Empty.` / `Everything you create is kept here.` — `No matches.` / `Try a different search or filter.` — `Nothing running.` — `Nothing playing` (a micro-caps status has no full stop).
- **Toasts**: a state or a past-tense fact, optionally followed by an em-dash clause. `Queued`, `4 songs queued`, `Prompt copied`, `Song deleted`, `Preset saved`, `Melody transcribed. Review it before rendering.`, `Training queued — follow it on this page or in the queue.` Action label is a single noun: `Queue`, `Open`.
- **Errors**: the system's message verbatim (`toast.error(e.message)`), or `Playback failed: …`. No apology, no "something went wrong".
- **Status words** (micro caps): `Engine ready`, `Engine offline`, `Queued`, `Working`, `Waiting`, `Checking`, `Playing`, `Paused`, `✕ Failed`, `Loading settings`, `up to date`.
- **Setting help**: one or two plain sentences that state the trade-off. `Upper bound the model may allocate. Leave 1–2 GB for the display.` — `Never contact Hugging Face; fail if weights are missing locally.` — `Seconds.`
- **Tooltips**: a sentence without a full stop unless there are two; or a shortcut. `Transpose down a semitone`, `Seed locked — same seed every run. Click to randomise.`, `Name, trigger and at least one source` (explaining a disabled button), `Ctrl + Enter`.
- **Confirmations**: only for destruction. Title `Delete song`; body `“Title” and its files will be removed. This cannot be undone.`; buttons ghost `Cancel`, then `Delete` (no red).
- **Danger** is a word and a glyph: `✕ Delete` in `font-medium`. Never a colour.
- **Numbers and units**
  - Durations `m:ss` (`2:34`), unknown `--:--`; clip times `m:ss.s`.
  - ETAs `45s`, `3m 05s`, `1h 12m`; relative time `just now`, `5m ago`, `3h ago`, `2d ago`, then a locale date.
  - Estimates lead with `≈ ` (`≈ 3 GB · 5 min`, `≈ 2:40`). Ranges use an en dash (`10–20 min`, `1–2 GB`). Items are joined with ` · `.
  - A space before units: `16 GB`, `120 BPM`, `44100 Hz`, `-14 LUFS`, `800 steps`, `12 s`. Percent as `57%`. Multiples `×4`. Thousands `1,234`. Indexes `01`. Ranks `#1`. Scores `0.71`.
  - Shortcuts: `Ctrl K`, `Esc`, `Ctrl J` inside `Kbd` (space, no plus); `Ctrl + Enter` in tooltip prose; `Space play · Tab switch · 1–5 rate` in hint lines. Never `⌘`.
- **Theme names**: `Paper` (light) and `Ink` (dark). `Switch to ink (dark)`.
- **Product name**: in the wordmark and the window title only. The UI does not say the app's name in sentences.

---

## 10. Feedback and states

| State | Treatment |
|---|---|
| Loading a page | `PageSkeleton`: stacked `.skeleton` blocks in the page's padding |
| Loading data inline | `.skeleton` block sized like the content; waveform canvas gets `.skeleton` until peaks arrive |
| Busy button | `loading` → spinner in the button, disabled |
| Running (a job, the engine, a step) | breathing 6px square + micro-caps word; `Progress` with mono `57% · 1m 20s left`; live hatch when indeterminate; the running step row inverts on install screens |
| Queued | micro caps `Waiting` / `Queued` in ink-45 |
| Success | a toast (`Preset saved`) or a `✓` glyph in the stage list; optionally the two-note sound. No green, no check-in-a-circle |
| Failure | **the whole row or bar inverts** (`bg-ink text-paper`), kicker `✕ Failed`, the message at 80%; expanded error in a `pre` with `border-paper/30`. Toast for transient errors. No red |
| Warning | outlined notice bar, or text at ink-70 prefixed with `—` |
| Hover | rows: wash; controls: inversion; links: underline slides in; row actions reveal |
| Selected / current / active | inversion |
| Focus | 2px ink ring, or field border → ink |
| Disabled | opacity .3 (.4 for fields); a tooltip explains why when it is not obvious |
| Empty | `.t-display` sentence + one line (§6) |
| Drag over | the drop zone inverts; the dragged row goes to `opacity-40` with a `GripVertical` handle in ink-45 |
| Confirm | only destructive; `sm` dialog |
| Sound (optional, off by default) | synthesised square waves: a 60ms 1200 Hz click on the primary action, a 660→990 Hz two-note "done" |

---

## 11. Theming

- `<html data-theme="light">` by default; `dark` is the exact inversion of `--paper`/`--ink` and the alpha ramp. Also toggle a `dark` class for frameworks that want it. Set `color-scheme` so native controls follow.
- Persist in `localStorage` under `<prefix>.theme` (Music Master: `mm.theme`). No system-preference listener; the user chooses.
- Electron: on change call `nativeTheme.themeSource = t`, `win.setBackgroundColor(paper)`, `win.setTitleBarOverlay({ color: paper, symbolColor: ink, height: 40 })`.
- Canvas drawing reads `getComputedStyle(document.documentElement).getPropertyValue('--ink')` so charts follow the theme.
- Generated rasters (tiles) must pick the foreground from the actual theme colours (paper at 50% on an ink tile in light; ink at 50% in dark).
- Never ship a "dim" or "sepia" theme. Never tint the dark theme.

---

## 12. Data and identity

- **Charts are ink bars.** 1px bars, 2px gaps, drawn on canvas at device pixel ratio. State is alpha: 1 (done / played), .5 (hover preview), .25 (rest). Markers are 1px full-height ink lines; a playhead is a 1px line with a 6px square at the top. Labels are `t-micro text-[9px] ink-45` above the marks. No axes, no grid lines, no legends, no colour series — if two series must be compared, use weight, hatch or side-by-side panels.
- **Discrete levels** use `Meter` (cells). **Ratios** use `Progress`. **Structure** uses a vertical strip of blocks proportional to size, the emphasised block inverted, instrumental blocks hatched with a paper label.
- **Identity without colour.** Every object that needs a face (a song, a project, a dataset) gets a typographic tile: an ink square, a deterministic raster from its seed (five pattern kinds; density from a tempo-like number, angle from a key-like number), the name set in bold paper caps. Same seed, same tile, forever. Derived objects are outlined paper tiles.
- **Tables** are lists with rules: header strip in micro caps, rows with hairlines, mono numerals in a fixed first column, right-aligned mono values.

---

## 13. Family and naming

- Apps are called **`<Thing> Master`**: Music Master, Sort Master, … The wordmark is the Mark + the name in bold uppercase at 13px, tracking −0.02em.
- **The mark is a picture of what the app acts on**, not a letter. An ink square carrying a paper diagram of the app's subject: Music Master = levels (five bars), Visual Master = a framed picture, Sort Master = an ordered list. Each app gets its own drawing; never a variation on a sibling's. **Do not spell the initial** — bar-heights-as-letters produced marks that were indistinguishable at 16px and meant nothing. Full brief, grammar, tests and export sizes in `guides/MARK.md`; worked examples in `react/Mark.tsx`.
- **Mark grammar** (what makes them a family): 100×100 ink square, full bleed, zero radius; geometry in a 68×68 field (16 padding), coordinates snapped to even numbers; paper on ink only — no alpha, grey or stroke colour; one element weight per mark; straight lines, 45° diagonals and full circles only; 2–5 elements; smallest element 8 units; legible at 16px; optically centred. It inverts with the theme for free; exported icon files are always the light version.
- **Storage keys** are prefixed with the app's two-letter code (`mm.theme`, `mm.sound`, `mm.libraryView`).
- **Window title** is the product name. Pages are titled by their numeral and noun (`03 Library`).
- **Shortcuts** shared across the family: `Ctrl K` palette, `Ctrl J` guest panel, `Ctrl 1…9` pages, `Ctrl ,` settings, `Esc` close, `Space` primary media action, `J/K` next/previous, `L` like, `1–5` rate, `Ctrl + Enter` submit the main form.

---

## 14. Guest rooms (the only sanctioned colour)

A third-party presence (Claude, today) may sit inside a Master UI app with its own palette so it reads as a guest rather than a feature. Rules:

1. All of its colours live in CSS variables scoped to one container (`.claude-room`). Nothing leaks.
2. Outside the room, exactly two things may show its colour: a 34px square button that is just its monogram (breathes idle, turns and fills on hover, spins while it works) and a 12px monogram next to a field it filled (a provenance mark, gone once the user edits).
3. It speaks in the app's grotesk, not a serif; it may use weight 600.
4. Its motion follows the same reduced-motion rule.
5. It keeps the app's edges: zero radius, no shadows. Its one allowed dashed border is for "something else" free-text options.
6. It is optional: the kit ships it as `css/claude-room.css`, off unless `--claude-room` is passed to `init`.

---

## 15. Do / Don't

| Do | Don't |
|---|---|
| `border border-ink`, `border-b border-ink-12` | `rounded-md`, `shadow-sm`, `ring-2 ring-blue-500` |
| `bg-ink text-paper` for selected | `bg-blue-50 text-blue-700` |
| `✕ Failed` in an inverted row | red text, a red border, an alert icon |
| `hatch-live` / breathing square for running | a spinner in the middle of the page, a shimmer |
| `.t-micro` label above the field | placeholder as label, floating labels |
| `01` numerals | icons in navigation |
| `Create →` | `🚀 Let's go!` |
| `Nothing yet.` + one line | an illustration of an empty box |
| a toast that says `Preset saved` | a green banner with a check icon |
| `2:34 · seed 12345 · 5m ago` | badges in three colours |
| `Ctrl K` in a Kbd | `⌘K` |
| overlay = paper at 85% | dark scrim with blur |
| `--ease` 120ms | spring, bounce, 400ms ease-in-out |
| one primary button per page, in the sticky footer | three coloured CTAs |
| Neue Haas / Inter, ss01, tabular numbers | system-ui, Roboto, a display serif |
| an app mark that draws the app's subject | a mark that spells the initial, or a sibling's mark recoloured |

**Forbidden** (the linter errors on these): any `border-radius` other than 0; any `box-shadow`/`text-shadow` other than none; `filter: blur|drop-shadow`; `backdrop-filter`; `linear-gradient`/`radial-gradient` (the hatch `repeating-linear-gradient`, the link underline and the range track are the only gradients); any colour that is not black, white, their alphas, `transparent` or `currentColor`; Tailwind `rounded-*`, `shadow-*`, `blur-*`, `backdrop-blur-*`, `drop-shadow-*`, `bg-gradient-*`, and every `{bg,text,border,ring,fill,stroke,from,via,to,outline,decoration}-{colour}-{n}` utility.

**Warned**: emoji; `!` ending a string; `⌘`; weights 600/800/900.

---

## 16. New-screen checklist

1. Page header: numeral + `.t-h1`, micro-caps subtitle, actions right, `border-b border-ink`.
2. Sections divided by 1px rules; no cards; frames only for empty states and n-up cells.
3. Every label is `.t-micro`; every number is `.t-mono`; help text is 11px ink-45.
4. One primary action, `lg`, in a `border-t-2` sticky footer with the estimate in mono to its left.
5. Selected / current / active = inversion. Hover = wash (rows) or inversion (controls).
6. Running = breathing square or live hatch + mono progress. Failed = inverted row + `✕ Failed`.
7. Empty state = `.t-display` sentence with a full stop + one line.
8. Inputs underline-only, textareas boxed, selects with `▼`, switches square.
9. Nothing rounded, nothing shadowed, nothing coloured, nothing bouncing. Run `master-ui check`.
10. Copy: sentence case, no `!`, British spelling, ` · ` separators, `≈` estimates, `→` forward.
11. Works in dark by inversion alone (check canvases and rasters read the theme).
12. Keyboard: `Esc` closes, `Ctrl K` reaches it, `Ctrl + Enter` submits, focus ring visible.
13. Pictures (§17): colour only inside a content frame; overlays are double strokes; a selected image is the inverted caption strip plus a double ring; transparency is the cross-hatch, never a grey checkerboard.

---

## 17. Visual content (apps whose product is pictures)

Music Master's content is sound, so its screens hold no colour at all. An image app's content *is* colour. The rule that keeps the family seamless: **the pixels a user makes or brings are content and keep every colour they have; everything the app draws around, over or about them stays paper and ink.** A screen of Visual Master with its images removed must pass §15 unchanged.

### 17.1 Content frames

| Thing | Recipe |
|---|---|
| Content frame | `.vframe`: `position: relative; overflow: hidden; background: var(--ink-06)`. Colour may appear **only** inside one. The image is `object-fit: contain` so the real framing shows; the letterbox is the ink-06 field, never a blurred copy of the image |
| Stage (the working view of one image) | the page body becomes an ink-06 field; the image sits centred with a 1px ink-12 hairline around it, 32px from every edge at fit. Zoom level in mono (`Fit`, `100%`, `200%`); above 200% set `image-rendering: pixelated` so pixels read as pixels |
| Surround | a per-view `Paper · Ink` segmented control sets the stage field to paper or ink, independent of the theme, because colour is judged against a neutral. Never a grey that is neither |
| Transparency | `.alpha-grid`: two `repeating-linear-gradient`s at ±45°, ink-12, 8px, a fine cross-hatch behind transparent pixels. Never a grey checkerboard (a third neutral) and never the single-direction hatch (that means placeholder) |
| Not allowed | an image as a page or panel background, text over an image without a paper block, blurred or dimmed copies, colour sampled from an image into chrome (accent-from-artwork), rounded thumbnails, shadows under images, hover zoom |

### 17.2 Image tile (grids)

A **grid tile** (§6) whose art is a content frame.

- Cell: `border-b border-r ink-12`, `p-3`; frame square by default (`aspect-square`), the image contained.
- Caption strip under the frame, two lines: title 13 medium (truncated), mono meta 11 ink-45 `1024×1024 · seed 12345 · 5m ago`. Kind chips as in §6 (`Edit`, `Inpaint`, `×2`, `Cut out`) and a batch count chip `4 takes`.
- Hover: the caption strip gets the wash; a 40px `Open` square bottom-right of the frame and a menu square top-right fade in (120ms). No zoom, no lift.
- **Selected**: the caption strip inverts (§10) **and** the frame gets a double ring: a 2px ink outline inset by 2px plus a 1px paper line inside it, so the ring reads on dark and light pixels alike. Multi-select numbers the picks in an inverted 20px square top-left (`01`, `02`); the order is the compare order.
- **Current** (the image open on the stage): the caption strip inverts, no ring.
- **Pending**: the frame at the *requested* aspect ratio filled with `hatch-live`, no label. When the engine sends a preview it replaces the hatch at `image-rendering: pixelated` (it is a 64–256px latent peek), a mono step count sits in a paper block top-left (`12/28`), and a 3px progress track runs along the frame's bottom edge. The finished image replaces the preview with a 120ms opacity transition, nothing else.
- **Failed**: static `hatch` frame, caption strip inverted with `✕ Failed` and the message at 80% (§10).
- **Missing file**: static `hatch` frame, paper label block `Missing`.

### 17.3 Overlays on pictures

Anything drawn *on* pixels must survive any colour under it, so every overlay is a **double stroke**: a 1px ink line with a 1px paper line beside it, drawn on a canvas that reads `--ink` / `--paper` from computed style (§11). Overlays never use a colour, never fade their strokes, and all hide while `H` is held so the user can see the untouched image.

| Overlay | Recipe |
|---|---|
| Mask (area to change) | fill = diagonal stripes, 2px ink / 2px paper at 45°, drawn at 45% opacity; edge = the double stroke as marching ants (4px dashes drifting 8px per 0.6s, the live-hatch tempo; static under reduced motion). A `Show mask as solid` toggle swaps the fill for paper at 70% |
| Selection candidate (from a click or a description) | edge only, dashed double stroke, not animated; `Enter` adds it to the mask, `Esc` drops it |
| Click points | include: 10px paper square, 1px ink border, ink `+`; exclude: 10px ink square, paper `−`. Squares, like handles |
| Brush | the footprint is a double-stroke circle on the canvas: the one round shape in the family, because a brush is round; it is never a UI element. Size in mono next to the cursor while `[` / `]` are pressed (`64 px`) |
| Crop / outpaint frame | double-stroke rectangle; 8px square handles (paper fill, ink border) at corners and edge midpoints; size in a paper block at the bottom-right corner (`1536 × 1024`). Outside a crop: paper at 85% (`--overlay`), never a dark scrim. New area of an outpaint: static `hatch` (it is a placeholder) with a paper block `+256 px` on each extended side |
| Reference slots | 64px content frames in a row, numbered `01…10` in an inverted square top-left; an empty slot is a `.box` with `+` and the micro label `Add` |
| Compare divider | a 1px ink + 1px paper vertical line with a 24px square handle (paper, ink border, mono `‹ ›`); labels `A` / `B` in inverted 20px squares in the top corners |

### 17.4 Compare

Modes in a segmented control: `Split · Side by side · Flicker`. Split drags the divider (arrow keys move it 1%, `Shift` 10%); Side by side puts two stages in one ink frame with a 1px ink divider and links zoom and pan; Flicker swaps while `Space` is held, with no transition. **Blind** works as in Music Master: labels become `1` / `2`, titles `Hidden`, a fixed coin flip per pair, and the reveal line `1 was A · 2 was B`. Both images are shown at the same scale; a size mismatch is written in mono above the stage (`1024×1024 vs 2048×2048 · shown at the smaller`).

### 17.5 Models: licence and fit

Models get typographic tiles (§12) from their id, never a logo. On a model row:

| Fact | Treatment |
|---|---|
| Licence that allows commercial use | neutral badge (`Apache 2.0`, `MIT`) |
| Non-commercial licence | **inverted** badge `Non-commercial`, the licence name in a tooltip; the only emphasis a licence gets |
| Fits in video memory | micro caps `Fits`, ink-70 |
| Fits by loading in turns | micro caps `Fits by swapping`, ink-70, with a tooltip (`Loads the text encoder, then the image model. ≈ 20 s slower to start`) |
| Too big for this machine | inverted badge `✕ Too big` |
| Size and download | mono `30.9 GB`; while downloading, §6 Progress with `12.4 of 30.9 GB · 18 MB/s · 17m left` |
| Needs a token | outlined badge `Token needed`, linking to Settings |

### 17.6 Colour as information

When colour is the data (a palette taken from a reference, a swatch in a prompt helper), each swatch is content: a 16px content frame with a 1px ink-12 outline and its value beside it in mono (`#3A5F8C`). No swatch ever tints chrome, a badge or a selection.

### 17.7 CSS

`css/master-ui.components.css` ships `.vframe`, `.vframe-stage`, `.alpha-grid`, `.vtile` (+ `.is-selected`, `.is-current`), `.vring`, `.vhandle` and `.pixelated`. Overlays are canvas drawing, not CSS; `react/overlay.ts` has the double-stroke, stripe and marching-ants helpers.
