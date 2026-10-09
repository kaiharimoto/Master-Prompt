# Layout

How a Master UI app is put together, from the window down to a form field. Values are exact.

## 1. The shell

Three horizontal bands, the middle one split vertically. Everything is flex, nothing is a CSS grid at the shell level.

```
<div class="flex h-full flex-col bg-paper text-ink">
  <header>  title bar  h-[var(--shell-top-h)]=40  border-b border-ink  z-40  drag-region
  <banner>  optional system notice (inverted bar), only while there is a problem
  <div class="relative flex min-h-0 flex-1">
    <aside> index rail  w-[var(--sidebar-w)]=232  border-r border-ink
    <main class="relative min-w-0 flex-1 overflow-hidden">
      <div key={page} class="h-full animate-[fade_100ms_ease-out]"> page </div>
      <drawer/>      absolute, right, z-50, over the main area only
    </main>
    <aside> optional guest panel, border-l border-ink, animated width
  </div>
  <footer>  transport / status bar  h-[var(--shell-bottom-h)]=88  border-t-2 border-ink  z-30
</div>
<command palette/>  z-70
<toaster position="bottom-right" offset={104}/>
```

- The rail and footer are hidden during first-run setup (`chrome = false`); the title bar always shows.
- The drawer is `absolute` inside `main`, so the rail and footer stay visible and usable while it is open.
- Dialogs are `fixed` and cover the whole window under the paper overlay.
- Window (Electron): 1440×900, min 1024×680, `titleBarStyle: 'hidden'`, `titleBarOverlay { color: paper, symbolColor: ink, height: 40 }`, `autoHideMenuBar: true`, `backgroundColor: paper`. On theme change update `nativeTheme.themeSource`, `setBackgroundColor`, `setTitleBarOverlay`.

### Title bar (40px)

Left: wordmark button (goes home), then a running-job pill when something runs. Right (`no-drag flex items-center gap-4`): update pills, the search trigger, the system status. Right padding 150px on Windows Electron for the native overlay buttons, 16px elsewhere.

### Index rail (232px)

A typographic index, not a sidebar of icons.

- Rows are 56px, `px-5`, `gap-4`: numeral, `.t-h2` label, optional mono count, `→`.
- Active = inverted; hover = wash + the arrow slides in.
- Six to eight entries at most. Order is the workflow order (Create → … → Library → Queue).
- Below the list, pushed to the bottom (`mt-auto`): the "now" strip (current object with its tile and status) and a footer row of micro-caps links (`Settings · Setup · Dark`).
- The rail never scrolls; if you have more entries than fit at 680px, you have too many entries.

### Footer bar (88px)

The only strong rule in the shell. Three zones: identity (280px), the centre control (flexible, content capped at 768px), utilities (220px). If the app has no media transport, the footer can be a status bar (progress of the active job, mono stats, the primary action) or omitted — but keep the `border-t-2` when there is one.

## 2. Pages

### Header

```
<div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b border-ink px-8 pb-4 pt-8">
  <div>
    <h1 class="t-h1 flex items-baseline gap-4"><Numeral n={3}/> Library</h1>
    <p class="t-micro mt-2 text-ink-45">128 songs · 12 liked · 7 rated 4+</p>
  </div>
  <div class="ml-auto flex flex-wrap items-center gap-3"> …actions… </div>
</div>
```

The subtitle is either a stat line (mono-ish numbers joined by ` · `) or one sentence of intent (`One job at a time on the GPU. Drag queued jobs to reorder.`). Actions, left to right: search input (`w-72`), filter selects (`sm`, `w-36`–`w-40`), secondary `sm` buttons, a segmented view switch, micro links, the guest button.

When the page is a form with a preview, the header lives inside the form column (`flex-[7]`) and the preview column gets its own micro-caps strip (`Latest … All songs →`).

### Body

- Forms: `flex flex-col gap-8 px-8 pb-8 pt-8`, sections `grid grid-cols-2 gap-x-10 gap-y-6 border-t border-ink pt-6`.
- Lists: no page padding; rows are edge to edge with `px-6` or `px-8` internal padding; group headers are micro-caps strips.
- Grids: `grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] border-l border-ink-12`; cells `border-b border-r border-ink-12 p-4`.
- Settings: `flex h-full` → nav `w-56 border-r border-ink px-6 pt-8` + content `flex-1 overflow-y-auto px-8 pb-16 pt-8 gap-8`.
- Wizard: `mx-auto max-w-3xl p-12` (or `max-w-5xl p-8 gap-6` for a stepper page).
- Cards: `grid grid-cols-1 gap-4 xl:grid-cols-2` of `flex flex-col gap-3 border border-ink p-5` — one of the few places a frame with a gap is right, because each card is an independent object with its own actions.

### Sticky action footer

```
<div class="sticky bottom-0 z-10 mt-auto flex items-center justify-between gap-6 border-t-2 border-ink bg-paper px-8 py-3">
  <div class="flex items-center gap-6"> [micro label + segmented] [switch + label] [t-mono estimates · badge] </div>
  <Button variant="primary" size="lg" class="min-w-44">Create <ArrowRight/></Button>
</div>
```

One per page, only on pages whose purpose is to produce something. Estimates to its left in `t-mono text-[12px] text-ink-70`, separated by `<span class="text-ink-25">·</span>`.

### Split panes

`<div class="@container flex h-full min-h-0">` → form `flex min-w-0 flex-[7] flex-col overflow-y-auto border-r border-ink @max-[1040px]:border-r-0` + feed `flex min-w-[380px] flex-[5] flex-col overflow-y-auto @max-[1040px]:hidden`.

## 3. Rhythm

| Level | Spacing |
|---|---|
| Page padding | 32 (`p-8`), wizard 48 |
| Between sections | 32 (`gap-8`) + a 1px rule |
| Section internal | 24 (`pt-6`), grid gaps 40 × 24 |
| Field stack | 8 |
| Row padding | 12 vertical × 24–32 horizontal |
| Toolbar gaps | 12 (`gap-3`) |
| Icon–label gap | 8 (`gap-2`) |
| Inline meta gap | 8 with ` · ` |
| Frames | 20 (`p-5`) cells, 40 (`p-10`) empty/drop zones |

Rules beat space. If two regions need separating, draw a hairline (`ink-12`) between rows or a structural rule (`ink`) between sections; do not add margin.

## 4. Widths and caps

| Thing | Width |
|---|---|
| number input | 64 (`w-16`), 80 (`w-20`) |
| short select | 144 (`w-36`), 160 (`w-40`) |
| search input | 288 (`w-72`) |
| slider in a settings row | 256 (`w-64`) |
| volume slider | 96 (`w-24`) |
| queue popover | 320 (`w-80`) |
| tag picker popover | 560 |
| dialog | 384 / 512 / 672 / 896 |
| drawer | `min(800px, 85vw)` |
| palette | `min(640px, 90vw)` |
| prose | `max-w-xs` 320 · `max-w-sm` 384 · `max-w-md` 448 · `max-w-lg` 512 |
| empty title | `max-w-2xl` 672 |
| title bar status | `max-w-[360px]` |
| running pill title | `max-w-[240px]` |

## 5. Layering

`z-10` sticky bars and resize handles · `z-30` footer · `z-40` title bar, drawer backdrop · `z-50` dialogs, menus, selects, popovers, drawer · `z-[60]` tooltips · `z-[70]` command palette.

## 6. Density

Desktop-first at 1024px minimum. There is no mobile layout; a narrow window collapses the preview column (container query at 1040px) and wraps header actions (`flex-wrap`). Row heights: 56 rail, 36 controls, 32 small controls, 28 chips, 20 badges. Text never goes below 9px (waveform section labels) and body never below 13px.

## 7. Responsive web (if the target is a website, not a desktop app)

Keep the same bands. Under 768px: the rail becomes a top strip of numerals (`01 02 03`) with the active one inverted; the footer bar becomes a 56px bar; page padding drops to 16; two-column forms stack. Never introduce a hamburger menu with icons — the index is typographic at every size.
