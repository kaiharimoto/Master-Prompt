/** Optional UI sounds, synthesised with Web Audio (no assets). Off by default. */

let ctx: AudioContext | null = null
let KEY = 'app.sound'

/** Set the localStorage key once (e.g. 'mm.sound'). */
export function configureSound(key: string): void {
  KEY = key
}

export function soundEnabled(): boolean {
  try {
    return localStorage.getItem(KEY) === 'on'
  } catch {
    return false
  }
}

export function setSoundEnabled(on: boolean): void {
  try {
    localStorage.setItem(KEY, on ? 'on' : 'off')
  } catch {
    /* ignore */
  }
}

function tone(freq: number, at: number, dur: number, gain = 0.06): void {
  if (!ctx) ctx = new AudioContext()
  const o = ctx.createOscillator()
  const g = ctx.createGain()
  o.type = 'square'
  o.frequency.value = freq
  g.gain.setValueAtTime(0, ctx.currentTime + at)
  g.gain.linearRampToValueAtTime(gain, ctx.currentTime + at + 0.005)
  g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + at + dur)
  o.connect(g).connect(ctx.destination)
  o.start(ctx.currentTime + at)
  o.stop(ctx.currentTime + at + dur + 0.02)
}

/** 60 ms click for the primary action. */
export function click(): void {
  if (!soundEnabled()) return
  tone(1200, 0, 0.06, 0.04)
}

/** Two-note "done" (a rising fifth). */
export function done(): void {
  if (!soundEnabled()) return
  tone(660, 0, 0.12)
  tone(990, 0.13, 0.18)
}
