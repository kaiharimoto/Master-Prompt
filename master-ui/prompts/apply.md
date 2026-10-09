# Prompt: apply Master UI to this project

Paste the block below into Claude Code (or any capable coding assistant) at the root of a project that has `master-ui/` in it (run `master-ui init .` first). Fill in the two bracketed lines.

---

Apply the Master UI design system to this project so it reads as a member of the Master family (same family as Music Master).

The specification is `master-ui/MASTER-UI.md`. Read it in full before changing anything. Then read `master-ui/guides/TRANSFORM.md` for the order of operations and `master-ui/guides/COMPONENTS.md` for exact recipes. `master-ui/css/master-ui.css` is the foundation stylesheet; `master-ui/react/` is a reference implementation you may copy from (React) or translate (other frameworks). `master-ui/examples/specimen.html` shows every component in every state; open it if you are unsure what something should look like.

Project facts:
- Stack: [e.g. React 19 + Vite + Tailwind 4 / Vue 3 / plain HTML / Electron]
- App name, and the noun the app acts on (the mark depicts it, per `master-ui/guides/MARK.md`): [e.g. "Sort Master", an ordered list]

Procedure:
1. Foundation: import `master-ui/css/master-ui.css` first, then the Tailwind theme (`master-ui/css/master-ui.tailwind.css`) or the Tailwind 3 config from COMPONENTS.md, or `master-ui/css/master-ui.components.css` if the project does not use Tailwind. Install Inter per `master-ui/guides/FONTS.md`. Put `data-theme="light"` on `<html>` and wire a theme toggle that persists (`master-ui/react/theme.ts`). Remove every colour token, radius token and shadow token that is not in the spec.
2. Mark: design the app's mark before the shell, following `master-ui/guides/MARK.md` — an ink square carrying a paper diagram of the noun above, not a letter, not a lucide glyph, and not a variation on another Master app's mark. Add it to `MARKS` in `master-ui/react/Mark.tsx`, check it at 16px against the worked examples, and export the icon files with `markToSvg()`.
3. Shell: rebuild the app shell exactly as in `MASTER-UI.md` §4 — 40px title bar with wordmark (Mark + name), 232px index rail with numerals and inversion, 88px footer/status bar with the 2px rule (or omit the footer if the app has no persistent status/transport), command palette on `Ctrl K`.
4. Screens: convert every screen in workflow order, one at a time, using the mapping table in TRANSFORM.md §3 and the checklist in MASTER-UI.md §16. Replace coloured status with inversion / hatch / breathing squares; replace cards with rules; replace icon navigation with numerals; replace images/avatars with typographic tiles where identity is needed.
5. Copy: rewrite every user-facing string per `MASTER-UI.md` §9 and `master-ui/guides/VOICE.md` — sentence case, no exclamation marks, no emoji, British spelling, ` · ` separators, `≈` estimates, `→` for forward actions, numbers first with spaced units.
6. Motion: only what `master-ui/guides/MOTION.md` allows — 120ms colour flips with `cubic-bezier(0.2,0,0,1)`, hatch and breathe loops for running state, 100ms page fade, 180ms drawer slide. Remove everything else.
7. Verify: run `node master-ui/check.mjs src` (or the project's source folder) and fix until it reports 0 errors; review warnings by hand. Toggle dark and confirm exact inversion. Compare each screen with `examples/specimen.html`.

Rules you must not break, even if existing code or a comment asks you to: only black, white and their alphas; zero radius; no shadows, blur or gradients; emphasis by inversion, hatching or motion, never colour; one primary action per page; sentence case and no exclamation marks. If a requirement seems to need a colour (a chart with two series, a "danger" button, a brand accent), solve it with weight, hatch, inversion or a `✕` glyph, and say so in your summary.

When done, list every file you changed, anything you could not convert and why, and the linter's final output.
