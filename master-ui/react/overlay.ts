/**
 * Canvas helpers for overlays drawn on pictures (MASTER-UI §17.3).
 *
 * Every overlay is a double stroke: a 1px ink line with a 1px paper line beside it, so it reads
 * on any pixel colour. Colours come from the theme (`--ink` / `--paper`), never from a palette.
 */

export interface Theme {
  ink: string
  paper: string
}

export function themeColours(el: Element = document.documentElement): Theme {
  const cs = getComputedStyle(el)
  return { ink: cs.getPropertyValue('--ink').trim() || '#000', paper: cs.getPropertyValue('--paper').trim() || '#fff' }
}

/** Stroke the current path twice: 1px paper offset outward, 1px ink on top. `dash` makes it dashed; `phase` moves the ants. */
export function doubleStroke(ctx: CanvasRenderingContext2D, t: Theme, opts: { dash?: number; phase?: number } = {}): void {
  ctx.save()
  const d = opts.dash ?? 0
  ctx.lineWidth = 3
  ctx.strokeStyle = t.paper
  ctx.setLineDash(d ? [d, d] : [])
  ctx.lineDashOffset = -(opts.phase ?? 0) + d
  ctx.stroke()
  ctx.lineWidth = 1
  ctx.strokeStyle = t.ink
  ctx.lineDashOffset = -(opts.phase ?? 0)
  ctx.stroke()
  ctx.restore()
}

/** A 45° ink/paper stripe pattern (2px each) for mask fills. Create once per theme. */
export function stripePattern(ctx: CanvasRenderingContext2D, t: Theme): CanvasPattern | null {
  const tile = document.createElement('canvas')
  tile.width = tile.height = 8
  const g = tile.getContext('2d')!
  g.fillStyle = t.paper
  g.fillRect(0, 0, 8, 8)
  g.strokeStyle = t.ink
  g.lineWidth = 2.8
  g.beginPath()
  for (let o = -8; o <= 16; o += 4 * 2) {
    g.moveTo(o, 8)
    g.lineTo(o + 8, 0)
  }
  g.stroke()
  return ctx.createPattern(tile, 'repeat')
}

/** Fill a mask (an alpha canvas the size of the image) with the stripe pattern at 45% opacity. */
export function paintMask(ctx: CanvasRenderingContext2D, mask: CanvasImageSource, w: number, h: number, t: Theme, solid = false): void {
  const layer = document.createElement('canvas')
  layer.width = w
  layer.height = h
  const l = layer.getContext('2d')!
  l.drawImage(mask, 0, 0, w, h)
  l.globalCompositeOperation = 'source-in'
  l.fillStyle = solid ? t.paper : (stripePattern(l, t) ?? t.ink)
  l.fillRect(0, 0, w, h)
  ctx.save()
  ctx.globalAlpha = solid ? 0.7 : 0.45
  ctx.drawImage(layer, 0, 0)
  ctx.restore()
}

/** Marching-ants phase for `doubleStroke`: 8px per 0.6s (the live-hatch tempo); 0 under reduced motion. */
export function antsPhase(now: number = performance.now()): number {
  if (typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches) return 0
  return ((now / 600) * 8) % 8
}

/** An 8px square handle: paper fill, ink border (§17.3). */
export function handle(ctx: CanvasRenderingContext2D, x: number, y: number, t: Theme, size = 8): void {
  ctx.save()
  ctx.fillStyle = t.paper
  ctx.strokeStyle = t.ink
  ctx.lineWidth = 1
  ctx.fillRect(Math.round(x - size / 2), Math.round(y - size / 2), size, size)
  ctx.strokeRect(Math.round(x - size / 2) + 0.5, Math.round(y - size / 2) + 0.5, size - 1, size - 1)
  ctx.restore()
}

/** A click point: include = paper square with ink "+", exclude = ink square with paper "−". */
export function clickPoint(ctx: CanvasRenderingContext2D, x: number, y: number, include: boolean, t: Theme): void {
  const s = 10
  ctx.save()
  ctx.fillStyle = include ? t.paper : t.ink
  ctx.strokeStyle = include ? t.ink : t.paper
  ctx.fillRect(Math.round(x - s / 2), Math.round(y - s / 2), s, s)
  ctx.strokeStyle = t.ink
  ctx.strokeRect(Math.round(x - s / 2) + 0.5, Math.round(y - s / 2) + 0.5, s - 1, s - 1)
  ctx.strokeStyle = include ? t.ink : t.paper
  ctx.beginPath()
  ctx.moveTo(x - 3, y)
  ctx.lineTo(x + 3, y)
  if (include) {
    ctx.moveTo(x, y - 3)
    ctx.lineTo(x, y + 3)
  }
  ctx.stroke()
  ctx.restore()
}

/** The brush footprint: a double-stroke circle, the one round shape in the family (§17.3). */
export function brushCursor(ctx: CanvasRenderingContext2D, x: number, y: number, radius: number, t: Theme): void {
  ctx.beginPath()
  ctx.arc(x, y, Math.max(1, radius), 0, Math.PI * 2)
  doubleStroke(ctx, t)
}
