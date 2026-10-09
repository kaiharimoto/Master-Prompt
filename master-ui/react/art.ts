/**
 * Identity without colour: a seed-derived raster pattern for typographic tiles.
 * Deterministic for a seed so the same object always looks the same.
 */

function mulberry32(a: number): () => number {
  return () => {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export type PatternKind = 'lines' | 'dots' | 'cross' | 'diag' | 'bars'

export interface Art {
  kind: PatternKind
  /** CSS background-image (SVG data URI) drawn in `fg` on transparent. */
  backgroundImage: string
  backgroundSize: string
  spacing: number
}

/** Stable 31-bit seed from any string (for objects that have a name but no numeric seed). */
export function seedFrom(text: string): number {
  let h = 2166136261
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return (h >>> 0) % 2147483647 || 1
}

/**
 * `density` (60–160, a tempo-like number) drives spacing when known; `angle12`
 * (0–11, a key-like number) nudges the angle of the diagonal pattern.
 * `fg` should be paper at 50% on an ink tile, ink at 45% on an outlined tile,
 * chosen from the *current* theme colours.
 */
export function artFor(seed: number, opts: { density?: number | null; angle12?: number | null; fg?: string } = {}): Art {
  const rnd = mulberry32(seed || 1)
  const kinds: PatternKind[] = ['lines', 'dots', 'cross', 'diag', 'bars']
  const kind = kinds[Math.floor(rnd() * kinds.length)]
  const density = opts.density ?? 90 + Math.floor(rnd() * 60)
  // 70 → 12px, 160 → 4px
  const spacing = Math.max(3, Math.round(14 - ((density - 60) / 100) * 10))
  const fg = opts.fg ?? 'rgba(255,255,255,0.5)'
  const angle = ((opts.angle12 ?? Math.floor(rnd() * 12)) % 12) * 15
  const s = spacing
  let svg: string
  switch (kind) {
    case 'dots':
      svg = `<svg xmlns='http://www.w3.org/2000/svg' width='${s}' height='${s}'><rect x='0' y='0' width='1.2' height='1.2' fill='${fg}'/></svg>`
      break
    case 'cross':
      svg = `<svg xmlns='http://www.w3.org/2000/svg' width='${s}' height='${s}'><path d='M0 ${s / 2}H${s}M${s / 2} 0V${s}' stroke='${fg}' stroke-width='0.8'/></svg>`
      break
    case 'diag':
      svg = `<svg xmlns='http://www.w3.org/2000/svg' width='${s}' height='${s}'><g transform='rotate(${angle} ${s / 2} ${s / 2})'><path d='M-${s} ${s / 2}H${s * 2}' stroke='${fg}' stroke-width='0.8'/></g></svg>`
      break
    case 'bars':
      svg = `<svg xmlns='http://www.w3.org/2000/svg' width='${s * 2}' height='${s}'><rect x='0' y='0' width='${Math.max(1, s * 0.6)}' height='${s}' fill='${fg}'/></svg>`
      break
    default:
      svg = `<svg xmlns='http://www.w3.org/2000/svg' width='${s}' height='${s}'><path d='M0 0.5H${s}' stroke='${fg}' stroke-width='0.8'/></svg>`
  }
  return {
    kind,
    backgroundImage: `url("data:image/svg+xml;utf8,${encodeURIComponent(svg)}")`,
    backgroundSize: kind === 'bars' ? `${s * 2}px ${s}px` : `${s}px ${s}px`,
    spacing
  }
}
