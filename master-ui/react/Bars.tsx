import { useEffect, useRef, useState } from 'react'
import { cn } from './ui'

export interface Mark {
  /** Position 0..1 along the width. */
  at: number
  label?: string
}

/**
 * Ink bar chart / waveform: 1px bars, done part solid, rest at 25%, hover
 * preview at 50%; optional 1px marks with micro labels; a 1px playhead with a
 * 6px square. Reads --ink from the document so it follows the theme.
 */
export function Bars({
  values,
  progress = 0,
  onSeek,
  className,
  height = 40,
  bar = 1,
  gap = 2,
  interactive = true,
  marks,
  showPlayhead = true
}: {
  /** 0..1 amplitudes; null while loading (renders a skeleton), [] for flat. */
  values: number[] | null
  progress?: number
  onSeek?: (ratio: number) => void
  className?: string
  height?: number
  bar?: number
  gap?: number
  interactive?: boolean
  marks?: Mark[] | null
  showPlayhead?: boolean
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const wrapRef = useRef<HTMLDivElement>(null)
  const dragging = useRef(false)
  const [hover, setHover] = useState<number | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    const wrap = wrapRef.current
    if (!canvas || !wrap) return
    const draw = (): void => {
      const dpr = window.devicePixelRatio || 1
      const w = wrap.clientWidth
      const h = height
      canvas.width = w * dpr
      canvas.height = h * dpr
      canvas.style.width = `${w}px`
      canvas.style.height = `${h}px`
      const ctx = canvas.getContext('2d')
      if (!ctx) return
      ctx.scale(dpr, dpr)
      ctx.clearRect(0, 0, w, h)
      const ink = getComputedStyle(document.documentElement).getPropertyValue('--ink').trim() || '#000'
      const n = Math.max(1, Math.floor(w / (bar + gap)))
      const src = values && values.length ? values : null
      const mid = h / 2
      for (let i = 0; i < n; i++) {
        const x = i * (bar + gap)
        let amp: number
        if (src) {
          const a = Math.floor((i / n) * src.length)
          const b = Math.max(a + 1, Math.floor(((i + 1) / n) * src.length))
          let m = 0
          for (let k = a; k < b && k < src.length; k++) m = Math.max(m, src[k])
          amp = m
        } else amp = 0.08
        const bh = Math.max(1, amp * (h - 6))
        const ratio = i / n
        const isDone = ratio <= progress
        const isHover = hover != null && ratio <= hover && !isDone
        ctx.fillStyle = ink
        ctx.globalAlpha = isDone ? 1 : isHover ? 0.5 : 0.25
        ctx.fillRect(x, mid - bh / 2, bar, bh)
      }
      ctx.globalAlpha = 1
      if (marks) {
        ctx.fillStyle = ink
        for (const m of marks) {
          const x = Math.round(m.at * w)
          if (x <= 0) continue
          ctx.fillRect(x, 0, 1, h)
        }
      }
      if (showPlayhead && progress > 0 && progress < 1) {
        const x = Math.round(progress * w)
        ctx.fillStyle = ink
        ctx.fillRect(x, 0, 1, h)
      }
    }
    draw()
    const ro = new ResizeObserver(draw)
    ro.observe(wrap)
    const mo = new MutationObserver(draw)
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })
    return () => {
      ro.disconnect()
      mo.disconnect()
    }
  }, [values, progress, height, bar, gap, hover, marks, showPlayhead])

  const ratioFromEvent = (e: React.MouseEvent): number => {
    const rect = wrapRef.current!.getBoundingClientRect()
    return Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
  }

  return (
    <div
      ref={wrapRef}
      className={cn('relative w-full', interactive && 'cursor-crosshair', className)}
      style={{ height }}
      onMouseDown={(e) => {
        if (!interactive || !onSeek) return
        dragging.current = true
        onSeek(ratioFromEvent(e))
      }}
      onMouseMove={(e) => {
        if (!interactive) return
        setHover(ratioFromEvent(e))
        if (dragging.current && onSeek) onSeek(ratioFromEvent(e))
      }}
      onMouseUp={() => (dragging.current = false)}
      onMouseLeave={() => {
        dragging.current = false
        setHover(null)
      }}
    >
      <canvas ref={canvasRef} className={cn('block', !values && 'skeleton')} />
      {showPlayhead && progress > 0 && progress < 1 ? <span className="pointer-events-none absolute top-0 size-[6px] -translate-x-1/2 bg-ink" style={{ left: `${progress * 100}%` }} /> : null}
      {marks
        ? marks.map((m) =>
            m.label ? (
              <span key={m.at + m.label} className="t-micro pointer-events-none absolute -top-4 text-[9px] text-ink-45" style={{ left: `${m.at * 100}%`, paddingLeft: 3 }}>
                {m.label}
              </span>
            ) : null
          )
        : null}
    </div>
  )
}
