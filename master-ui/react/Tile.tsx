import { useMemo } from 'react'
import { artFor, seedFrom } from './art'
import { cn } from './ui'

/**
 * Typographic tile: an ink square with a seed-derived raster and the title set
 * in paper. `outline` makes a paper tile with ink text (derived objects).
 * `live` overlays a breathing square. `size` picks how much of the title to
 * show. `dark` must be the current theme so the raster uses real colours.
 */
export function Tile({
  seed,
  title,
  outline,
  className,
  live,
  pending,
  size = 'md',
  dark = false,
  density,
  angle12
}: {
  seed?: number
  title?: string
  outline?: boolean
  className?: string
  live?: boolean
  pending?: boolean
  size?: 'sm' | 'md' | 'lg'
  dark?: boolean
  density?: number | null
  angle12?: number | null
}) {
  const t = (title ?? '').trim()
  const s = seed ?? seedFrom(t)
  const art = useMemo(() => {
    const onInk = !outline
    const inkIsBlack = !dark
    const fg = onInk ? (inkIsBlack ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.5)') : inkIsBlack ? 'rgba(0,0,0,0.45)' : 'rgba(255,255,255,0.45)'
    return artFor(s, { density, angle12, fg })
  }, [s, outline, dark, density, angle12])
  const label = size === 'sm' ? (t ? t.slice(0, 1).toUpperCase() : '') : size === 'md' ? t.split(/\s+/).slice(0, 2).join(' ') : t
  const fontSize = size === 'sm' ? 'text-[46cqw]' : size === 'md' ? (label.length > 10 ? 'text-[15cqw]' : 'text-[19cqw]') : t.length > 24 ? 'text-[13cqw]' : t.length > 12 ? 'text-[16cqw]' : 'text-[22cqw]'

  return (
    <div
      className={cn('relative shrink-0 select-none overflow-hidden', outline ? 'border border-ink bg-paper text-ink' : 'bg-ink text-paper', pending && 'hatch-live bg-paper text-ink', className)}
      style={{ containerType: 'inline-size', ...(pending ? {} : { backgroundImage: art.backgroundImage, backgroundSize: art.backgroundSize }) }}
      aria-label={t}
    >
      {label && !pending ? (
        <div className={cn('absolute inset-0 flex items-end p-[8%] font-bold uppercase leading-[0.9] tracking-[-0.03em]', fontSize)}>
          <span className="line-clamp-3 break-words">{label}</span>
        </div>
      ) : null}
      {live ? (
        <div className="absolute left-[8%] top-[8%] flex items-center gap-1">
          <span className={cn('breathe block size-[10%] min-h-1.5 min-w-1.5', outline ? 'bg-ink' : 'bg-paper')} />
        </div>
      ) : null}
    </div>
  )
}
