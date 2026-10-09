# Transforming an existing app

How to take an app that already exists and make it a member of the family. The order matters: foundation first, then chrome, then screens, then copy. Do not restyle component by component from the top of the file list; you will end up with a half-converted app that looks worse than either end state.

## 0. Audit (30 minutes)

Run the linter to see the size of the job:

```bash
node master-ui/check.mjs ./src
```

(`check.mjs` is copied into the project by `init`, so this works without the kit repo). Then walk the app and list: every colour in use and what it means (accent, success, danger, brand, chart series); every rounded thing; every shadow; every icon-only control; every place a coloured badge or dot carries state; the fonts; the toast library; the icon library; the theme mechanism. Each of those is a mapping decision below.

## 1. Foundation (one commit)

1. Copy `master-ui/css/master-ui.css` and import it first, before your own styles. Add `master-ui.tailwind.css` (Tailwind 4) or the Tailwind 3 config from `COMPONENTS.md`.
2. Install Inter (`FONTS.md`). Delete other font imports.
3. Put `data-theme="light"` on `<html>`; wire a theme store (`react/theme.ts`) that flips it and persists.
4. Delete your colour palette. Keep only what maps to `--paper`, `--ink` and the alpha ramp.
5. Delete radius and shadow tokens; the kit sets them to 0 / none.
6. Replace the toast library's theme with the ink-box overrides (`master-ui.css` has the Sonner block; port the idea for others).
7. Switch icons to lucide if they are not already; drop filled/duotone sets.

At this point the app looks broken (things that relied on colour lose meaning). That is expected; the next steps give the meaning back.

## 2. Chrome

Rebuild the shell before any page: title bar (40, wordmark, status pill, search + `Ctrl K`), index rail (232, numerals, inversion), footer/status bar (88, strong rule) — see `LAYOUT.md` §1 and `react/Shell.tsx`. Add the command palette. Once the shell is right, every page you convert is framed correctly and the app already reads as family.

## 3. Mapping table

| You have | Replace with |
|---|---|
| accent colour on primary buttons | `primary` = ink fill, paper text; inverts on hover |
| brand colour anywhere else | nothing; the wordmark is ink |
| coloured badges for status (green/amber/red) | micro-caps word + `Badge` neutral/invert; running = breathing square; failed = inverted row + `✕ Failed` |
| coloured dot for "online" | 6px ink square, breathing while active |
| red text / red border for errors | inverted bar or row; the message verbatim |
| green success banner | a toast (`Saved`), or nothing |
| yellow warning box | outlined notice bar, or ink-70 text prefixed `—` |
| info blue box | outlined notice bar |
| link colour | ink text with the sliding underline (`.link`) |
| `rounded-*` | remove (the CSS forces 0 anyway) |
| `shadow-*`, elevation, cards floating on grey | 1px rules; regions divided by hairlines; paper everywhere |
| grey page background with white cards | paper page, no cards, sections separated by rules |
| card grid with gaps | grid with rules (`border-l ink-12`, cells `border-b border-r ink-12`) |
| sidebar with icons | index rail with numerals and `.t-h2` labels |
| top nav with tabs | index rail (desktop) or numeral strip (web) |
| avatar / thumbnail images | typographic tiles from a seed (`react/Tile.tsx`) |
| chart colour series | single ink series; compare with weight/hatch/side-by-side; bars 1px |
| donut / pie | `Meter` cells or a mono number |
| spinner overlay | `PageSkeleton` or an inline `.skeleton`; a breathing square for background work |
| modal with dark backdrop + blur | paper overlay at 85%, ink frame dialog, ghost Cancel + primary |
| slide-over with shadow | drawer with `border-l ink`, 24px slide |
| dropdown with shadow and radius | `Menu` ink frame, rows with hairlines, highlight inverts |
| floating labels / placeholder-as-label | `.t-micro` label above, underline input |
| bordered text inputs | underline-only inputs (`Input`); boxes are for textareas |
| toggle with coloured "on" | square switch, ink when on |
| pill tags | square tags, ink-25 border, inverted when selected |
| Title Case buttons, `Save Changes!` | sentence case, `Save` |
| emoji in empty states | `.t-display` sentence + one line |
| illustration in empty state | remove |
| "Oops! Something went wrong" | the error message |
| `⌘K` | `Ctrl K` in a `Kbd` |
| system-ui / Roboto / Segoe | Neue Haas → Inter with `ss01 cv11` |
| bouncy transitions, 300–500ms ease-in-out | 120ms `--ease`; drawers 180ms |
| skeleton shimmer | `.skeleton` hatch drift |
| dark theme with `#111` and `#eee` | exact inversion: `#000` and `#fff` |

## 4. Screens

Convert one screen fully before the next, in workflow order. For each screen, walk `MASTER-UI.md` §16:

1. header with numeral + `.t-h1` + micro subtitle + actions
2. sections divided by rules
3. labels micro caps, numbers mono
4. one primary action in a `border-t-2` sticky footer
5. selection = inversion, hover = wash
6. running = breathe/hatch, failed = inverted row
7. empty state = `.t-display` sentence
8. inputs underline, textareas boxed, selects `▼`, switches square
9. lint clean
10. copy in voice
11. dark by inversion
12. keyboard

## 5. Copy pass

Last, read every string. Sentence case, no `!`, no emoji, British spelling, ` · ` separators, `≈` estimates, `→` forward, numbers first, units spaced. Rename statuses to the family words (`Queued`, `Working`, `Waiting`, `✕ Failed`). Rewrite empty states and help text per `VOICE.md`.

## 6. Verify

- `master-ui check ./src` → 0 errors.
- Toggle to dark: everything must invert with no tinted surfaces and no invisible canvases (charts must read `--ink` from computed style).
- Open `master-ui/examples/specimen.html` beside the app; compare a button, a row, a dialog, a toast.
- The family test: a screenshot of your app next to Music Master should look like two pages of one product.

## 7. Keeping it that way

Add to CI:

```json
{ "scripts": { "lint:ui": "node master-ui/check.mjs src" } }
```

Add the kit's CLAUDE.md block (done by `init`) so any assistant working on the repo reads the spec before touching UI. Review PRs against §15 of `MASTER-UI.md`.
