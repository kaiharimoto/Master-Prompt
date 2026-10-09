# React reference

A portable build of the Master UI primitives, extracted from Music Master. Copy the files you need into your project (they import only each other via `./ui`, `./art`, `./Mark`).

## Dependencies

```bash
npm i react react-dom radix-ui class-variance-authority clsx tailwind-merge lucide-react
npm i -D tailwindcss @tailwindcss/vite            # Tailwind 4
npm i @fontsource-variable/inter                  # the fallback face
npm i motion                                      # optional: drawer / panel transitions
npm i sonner                                      # optional: toasts (styled by master-ui.css)
```

Tested with React 19.3, radix-ui 1.6, cva 0.7, tailwind-merge 3.7, lucide-react 1.47, Tailwind 4.3.

## Wiring

```ts
// main.tsx
import '@fontsource-variable/inter'
import './styles.css'
```

```css
/* styles.css */
@import 'tailwindcss';
@import './master-ui/css/master-ui.css';
@import './master-ui/css/master-ui.tailwind.css';
/* @import './master-ui/css/claude-room.css';   optional guest module */
```

```html
<!-- index.html -->
<html lang="en" data-theme="light">
  <body class="bg-paper text-ink overflow-hidden"><div id="root"></div></body>
```

```tsx
// App.tsx
import { TooltipProvider } from './master-ui/react/ui'
import { Shell, TitleBar, Rail, RailLink, Footer } from './master-ui/react/Shell'
import { CommandPalette } from './master-ui/react/CommandPalette'
import { initTheme, toggleTheme } from './master-ui/react/theme'

useEffect(() => { initTheme({ key: 'xx.theme' }) }, [])

<TooltipProvider>
  <Shell
    pageKey={page}
    top={<TitleBar name="Sort Master" onHome={() => go('home')} onSearch={() => setPalette(true)} status={{ text: 'Ready' }} electronWindows />}
    rail={<Rail items={[{ id: 'home', label: 'Home' }, { id: 'library', label: 'Library' }]} active={page} onSelect={go}
            foot={<><RailLink onClick={() => go('settings')}>Settings</RailLink><RailLink onClick={() => toggleTheme({ key: 'xx.theme' })}>Dark</RailLink></>} />}
    footer={<Footer left={…}>{…}</Footer>}
  >
    {content}
  </Shell>
  <CommandPalette open={palette} onOpenChange={setPalette} commands={commands} />
</TooltipProvider>
```

## Files

| File | What |
|---|---|
| `ui.tsx` | Button, Input, Textarea, Label, Help, Stack, Slider, Switch, Select, Segmented, Tabs, Tip, Menu*, Popover*, Dialog*, DialogFooter, Bar, Badge, Chip, Tag, Progress, Kbd, ScrollArea, Spinner, Rule, Numeral, Hatch, Dot, Marquee, Meter, Skeleton, PageSkeleton, EmptyState, SectionTitle, PageHeader, Strip, Row, Stat, Stage, Notice, Steps, `cn()` |
| `Shell.tsx` | Shell, TitleBar, RunningPill, Rail, RailLink, Footer, Banner, Drawer |
| `CommandPalette.tsx` | Ctrl K palette (generic commands + search) |
| `Tile.tsx` + `art.ts` | typographic tile and the seed-derived raster |
| `Mark.tsx` | Mark (a paper diagram of the app's subject on an ink square), the `MARKS` worked examples, the `bars()` constructor, `markToSvg()` for icon files, and Wordmark |
| `Bars.tsx` | 1px ink bar chart / waveform with marks and playhead |
| `theme.ts` | `initTheme`, `applyTheme`, `toggleTheme` (data-theme + localStorage) |
| `sound.ts` | optional click / done tones |
| `typewriter.ts` | `typeInto` |
| `format.ts` | `formatDuration`, `formatEta`, `timeAgo`, `meta`, `approx`, `numeral`, `unit`, `range` |

## Electron

```ts
new BrowserWindow({
  width: 1440, height: 900, minWidth: 1024, minHeight: 680,
  backgroundColor: '#ffffff', autoHideMenuBar: true,
  titleBarStyle: 'hidden',
  titleBarOverlay: { color: '#ffffff', symbolColor: '#000000', height: 40 }
})
// on theme change:
nativeTheme.themeSource = theme
win.setBackgroundColor(dark ? '#000000' : '#ffffff')
win.setTitleBarOverlay({ color: dark ? '#000000' : '#ffffff', symbolColor: dark ? '#ffffff' : '#000000', height: 40 })
```

Pass `electronWindows` to `TitleBar` so it reserves 150px for the overlay buttons.

## Toasts (sonner)

```tsx
<Toaster position="bottom-right" offset={104} toastOptions={{ className: 'text-[13px]' }} />
```

`master-ui.css` does not ship the Sonner override (it is library-specific); copy this block into your stylesheet:

```css
[data-sonner-toaster] { --normal-bg: var(--ink); --normal-border: var(--ink); --normal-text: var(--paper); --success-bg: var(--ink); --success-border: var(--ink); --success-text: var(--paper); --error-bg: var(--ink); --error-border: var(--ink); --error-text: var(--paper); --info-bg: var(--ink); --info-border: var(--ink); --info-text: var(--paper); --warning-bg: var(--ink); --warning-border: var(--ink); --warning-text: var(--paper); }
[data-sonner-toast] { font-family: var(--font-sans) !important; border-radius: 0 !important; box-shadow: none !important; }
[data-sonner-toast] [data-button] { background: var(--paper) !important; color: var(--ink) !important; border-radius: 0 !important; }
```
