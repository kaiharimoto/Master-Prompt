/**
 * Types `text` into a setter over `ms` milliseconds (used when a machine fills a
 * field on the user's behalf). Quadratic ease-out, rAF-driven, instant under
 * prefers-reduced-motion. Callers usually pass ms = min(2400, 400 + text.length * 6).
 */
export function typeInto(setter: (value: string) => void, text: string, opts: { ms?: number } = {}): Promise<void> {
  const ms = opts.ms ?? Math.min(2400, 400 + text.length * 6)
  if (!text || ms <= 0 || typeof window === 'undefined' || matchMedia?.('(prefers-reduced-motion: reduce)').matches) {
    setter(text)
    return Promise.resolve()
  }
  const start = performance.now()
  return new Promise((resolve) => {
    const tick = (): void => {
      const t = Math.min(1, (performance.now() - start) / ms)
      const n = Math.ceil(text.length * easeOut(t))
      setter(text.slice(0, n))
      if (t >= 1) resolve()
      else requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)
  })
}

function easeOut(t: number): number {
  return 1 - (1 - t) * (1 - t)
}
