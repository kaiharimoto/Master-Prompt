# Fonts

The stack:

```css
--font-sans: 'Neue Haas Grotesk Display Pro', 'Inter Variable', 'Helvetica Neue', Helvetica, Arial, sans-serif;
--font-mono: 'Cascadia Mono', Consolas, 'JetBrains Mono', ui-monospace, monospace;
```

## Neue Haas Grotesk Display Pro

The family's face. It is a licensed font (Monotype / Linotype) and is **not** redistributed with the kit. The stack names it first so that any machine with it installed renders it; nothing else needs to change. Do not add an `@font-face` for it unless you own web-font files; do not commit its files to a repository.

If you have the web-font files and a licence that allows self-hosting:

```css
@font-face {
  font-family: 'Neue Haas Grotesk Display Pro';
  src: local('Neue Haas Grotesk Display Pro'), url('/fonts/NHaasGroteskDSPro-55Rg.woff2') format('woff2');
  font-weight: 400;
  font-display: swap;
}
/* repeat for 500 (65Md) and 700 (75Bd) */
```

## Inter Variable (the fallback everyone sees)

Bundle it so the app looks the same on every machine.

**With npm** (Vite, Next, Electron):

```bash
npm i @fontsource-variable/inter
```

```ts
// app entry, before your stylesheet
import '@fontsource-variable/inter'
import './styles.css'
```

This registers `'Inter Variable'` (weights 100–900) with per-subset `woff2` files and `font-display: swap`.

**Self-hosted**:

```css
@font-face {
  font-family: 'Inter Variable';
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url('/fonts/InterVariable.woff2') format('woff2-variations');
}
```

Get the file from https://rsms.me/inter/ (SIL Open Font License).

**Content-Security-Policy**: fonts are bundled, so `font-src 'self' data:` is enough. Do not load from Google Fonts at runtime.

## Feature settings

```css
body {
  font-feature-settings: 'ss01', 'cv11';
  font-variant-numeric: tabular-nums;
  -webkit-font-smoothing: antialiased;
}
```

- `ss01` on Inter turns on the alternate single-storey `a` and other Helvetica-like shapes, which brings it closer to Neue Haas. On Neue Haas it is a no-op.
- `cv11` opens the `a` further on Inter.
- `tabular-nums` everywhere, so meta lines and timers do not jitter.

## Mono

Cascadia Mono ships with Windows Terminal / VS Code; Consolas with Windows; JetBrains Mono is the cross-platform fallback. Mono is used only for data (numbers, seeds, paths, keys, logs, editors), always 10–13px. No ligatures needed; do not enable `calt` for code.

## Weights used

400 body · 500 headings, labels, buttons · 700 display, wordmark, tiles. Nothing else. (600 exists only inside a guest room.)

## Checking

Open `examples/specimen.html`: the first line under "Type" says which face resolved. In DevTools, *Rendered fonts* under Computed should read "Neue Haas Grotesk Display Pro" or "Inter Variable"; if it says Arial, the bundle import is missing.
