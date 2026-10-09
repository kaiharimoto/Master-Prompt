# Motion

Motion in Master UI is a material, not a decoration. It has three jobs: confirm a state change (colour flips), show that the machine is working (hatch, breathe), and keep a title readable (marquee). Nothing else moves.

## 1. The vocabulary

| Token | Value |
|---|---|
| `--ease` | `cubic-bezier(0.2, 0, 0, 1)` — fast out, settles. The only easing for transitions. |
| `--dur-fast` | 120ms — colour, background, border, opacity reveals, chevrons, arrows |
| `--dur` | 180ms — link underline, drawer slide |
| `--dur-slow` | 320ms — the largest transition; glyph transforms only |
| linear | hatch drift, skeleton drift, progress width, marquee |
| `ease-in-out` | the breathe loop and the guest spark loops only |

## 2. Transitions (state changes)

```css
/* colour flip: every button, row, cell, tab, tag */
transition: background-color 120ms var(--ease), color 120ms var(--ease), border-color 120ms var(--ease);

/* reveal on hover: row actions, play overlays, grid menus */
opacity: 0 → 1, 120ms

/* rail arrow */
transform: translateX(-4px) → 0, opacity 0 → 1, 120ms

/* chevron */
transform: rotate(0) → rotate(180deg), 120ms

/* link underline */
background-size: 0% 1px → 100% 1px, 180ms

/* progress bar */
width, 300ms linear

/* field border on focus */
border-color, 120ms
```

Tailwind: `transition-colors duration-[120ms]`, `transition-opacity duration-[120ms]`, `transition-transform duration-[120ms]`, `transition-[width] duration-300 ease-linear`.

## 3. Entrances

| Thing | Recipe |
|---|---|
| Page swap | the page container is keyed on the route and gets `animate-[fade_100ms_ease-out]` (`@keyframes fade { from { opacity: 0 } to { opacity: 1 } }`) |
| Drawer | `initial { x: 24, opacity: 0 } → animate { x: 0, opacity: 1 } → exit { x: 24, opacity: 0 }`, `duration 0.18`, `ease [0.2, 0, 0, 1]`; backdrop opacity 0 → 1 over 0.12 |
| Side panel | `width: 0 → w, opacity 0 → 1`, `duration 0.22`, same ease |
| Dialogs, menus, popovers, tooltips, toasts | appear instantly (Radix default with no animation classes). Do not add scale-in or slide-in. |
| List items | appear instantly. No stagger. |

With `motion/react`: `<AnimatePresence>{open && <motion.aside … />}</AnimatePresence>`. Without a library: a CSS `@keyframes` with the same numbers.

## 4. Loops (the machine is working)

```css
@keyframes hatch-move { from { background-position: 0 0 } to { background-position: 16px 0 } }
.hatch-live { animation: hatch-move 0.6s linear infinite }   /* running, indeterminate, pending tile */
.skeleton   { animation: hatch-move 1.4s linear infinite }   /* loading placeholder */

@keyframes breathe { 0%, 100% { opacity: 1 } 50% { opacity: 0.35 } }
.breathe { animation: breathe 2.4s ease-in-out infinite }    /* the 6px live square; a playing tile's corner square */

@keyframes blink { 0%, 49% { opacity: 1 } 50%, 100% { opacity: 0 } }
.blink { animation: blink 1s steps(1) infinite }             /* the palette's → prompt; a playhead */

@keyframes marquee { from { transform: translateX(0) } to { transform: translateX(-50%) } }
.marquee { animation: marquee 12s linear infinite }          /* overflowing titles, text duplicated */

.animate-spin                                                 /* Loader2 inside a busy button only */
```

Rules:

- **Breathe is for squares, never text.** A word never pulses. The square is 6px (`size-1.5`) next to a micro-caps word, or 10% of a tile.
- **One loop per region.** A running job row has one breathing square and one hatch progress; not a spinner as well.
- **Hatch means "in progress" and nothing else.** Do not use it as a decorative texture. Static hatch means "placeholder / instrumental / missing".
- **Loops stop under reduced motion.** `@media (prefers-reduced-motion: reduce) { .hatch-live, .skeleton, .marquee, .breathe, .blink { animation: none } }`. The state must still be legible without motion (the hatch is still there, the square is still there).

## 5. Typewriter

When a machine fills a text field on the user's behalf (an assistant writing a prompt), the text types in rather than appearing: `duration = min(2400, 400 + 6 × chars)` ms, quadratic ease-out, driven by `requestAnimationFrame`, instant under reduced motion. See `react/typewriter.ts`.

## 6. Sound (optional)

Off by default; a Settings switch. Synthesised with Web Audio, no assets: a square wave with a 5ms attack and exponential decay. `click()` = 1200 Hz for 60ms at gain 0.04 on the primary action; `done()` = 660 Hz 120ms then 990 Hz 180ms (a rising fifth) when a long job finishes. Nothing else makes a sound. See `react/sound.ts`.

## 7. Not allowed

Hover scale or lift · press scale (except the guest spark) · ripples · spring or bounce curves · durations over 320ms for a transition · staggered entrances · skeleton shimmer gradients · animated gradients · parallax · confetti · bouncing dots · progress bars that ease · anything that moves without a state change behind it.
