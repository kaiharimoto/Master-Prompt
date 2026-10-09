/** Number, unit and time formatting in the family voice (see guides/VOICE.md §10). */

/** `m:ss`; `--:--` when unknown. */
export function formatDuration(seconds: number | null | undefined): string {
  if (seconds == null || !isFinite(seconds)) return '--:--'
  const s = Math.max(0, Math.round(seconds))
  const m = Math.floor(s / 60)
  const r = s % 60
  return `${m}:${r.toString().padStart(2, '0')}`
}

/** `m:ss.s` for clip times. */
export function formatClock(seconds: number): string {
  const s = Math.max(0, seconds)
  const m = Math.floor(s / 60)
  const r = s - m * 60
  return `${m}:${r.toFixed(1).padStart(4, '0')}`
}

/** `45s`, `3m 05s`, `1h 12m`; empty when unknown. */
export function formatEta(seconds: number | null | undefined): string {
  if (seconds == null || !isFinite(seconds)) return ''
  if (seconds < 60) return `${Math.max(1, Math.round(seconds))}s`
  const m = Math.floor(seconds / 60)
  const s = Math.round(seconds % 60)
  return m >= 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m}m ${s.toString().padStart(2, '0')}s`
}

/** `just now`, `5m ago`, `3h ago`, `2d ago`, then a locale date. `ts` in seconds. */
export function timeAgo(ts: number): string {
  const diff = Date.now() / 1000 - ts
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  if (diff < 86400 * 7) return `${Math.floor(diff / 86400)}d ago`
  return new Date(ts * 1000).toLocaleDateString()
}

/** `≈ 3 GB`, `≈ 2:40`. */
export function approx(text: string): string {
  return `≈ ${text}`
}

/** Join meta items with the family separator. */
export function meta(...parts: (string | number | null | undefined | false)[]): string {
  return parts.filter((p) => p !== null && p !== undefined && p !== false && p !== '').join(' · ')
}

/** `01`, `02`. */
export function numeral(n: number): string {
  return String(n).padStart(2, '0')
}

/** `16 GB`, `120 BPM`, `800 steps`. */
export function unit(value: number | string, u: string): string {
  return `${value} ${u}`
}

/** `10–20 min`. */
export function range(a: number | string, b: number | string, u?: string): string {
  return `${a}–${b}${u ? ` ${u}` : ''}`
}

export function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n))
}

export function randomSeed(): number {
  return Math.floor(Math.random() * 2 ** 31)
}
