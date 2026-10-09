/**
 * Theme: `data-theme` on <html>, persisted in localStorage. Light is default;
 * dark is the exact inversion. No system-preference listener; the user chooses.
 *
 * Framework-free. Wrap in your store of choice (a zustand store in Music Master).
 */
export type Theme = 'light' | 'dark'

export interface ThemeOptions {
  /** localStorage key; use your app's two-letter prefix, e.g. 'mm.theme'. */
  key?: string
  /** Called after the DOM is updated — e.g. to sync an Electron window's chrome. */
  onChange?: (theme: Theme) => void
}

export function applyTheme(t: Theme, opts: ThemeOptions = {}): void {
  document.documentElement.dataset.theme = t
  document.documentElement.classList.toggle('dark', t === 'dark')
  try {
    localStorage.setItem(opts.key ?? 'app.theme', t)
  } catch {
    /* ignore */
  }
  opts.onChange?.(t)
}

export function readTheme(key = 'app.theme'): Theme {
  try {
    const saved = localStorage.getItem(key)
    if (saved === 'dark' || saved === 'light') return saved
  } catch {
    /* ignore */
  }
  return 'light'
}

export function initTheme(opts: ThemeOptions = {}): Theme {
  const t = readTheme(opts.key)
  applyTheme(t, opts)
  return t
}

export function toggleTheme(opts: ThemeOptions = {}): Theme {
  const next: Theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'
  applyTheme(next, opts)
  return next
}

/**
 * Electron main process, on theme change (paste into your ipc handler):
 *
 *   const dark = theme === 'dark'
 *   nativeTheme.themeSource = theme
 *   win.setBackgroundColor(dark ? '#000000' : '#ffffff')
 *   try { win.setTitleBarOverlay({ color: dark ? '#000000' : '#ffffff', symbolColor: dark ? '#ffffff' : '#000000', height: 40 }) } catch {}
 */
