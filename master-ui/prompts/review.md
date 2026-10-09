# Prompt: review against Master UI

Paste this into an assistant with access to the project (or attach screenshots) to get a strict review.

---

Review this UI against the Master UI specification in `master-ui/MASTER-UI.md`. Be strict: the goal is that the screen could sit next to Music Master without a visible seam.

For each screen (or the diff, if I gave you one), report findings in this order, most severe first:

1. **Law breaks** — any colour other than black/white/alphas; any radius; any shadow, blur or gradient; coloured status; emoji or exclamation marks; a second primary action; Title Case labels; a font that is not Neue Haas/Inter.
2. **Structure** — header pattern (numeral + `.t-h1` + micro subtitle + actions right, `border-b border-ink`); sections divided by rules not cards; grids with rules not gaps; one sticky `border-t-2` footer for the primary action; index rail with numerals.
3. **Components** — each control against `guides/COMPONENTS.md`: underline inputs, boxed textareas, `▼` selects, square switches, segmented controls, ink-box tooltips, ink-frame menus and dialogs, ghost Cancel then primary in dialog footers, 3px progress with hatch when indeterminate, `.t-display` empty states.
4. **State** — selected = inversion; hover = wash on rows / inversion on controls; running = breathing 6px square or live hatch with mono progress; failed = inverted row with `✕ Failed`; disabled = opacity .3/.4; focus ring 2px ink.
5. **Type** — scale values, micro caps for labels, mono for numbers, negative tracking on display, weights 400/500/700 only, numerals `01`.
6. **Motion** — 120ms `--ease` flips only; no scale/spring/stagger; loops only for running state; reduced-motion honoured.
7. **Voice** — sentence case, no `!`, British spelling, ` · ` separators, `≈` estimates, `→` forward, spaced units, `Ctrl K` not `⌘K`, empty state = short sentence with a full stop + one line, toasts = state or past tense, errors verbatim.
8. **Mark** (if the app icon is in scope) — does it draw what the app acts on rather than spell a letter? Is it distinguishable from every other Master app at 16px? Does it obey the grammar in `guides/MARK.md` (68×68 field, one weight, straight lines and 45° only, 2–5 elements, paper on ink)?
9. **Dark** — exact inversion; canvases and rasters read `--ink`; no tinted surfaces.

Format each finding as: `file:line` (or screen + element) · the rule (cite the section, e.g. `MASTER-UI §6 Button`) · what is there · what it should be (exact class string or value). End with the count of law breaks and a one-line verdict: passes the family test, or not.

Do not suggest adding colour, radius, shadows, illustrations or icons as a fix for anything. If you believe a rule should be broken, say why in one sentence and still report it as a finding.
