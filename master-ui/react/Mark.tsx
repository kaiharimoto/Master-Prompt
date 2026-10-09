import { cn } from './ui'

/**
 * The family mark: an ink square carrying a paper diagram of what the app acts
 * on. Every app in the family gets its OWN picture — never a letterform, never
 * a variation on another app's mark. What makes them a family is the square,
 * the two fills and the construction grammar (see guides/MARK.md), not the
 * shape.
 *
 * Grid: 100×100 viewBox, ink square full bleed, geometry inside a 68×68 field
 * (16 padding), coordinates snapped to 4, one element weight per mark, straight
 * lines and 45° diagonals only, 2–5 elements, legible at 16px.
 */

export type Shape =
  /** [x, y, w, h] */
  | { rect: [number, number, number, number]; ink?: boolean }
  /** flat [x1, y1, x2, y2, …] */
  | { poly: number[]; ink?: boolean }
  /** [cx, cy, r] */
  | { circle: [number, number, number]; ink?: boolean }

export interface MarkDef {
  /** The noun the app acts on — what the diagram depicts. */
  subject: string
  /** Drawn in order; `ink: true` cuts a hole in what is already there. */
  shapes: Shape[]
}

/**
 * Worked examples. Add one per app; do not reuse another app's entry.
 * Each is a reduced diagram of the thing the app's user works with.
 */
export const MARKS: Record<string, MarkDef> = {
  /** Music Master — levels. Five bars, unequal heights: sound as a meter. */
  levels: { subject: 'sound levels', shapes: bars([0.9, 0.45, 0.7, 0.45, 0.9]) },

  /** Visual Master — a picture. A paper frame with a horizon inside it. */
  frame: {
    subject: 'a picture',
    shapes: [
      { rect: [16, 22, 68, 56] },
      { rect: [24, 30, 52, 40], ink: true },
      { poly: [24, 70, 46, 48, 68, 70] }
    ]
  },

  /** Sort Master — an ordered list. Three bars, left-aligned, descending. */
  list: {
    subject: 'an ordered list',
    shapes: [
      { rect: [16, 16, 68, 16] },
      { rect: [16, 42, 46, 16] },
      { rect: [16, 68, 24, 16] }
    ]
  },

  /** A worked example for a text/document app — a page with a fold. */
  page: {
    subject: 'a document',
    shapes: [
      { poly: [22, 16, 62, 16, 78, 32, 78, 84, 22, 84] },
      { rect: [32, 40, 36, 8], ink: true },
      { rect: [32, 56, 36, 8], ink: true }
    ]
  },

  /** A worked example for a time/scheduling app — a dial at 45°. */
  dial: {
    subject: 'elapsed time',
    shapes: [
      { circle: [50, 50, 34] },
      { circle: [50, 50, 24], ink: true },
      { rect: [46, 26, 8, 28] },
      { rect: [46, 46, 26, 8] }
    ]
  }
}

/**
 * Vertical bars from the baseline (or hanging from the top). The constructor
 * behind Music Master's mark; use it when levels, a spectrum or a histogram IS
 * the subject — not to spell a letter.
 */
export function bars(heights: number[], anchor: 'top' | 'bottom' = 'bottom'): Shape[] {
  const pad = 16
  const inner = 100 - pad * 2
  const n = heights.length
  const gap = inner * 0.09
  const bw = (inner - gap * (n - 1)) / n
  return heights.map((h, i) => ({
    rect: [pad + i * (bw + gap), anchor === 'top' ? pad : pad + inner * (1 - h), bw, inner * h] as [number, number, number, number]
  }))
}

function renderShape(s: Shape, i: number, inkClass: string, paperClass: string) {
  const fill = s.ink ? inkClass : paperClass
  if ('rect' in s) {
    const [x, y, w, h] = s.rect
    return <rect key={i} x={x} y={y} width={w} height={h} className={fill} />
  }
  if ('circle' in s) {
    const [cx, cy, r] = s.circle
    return <circle key={i} cx={cx} cy={cy} r={r} className={fill} />
  }
  return <polygon key={i} points={s.poly.join(' ')} className={fill} />
}

/**
 * Renders a mark. Pass `shape` (a key in MARKS or a MarkDef) — or `shapes` for
 * a one-off. `title` gives it an accessible name; omit for decoration.
 */
export function Mark({ shape = 'levels', shapes, className, title }: { shape?: keyof typeof MARKS | MarkDef; shapes?: Shape[]; className?: string; title?: string }) {
  const def = typeof shape === 'string' ? MARKS[shape] : shape
  const list = shapes ?? def?.shapes ?? MARKS.levels.shapes
  return (
    <svg viewBox="0 0 100 100" className={cn('shrink-0', className)} role={title ? 'img' : undefined} aria-label={title} aria-hidden={title ? undefined : true}>
      <rect width="100" height="100" className="fill-ink" />
      {list.map((s, i) => renderShape(s, i, 'fill-ink', 'fill-paper'))}
    </svg>
  )
}

/** Mark + name in bold uppercase. `stacked` puts each word on its own line. */
export function Wordmark({ name, shape, shapes, className, stacked }: { name: string; shape?: keyof typeof MARKS | MarkDef; shapes?: Shape[]; className?: string; stacked?: boolean }) {
  const words = name.split(' ')
  return (
    <div className={cn('flex select-none items-center gap-2 whitespace-nowrap', className)} aria-label={name}>
      <Mark className="size-5" shape={shape} shapes={shapes} />
      {stacked ? (
        <div className="flex flex-col font-bold uppercase leading-[0.85] tracking-[-0.04em]">
          {words.map((w) => (
            <span key={w}>{w}</span>
          ))}
        </div>
      ) : (
        <span className="text-[13px] font-bold uppercase tracking-[-0.02em]">{name}</span>
      )}
    </div>
  )
}

/**
 * Standalone SVG string for the app icon files (icon.png, icon.ico, favicon).
 * Icons on a desktop are always the light mark: paper marks on an ink square.
 * See guides/MARK.md for the export sizes.
 */
export function markToSvg(shape: keyof typeof MARKS | MarkDef, { size = 512, ink = '#000000', paper = '#ffffff' } = {}): string {
  const def = typeof shape === 'string' ? MARKS[shape] : shape
  const body = def.shapes
    .map((s) => {
      const fill = s.ink ? ink : paper
      if ('rect' in s) return `<rect x="${s.rect[0]}" y="${s.rect[1]}" width="${s.rect[2]}" height="${s.rect[3]}" fill="${fill}"/>`
      if ('circle' in s) return `<circle cx="${s.circle[0]}" cy="${s.circle[1]}" r="${s.circle[2]}" fill="${fill}"/>`
      return `<polygon points="${s.poly.join(' ')}" fill="${fill}"/>`
    })
    .join('')
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="${size}" height="${size}"><rect width="100" height="100" fill="${ink}"/>${body}</svg>`
}
