---
name: master-ui
description: Apply or review the Master UI design system (Brutalist Swiss Minimal — paper and ink only, zero radius, no shadows, emphasis by inversion/hatching/motion, Neue Haas/Inter, numbered pages, quiet sentence-case voice). Use when building or restyling any UI that should belong to the Master family (Music Master and siblings), when the user says "Master UI", "make it look like Music Master", "family look", or when a project contains a master-ui/ folder and the task touches UI, CSS, components, copy or theming.
---

# Master UI

You are working in the Master UI design system. The specification is the file next to this one, `MASTER-UI.md`. Read it fully once per session before touching UI. It is short enough to keep in context; do not summarise it from memory.

## When the task is to build or change UI

1. Read `MASTER-UI.md`. Keep §15 (Do / Don't) and §16 (checklist) in mind.
2. For exact class strings, read `guides/COMPONENTS.md`. For page structure, `guides/LAYOUT.md`. For animation, `guides/MOTION.md`. For strings, `guides/VOICE.md`. For the app icon, `guides/MARK.md`.
3. Use the foundation in `css/master-ui.css` (and `css/master-ui.tailwind.css` for Tailwind 4, or `css/master-ui.components.css` for plain CSS). Copy from `react/` when the project is React.
4. Never introduce: a colour other than black/white/their alphas; a radius; a shadow, blur or gradient; an emoji; an exclamation mark; a spinner where a breathing square or live hatch belongs; a card where a rule belongs; an icon where a numeral belongs.
5. After changes, run `node master-ui/check.mjs <src>` (the file is copied into the project by `init`; otherwise `node <kit>/lib/check.mjs <src>`) and fix every error. Report the final output.

## When the task is to convert an existing app

Follow `guides/TRANSFORM.md` in order: foundation → shell → screens → copy → verify. Use the mapping table for every colour, radius, shadow and icon you meet. Do not convert component by component out of order.

## When the task is to review

Use `prompts/review.md` as the rubric. Cite sections. Never propose colour, radius, shadows or illustrations as fixes.

## Judgement calls

When the spec is silent, derive from the laws in §1: two fills, zero radius, no depth, emphasis by inversion/hatch/motion, type does the work, rules not gaps, dark is exact inversion, quiet voice. Ask "what would a Swiss typographer do with one ink and one paper". Prefer removing something over adding something.

The one sanctioned exception is a guest room (§14) for a third-party presence such as Claude; it is off unless the project explicitly includes `css/claude-room.css`.
