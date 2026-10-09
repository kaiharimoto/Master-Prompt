# Components

Every primitive in the family, with its anatomy, the exact Tailwind recipe (from the reference React build in `../react/ui.tsx`), the plain-CSS class (from `../css/master-ui.components.css`), and its states. Values are not negotiable; if you need something that is not here, compose it from these.

Conventions used below: `ink-N` means `var(--ink-N)`; "inverted" means `background: var(--ink); color: var(--paper)`; sizes are px.

---

## Button

**Anatomy**: `<button>` with optional leading icon, uppercase micro-caps label, optional trailing arrow. Height 32 / 36 / 48. Icon-only squares 28 / 36 / 48.

Tailwind (cva):

```
base: inline-flex select-none items-center justify-center gap-2 whitespace-nowrap font-medium transition-colors duration-[120ms] disabled:pointer-events-none disabled:opacity-30 [&_svg]:pointer-events-none [&_svg]:shrink-0 no-drag
primary:   border border-ink bg-ink text-paper hover:bg-paper hover:text-ink
secondary: border border-ink bg-paper text-ink hover:bg-ink hover:text-paper        (default)
subtle:    border border-ink-25 bg-paper text-ink hover:border-ink hover:bg-ink hover:text-paper
ghost:     border border-transparent text-ink-70 hover:text-ink hover:bg-ink-06
link:      link h-auto p-0 text-ink
sm:  h-8 px-3 text-[11px] font-medium uppercase tracking-[0.08em] [&_svg]:size-3.5
md:  h-9 px-4 text-[12px] uppercase tracking-[0.08em] [&_svg]:size-4                (default)
lg:  h-12 px-6 text-[13px] uppercase tracking-[0.08em] [&_svg]:size-4
icon: size-9 [&_svg]:size-4   icon-sm: size-7 [&_svg]:size-3.5   icon-lg: size-12 [&_svg]:size-5
```

Plain: `.btn`, `.btn.btn-primary`, `.btn.btn-subtle`, `.btn.btn-ghost`, `.btn-link`; sizes `.btn-sm`, `.btn-lg`, `.btn-icon`, `.btn-icon-sm`, `.btn-icon-lg`.

States: hover inverts (primary → paper, others → ink); `:active` no extra treatment; disabled `opacity-30` + no pointer events; `loading` = `Loader2 animate-spin` before the label and disabled; toggled ghost (shuffle/repeat) = `bg-ink text-paper hover:bg-ink hover:text-paper`; on an inverted parent a ghost button becomes `text-paper hover:bg-paper hover:text-ink`.

Where: primary = the one main action on a page (`lg`, `min-w-44`, in the sticky footer) and the play button (`icon-lg`); secondary = everything else in headers/dialog footers; subtle = rarely, inside dense rows; ghost = icon actions, `Cancel`, `Recent`, `Clear`; link = inline text actions in `.t-micro`.

---

## Input

Single-line, underline only.

```
h-9 w-full border-0 border-b border-ink-25 bg-transparent px-0 text-[14px] text-ink placeholder:text-ink-45 transition-colors focus:border-ink focus:outline-none disabled:opacity-40
```

Plain `.field`. Variants: numeric/path/seed add `t-mono` and a width (`w-16 text-right`, `w-20`, `w-72`); dense rows `h-7 text-[11px]`; search `w-72` with placeholder listing the fields it searches (`Search title, style, lyrics, seed`). Never a leading icon inside the field; never a border box for single lines.

## Textarea

```
w-full resize-none border border-ink-25 bg-transparent px-3 py-2 text-[14px] leading-relaxed text-ink placeholder:text-ink-45 transition-colors focus:border-ink focus:outline-none disabled:opacity-40
```

Plain `.field-box`. Editors add `t-mono text-[13px]` and `line-height: 1.55; tab-size: 2`; a stats line under them in `t-mono text-[11px] text-ink-45` (`3 sections · 24 lines · 180 words`, `1,204 / 12,000`). Insert chips above an editor: `t-mono h-7 border border-ink-25 px-2 text-[11px] text-ink-70 hover:border-ink hover:bg-ink hover:text-paper`.

## Label, help, unit

```
Label:  t-micro flex items-center justify-between text-ink-70
  hint: normal-case tracking-normal text-ink-45    (usually <span class="t-mono">3:00</span>)
Help:   text-[11px] leading-snug text-ink-45       (under the control)
Unit:   t-micro text-ink-45                        (after a number input: GB, LUFS, s)
Stack:  flex flex-col gap-2                        (label / control / help)
```

Plain `.label`, `.label .hint`, `.help`, `.stack`.

## Select

Trigger:

```
inline-flex w-full items-center justify-between gap-2 border border-ink-25 bg-paper px-3 text-left text-[13px] text-ink transition-colors hover:border-ink focus:border-ink focus:outline-none data-[placeholder]:text-ink-45 data-[state=open]:border-ink no-drag
+ h-9        (md)
+ h-8 text-[12px]   (sm)
caret: <span class="text-[10px] text-ink-70">▼</span>
```

Popup (Radix `position="popper" sideOffset={-1}`):

```
content: z-50 min-w-[var(--radix-select-trigger-width)] border border-ink bg-paper
item:    relative flex cursor-default select-none flex-col border-b border-ink-12 px-3 py-2 text-[13px] outline-none last:border-b-0 data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[state=checked]:font-medium
help:    text-[11px] opacity-60
```

Plain: `.select` / `.select-sm` (native, with an inline SVG caret), or `.list` + `.list-item` + `.list-label` + `.list-sep` for a custom popup. Option help text pattern: `Composes an editable score before rendering. Most controllable.`

## Segmented

```
wrap: inline-flex border border-ink no-drag
cell: px-3 font-medium uppercase tracking-[0.08em] transition-colors duration-[120ms]
      + border-l border-ink (not first)
      + h-9 text-[11px] (md) | h-7 text-[10px] (sm)
      + bg-ink text-paper (selected) | text-ink hover:bg-ink-06
```

Plain `.segmented` / `.segmented-sm`, cells with `.is-on` or `aria-pressed`. Use for 2–5 exclusive values: `Simple | Custom`, `Grid | List`, `1 | 2 | 4 | 8`, `Both | Notation | ABC`.

## Tabs

```
list:    flex items-end gap-6 border-b border-ink-12 no-drag
trigger: t-micro -mb-px border-b-2 border-transparent pb-2 text-ink-45 transition-colors hover:text-ink data-[state=active]:border-ink data-[state=active]:text-ink disabled:opacity-30
```

Plain `.tabs` / `.tab.is-active`. A tab label may carry a mono suffix: `Score · draft`.

## Switch

```
root:  relative h-[18px] w-9 shrink-0 border border-ink bg-paper transition-colors duration-[120ms] data-[state=checked]:bg-ink disabled:opacity-30 no-drag
thumb: block size-3 translate-x-[2px] bg-ink transition-transform duration-[120ms] data-[state=checked]:translate-x-[20px] data-[state=checked]:bg-paper
```

Plain `.switch` (`aria-checked`). Inline label form: `<label class="flex items-center gap-2 text-[11px] text-ink-70"><Switch/> Rank & pick the best</label>`.

## Checkbox

Native `input[type=checkbox]`: 14px square, `border 1px ink`, paper; checked = ink fill. No check mark glyph.

## Slider

Native `input[type=range]` styled in `master-ui.css`; set `--pct` to the fill percentage. 1px track (ink to `--pct`, ink-25 after), 10px square thumb (ink with 1px paper border), `cursor: ew-resize`. Always paired with a readout: the label hint in mono, or a `t-mono h-7 w-20 text-right text-[12px]` number input, and often a min/max line `t-mono flex justify-between text-[11px] text-ink-45`.

## Meter

```
wrap: flex gap-[2px]
cell: h-2 flex-1 border border-ink transition-colors   + bg-ink (on) | bg-paper   + hover:bg-ink-25 when clickable and off
```

Plain `.meter` with `.is-on` cells. Six cells for a quality score, twelve for VRAM.

---

## Tooltip

```
z-[60] max-w-xs bg-ink px-3 py-2 text-[12px] leading-snug text-paper     sideOffset 6, delay 300
```

Plain `.tooltip`. No arrow. Content is a sentence or a shortcut.

## Menu (dropdown / context)

```
content:    z-50 min-w-52 border border-ink bg-paper text-[13px]      sideOffset 4, align end
item:       flex cursor-default select-none items-center gap-3 px-3 py-2 outline-none transition-colors data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[disabled]:opacity-30 [&_svg]:size-3.5
danger:     + font-medium, label prefixed ✕
separator:  h-px bg-ink-12
label:      t-micro px-3 pb-1 pt-2 text-ink-45
sub trigger: + data-[state=open]:bg-ink data-[state=open]:text-paper
sub content: z-50 min-w-44 border border-ink bg-paper text-[13px]      sideOffset -1
```

Plain `.list`, `.list-item`, `.list-label`, `.list-sep`. Trigger: ghost `icon-sm` `MoreHorizontal`.

## Popover

```
z-50 border border-ink bg-paper p-3 outline-none     sideOffset 4
```

Plain `.popover`. A list popover uses `p-0` and a header strip `flex items-center justify-between border-b border-ink px-3 py-2` with a micro-caps title and a ghost `sm` action.

## Dialog

```
overlay: fixed inset-0 z-50 bg-overlay
content: fixed left-1/2 top-1/2 z-50 w-[calc(100%-2rem)] -translate-x-1/2 -translate-y-1/2 border border-ink bg-paper p-6 focus:outline-none
         + max-w-sm (sm) | max-w-lg (md) | max-w-2xl (lg) | max-w-4xl (xl)
title:   t-h2 pr-8
desc:    mt-1 text-[13px] text-ink-70
body:    mt-5
close:   absolute right-4 top-4 p-1 text-ink-45 transition-colors hover:text-ink    (X size-4)
footer:  flex justify-end gap-2   → ghost Cancel, then primary
big footer: flex items-center justify-between border-t-2 border-ink pt-4   → caveat text left, CTA right
```

Plain `.dialog` (`-sm`, `-lg`, `-xl`), `.dialog-title`, `.dialog-desc`, `.dialog-body`, `.dialog-close`, `.dialog-footer`, `.bar`. Inside big dialogs: `grid grid-cols-2 gap-6` and `grid grid-cols-3 gap-6 border-t border-ink pt-4`.

## Drawer

```
backdrop: absolute inset-0 z-40 bg-overlay            (fade 120ms)
panel:    absolute bottom-0 right-0 top-0 z-50 w-[min(800px,85vw)] border-l border-ink bg-paper
          motion: initial {x:24, opacity:0} → {x:0, opacity:1}, 180ms, ease [0.2,0,0,1]
header:   flex items-start gap-5 border-b border-ink p-6
next rail: grid grid-cols-4 border-b border-ink; cell: border-r border-ink p-3 text-left hover:bg-ink hover:text-paper; title t-micro "{title} →"; body text-[11px] leading-snug opacity-70
```

Plain `.drawer`, `.drawer-backdrop`. `Esc` closes; close button is ghost `icon` `X` in the header.

## Command palette

```
overlay: fixed inset-0 z-[70] bg-overlay
content: fixed left-1/2 top-[15vh] z-[70] w-[min(640px,90vw)] -translate-x-1/2 border border-ink bg-paper focus:outline-none
row:     flex items-center gap-3 border-b border-ink px-4
prompt:  <span class="t-mono blink text-ink-45">→</span>
input:   h-12 flex-1 bg-transparent text-[15px] outline-none placeholder:text-ink-45
kbd:     <Kbd>Esc</Kbd>
list:    max-h-[50vh] overflow-y-auto
result:  flex w-full items-center gap-4 border-b border-ink-12 px-4 py-2.5 text-left text-[13px] last:border-b-0   + bg-ink text-paper (selected)
group:   t-micro w-12 shrink-0 text-ink-45   (text-paper/60 when selected)
hint:    t-mono truncate text-[11px] text-ink-45
empty:   px-4 py-6 text-[13px] text-ink-45  "No matches."
```

Plain `.palette*`. Keys: `Ctrl K` toggles, arrows move, mouse-enter selects, Enter runs, Esc closes. Groups in order: navigation (`Go`), object actions, `App`, search results.

## Toast

Sonner with every colour variable set to ink/paper; `border-radius: 0 !important; box-shadow: none !important; font-family: var(--font-sans)`; `position="bottom-right" offset={104}` (clears an 88px footer); `text-[13px]`; action button paper-on-ink. Plain `.toast`.

---

## Badge, chip, tag, kbd, numeral, rule

```
Badge:   t-micro inline-flex h-5 items-center border px-1.5   + border-ink-25 text-ink-70 | border-ink bg-ink text-paper (invert)
Chip:    t-micro shrink-0 border border-current px-1            (Cover, Remix, Var., Instr.)
Tag:     h-7 border border-ink-25 px-2.5 text-[12px] text-ink-70 hover:border-ink hover:text-ink   + border-ink bg-ink text-paper (selected)
Kbd:     t-mono border border-ink-25 px-1.5 py-0.5 text-[10px] text-ink-70
Numeral: t-mono text-[11px] text-ink-45      String(n).padStart(2,'0')
Rule:    h-px bg-ink-12 border-0   |  strong: h-[2px] bg-ink
Score chip: t-mono inline-flex items-center gap-1 border px-1 text-[10px]  border-current (border-paper/60 on inverted); #1 rank → inverted
Stars:   t-mono inline-flex text-[11px] tracking-[0.1em]   ★ (opacity-100) ☆ (opacity-30)
```

Plain `.badge`, `.badge-invert`, `.chip`, `.tag.is-on`, `.kbd`, `.numeral`, `.rule`, `.rule-strong`.

## Progress, skeleton, spinner, live dot, marquee

```
Progress:  relative h-[3px] w-full overflow-hidden bg-ink-12
  fill:    h-full bg-ink transition-[width] duration-300 ease-linear
  indet.:  hatch-live absolute inset-0
  install: h-[6px]
Skeleton:  skeleton  (+ h-8 w-48 / h-24 w-full …)
Spinner:   size-4 animate-spin text-ink-70  (Loader2)
Live dot:  breathe size-1.5 bg-ink   | bg-paper on inverted | bg-current in chips
Marquee:   overflow-hidden whitespace-nowrap → <span class="marquee"><span class="pr-8">t</span><span class="pr-8">t</span></span> when overflowing, else block truncate
```

Plain `.progress > .fill`, `.progress.is-indeterminate`, `.skeleton`, `.spinner`, `.dot.breathe`, `.marquee`.

## Empty state

```
wrap:  flex flex-col items-start gap-4 px-8 py-16     (boxed: border border-ink p-10)
title: t-display max-w-2xl        "Nothing yet."
body:  max-w-md text-[14px] text-ink-70
action: mt-2 → primary button
```

Plain `.empty`, `.empty-title`, `.empty-body`, `.empty-boxed`. Inside a list column the padding is `px-6 py-16` and the body `max-w-xs`. A tiny inline empty is just `t-micro text-ink-45` (`Queue is empty`, `Nothing playing`).

## Section title, strip, settings row, stat stack

```
SectionTitle: mb-4 flex items-end justify-between border-b border-ink pb-2 ; h2: t-h2 flex items-baseline gap-3 (+ Numeral)
Strip:        t-micro flex items-center justify-between border-b border-ink px-8 py-3 text-ink-45      "Active … 3"
Row:          grid grid-cols-[260px_1fr] items-center gap-6 border-b border-ink-12 py-3 last:border-b-0 ; label text-[13px] ; help mt-0.5 text-[11px] leading-snug text-ink-45 ; control flex items-center gap-3
Stat:         t-micro text-ink-45 (label) / text-[14px] (value) ; grid grid-cols-2 gap-x-8 gap-y-3
Warning box:  border border-ink p-3 text-[12px]
Legal/footnote: mt-6 max-w-2xl text-[11px] leading-relaxed text-ink-45
```

Plain `.section-title`, `.strip`, `.row`, `.row-label`, `.row-control`, `.stat-label`, `.stat-value`.

## Feed row, grid tile, typographic tile

```
FeedRow: group relative flex cursor-pointer items-center gap-4 border-b border-ink-12 px-6 py-3 transition-colors duration-[120ms]   + bg-ink text-paper (current) | hover:bg-ink-06
  art:    size-16 (size-12 compact) ; overlay play: absolute inset-0 flex items-center justify-center bg-paper/85 text-ink opacity-0 transition-opacity duration-[120ms] group-hover:opacity-100 (+ bg-ink/85 text-paper when current)
  title:  truncate text-[15px] font-medium   + chips
  sub:    truncate text-[12px] text-ink-70        (text-paper/70 when current)
  meta:   t-mono mt-1 flex items-center gap-2 text-[11px] text-ink-45   (text-paper/60 when current)   items joined by <span>·</span>
  actions: flex shrink-0 items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100 (+ opacity-100 when liked/current)

GridTile: group flex cursor-pointer flex-col border-b border-r border-ink-12 p-4 transition-colors hover:bg-ink-06
  art:    aspect-square w-full
  play:   absolute bottom-2 right-2 flex size-10 items-center justify-center border border-ink bg-paper text-ink opacity-0 transition-opacity duration-[120ms] hover:bg-ink hover:text-paper group-hover:opacity-100
  menu:   absolute right-2 top-2 opacity-0 group-hover:opacity-100
  text:   mt-3 ; title truncate text-[14px] font-medium ; sub truncate text-[12px] text-ink-70 ; meta t-mono mt-1 flex gap-2 text-[11px] text-ink-45

Tile: relative shrink-0 select-none overflow-hidden   + bg-ink text-paper | border border-ink bg-paper text-ink (outline) | hatch-live bg-paper text-ink (pending)
  style: container-type: inline-size; background-image/size from art()
  label: absolute inset-0 flex items-end p-[8%] font-bold uppercase leading-[0.9] tracking-[-0.03em] + text-[46cqw] (initial) | text-[19cqw]/[15cqw] (two words) | text-[22/16/13cqw] (full)
  live:  absolute left-[8%] top-[8%] → span breathe block size-[10%] min-h-1.5 min-w-1.5 bg-paper (bg-ink on outline)
```

Plain `.feed-row(.is-current)`, `.tile-grid`, `.tile(.tile-outline | .tile-pending)`, `.tile-label`, `.tile-live`. Raster generator: `react/art.ts`.

## Step strip, cells, stage list, drop zone, notice

```
Steps:  flex border border-ink ; step: t-micro flex h-8 items-center gap-2 border-r border-ink px-3 last:border-r-0 + bg-ink text-paper (current) | hover:bg-ink-06 (done) | text-ink-45 (future) ; numeral t-mono "01"
Cells:  grid grid-cols-3 border border-ink ; cell: flex flex-col gap-2 p-5 (+ border-r border-ink) ; t-mono text-[11px] text-ink-45 / t-h2 / text-[12px] text-ink-70 / t-micro mt-2 text-ink-45
Stage:  flex items-center gap-3 py-1 ; glyph t-mono w-3 text-[11px] (✓ ● – ✕ ○) or breathe mx-[3px] block size-1.5 bg-ink ; label min-w-0 flex-1 truncate text-[12px] (text-ink-45 pending/skipped) ; right t-mono shrink-0 text-[11px] text-ink-70 ; running: mt-1 flex items-center gap-2 pl-6 + Progress
Checklist row glyphs: t-mono w-4 text-[13px]  ○ (unknown) ✓ (ok) ! (failed)
Dropzone: flex flex-col items-start gap-4 border border-ink p-10 transition-colors + bg-ink text-paper (dragging)
Notice:   flex items-center gap-4 bg-ink px-4 py-2 text-[13px] text-paper (system) | flex items-center gap-4 border border-ink px-4 py-3 text-[13px] (info) ; kicker t-micro ; actions t-micro link
Timeline: flex h-8 w-full border border-ink ; block bg-ink text-paper (emphasis) | hatch (held) ; label t-micro
Structure strip: flex min-h-[220px] flex-1 flex-col border border-ink ; block flex min-h-6 flex-col justify-between border-b border-ink px-2 py-1 last:border-b-0 + bg-ink text-paper (chorus) ; instrumental: hatch flex flex-1 items-end p-2 + <span class="t-micro bg-paper px-1">Instrumental</span>
Lineage tree: border border-ink ; rows border-b border-ink-12 py-1.5 text-[12px] + bg-ink text-paper (current) ; glyphs └ • in t-mono opacity-50
```

Plain `.steps`/`.step`, `.cells`/`.cell`, `.stage`, `.dropzone.is-over`, `.notice`/`.notice-invert`.

## Shell parts

```
TitleBar: drag-region relative z-40 flex h-[var(--shell-top-h)] shrink-0 items-center justify-between border-b border-ink bg-paper pl-4   (paddingRight 150 in Electron on Windows, else 16)
  wordmark: flex select-none items-center gap-2 whitespace-nowrap ; Mark size-5 ; text-[13px] font-bold uppercase tracking-[-0.02em]
  running pill: no-drag t-micro flex h-6 items-center gap-2 border border-ink px-2 hover-invert ; breathe size-1.5 bg-current ; title normal-case tracking-normal max-w-[240px] truncate ; t-mono 57%
  update pill: t-micro flex h-7 items-center gap-2 border border-ink px-2 hover-invert ; ready: bg-ink px-2 text-paper hover:bg-paper hover:text-ink hover:outline hover:outline-1 hover:outline-ink
  search: flex h-7 items-center gap-2 border border-ink-25 px-2 text-ink-45 transition-colors hover:border-ink hover:text-ink ; Search size-3.5 ; t-micro "Search" ; Kbd "Ctrl K"
  status: t-micro flex items-center gap-2 hover:underline ; dot size-1.5 bg-ink (+ breathe when running) ; error: bg-ink px-2 py-1 text-paper ; text parts joined " · " max-w-[360px] truncate
Sidebar:  flex w-[var(--sidebar-w)] shrink-0 flex-col border-r border-ink bg-paper
  nav:    flex flex-col border-b border-ink
  item:   group flex h-14 items-center gap-4 border-b border-ink-12 px-5 text-left transition-colors duration-[120ms] last:border-b-0 + bg-ink text-paper | hover:bg-ink-06
          numeral t-mono text-[11px] (text-paper/60 | text-ink-45) ; label t-h2 flex-1 ; count t-mono text-[11px] ; arrow text-[16px] transition-transform duration-[120ms] (-translate-x-1 opacity-0 group-hover:translate-x-0 group-hover:opacity-100 | translate-x-0)
  now:    flex items-center gap-3 border-t border-ink p-4 text-left hover:bg-ink-06 ; art size-12 ; t-micro text-ink-45 Playing/Paused ; truncate text-[13px] font-medium
  foot:   flex items-center justify-between border-t border-ink px-5 py-3 ; t-micro link (text-ink when active else text-ink-70)
Footer:   relative z-30 flex h-[var(--shell-bottom-h)] shrink-0 items-center gap-6 border-t-2 border-ink bg-paper px-4
  left:   flex w-[280px] min-w-0 items-center gap-3 ; art size-14 ; Marquee text-[14px] font-medium ; truncate text-[12px] text-ink-45 ; empty: size-14 border border-ink-25 + t-micro text-ink-45 "Nothing playing"
  centre: flex min-w-0 flex-1 flex-col items-center gap-1 ; transport flex items-center gap-1 (ghost icon-sm / ghost icon / primary icon-lg / ghost icon / ghost icon-sm) ; flex w-full max-w-3xl items-center gap-3 ; times t-mono w-10 text-[11px] text-ink-70 ; Waveform height 28
  right:  flex w-[220px] items-center justify-end gap-2 ; ghost icon-sm ; Slider w-24 ; queue Popover w-80 p-0
Page skeleton: flex h-full flex-col gap-6 p-8 → skeleton h-8 w-48 / h-24 w-full / h-24 w-full / h-24 w-2/3
Engine banner: flex items-center gap-4 bg-ink px-4 py-2 text-[13px] text-paper ; t-micro "Engine" ; flex-1 truncate message ; t-micro link actions
```

Plain `.shell`, `.shell-top`, `.shell-middle`, `.shell-main`, `.shell-bottom`, `.wordmark`, `.pill`, `.pill-soft`, `.rail`, `.rail-nav`, `.rail-item(.is-active)`, `.rail-foot`.

---

## Tailwind v3 equivalent

If a project is on Tailwind 3, put this in `tailwind.config.js` instead of importing `master-ui.tailwind.css`:

```js
module.exports = {
  theme: {
    borderRadius: { none: '0', DEFAULT: '0', sm: '0', md: '0', lg: '0', xl: '0', '2xl': '0', '3xl': '0', full: '0' },
    boxShadow: { none: 'none', DEFAULT: 'none', sm: 'none', md: 'none', lg: 'none', xl: 'none', '2xl': 'none', inner: 'none' },
    extend: {
      colors: {
        paper: 'var(--paper)', ink: 'var(--ink)',
        'ink-70': 'var(--ink-70)', 'ink-45': 'var(--ink-45)', 'ink-25': 'var(--ink-25)', 'ink-12': 'var(--ink-12)', 'ink-06': 'var(--ink-06)',
        overlay: 'var(--overlay)'
      },
      fontFamily: { sans: 'var(--font-sans)', mono: 'var(--font-mono)' },
      transitionTimingFunction: { swiss: 'var(--ease)' }
    }
  }
}
```
