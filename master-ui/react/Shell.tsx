import * as React from 'react'
import { Search } from 'lucide-react'
import { cn, Kbd } from './ui'
import { Wordmark } from './Mark'

/**
 * App shell: title bar / [rail | main | aside] / footer. See guides/LAYOUT.md.
 * Everything is a slot; the shell owns only the bands, rules and dimensions.
 */
export function Shell({
  top,
  rail,
  aside,
  footer,
  banner,
  children,
  pageKey
}: {
  top: React.ReactNode
  rail?: React.ReactNode
  aside?: React.ReactNode
  footer?: React.ReactNode
  banner?: React.ReactNode
  children: React.ReactNode
  /** Changes when the page changes so the content fades in (100ms). */
  pageKey?: string
}) {
  return (
    <div className="flex h-full flex-col bg-paper text-ink">
      {top}
      {banner}
      <div className="relative flex min-h-0 flex-1">
        {rail}
        <main className="relative min-w-0 flex-1 overflow-hidden">
          <div key={pageKey} className="h-full fade-in">
            {children}
          </div>
        </main>
        {aside}
      </div>
      {footer}
    </div>
  )
}

/** 40px title bar. `electronWindows` reserves room for the native overlay buttons. */
export function TitleBar({
  name,
  shape,
  shapes,
  onHome,
  left,
  right,
  status,
  onSearch,
  electronWindows
}: {
  name: string
  /** The app's mark: a key in MARKS, or a MarkDef. See guides/MARK.md. */
  shape?: React.ComponentProps<typeof Wordmark>['shape']
  shapes?: React.ComponentProps<typeof Wordmark>['shapes']
  onHome?: () => void
  /** After the wordmark: e.g. a running-job pill. */
  left?: React.ReactNode
  /** Before the search: e.g. update pills. */
  right?: React.ReactNode
  /** Micro-caps status text, e.g. "Engine ready · 4.2 / 24 GB"; `live` breathes the square; `error` inverts. */
  status?: { text: string; live?: boolean; error?: boolean; onClick?: () => void }
  onSearch?: () => void
  electronWindows?: boolean
}) {
  return (
    <header className="drag-region relative z-40 flex h-[var(--shell-top-h)] shrink-0 items-center justify-between border-b border-ink bg-paper pl-4" style={{ paddingRight: electronWindows ? 150 : 16 }}>
      <div className="flex items-center gap-6">
        <button className="no-drag" onClick={onHome} type="button">
          <Wordmark name={name} shape={shape} shapes={shapes} />
        </button>
        {left}
      </div>
      <div className="no-drag flex items-center gap-4">
        {right}
        {onSearch ? (
          <button type="button" onClick={onSearch} className="flex h-7 items-center gap-2 border border-ink-25 px-2 text-ink-45 transition-colors hover:border-ink hover:text-ink">
            <Search className="size-3.5" />
            <span className="t-micro">Search</span>
            <Kbd>Ctrl K</Kbd>
          </button>
        ) : null}
        {status ? (
          <button type="button" onClick={status.onClick} className={cn('t-micro flex items-center gap-2 hover:underline', status.error && 'bg-ink px-2 py-1 text-paper')}>
            {!status.error ? <span className={cn('size-1.5 bg-ink', status.live && 'breathe')} /> : null}
            <span className="max-w-[360px] truncate">{status.text}</span>
          </button>
        ) : null}
      </div>
    </header>
  )
}

/** Running-job pill for the title bar. */
export function RunningPill({ title, percent, onClick }: { title: string; percent: number; onClick?: () => void }) {
  return (
    <button type="button" onClick={onClick} className="no-drag t-micro flex h-6 items-center gap-2 border border-ink px-2 hover-invert">
      <span className="breathe size-1.5 bg-current" />
      <span className="max-w-[240px] truncate normal-case tracking-normal">{title}</span>
      <span className="t-mono">{Math.round(percent)}%</span>
    </button>
  )
}

export interface RailItem {
  id: string
  label: string
  /** Optional mono count (e.g. active jobs). */
  count?: number
}

/** Typographic index rail: numbered entries, the active one inverted. */
export function Rail({
  items,
  active,
  onSelect,
  now,
  foot
}: {
  items: RailItem[]
  active: string
  onSelect: (id: string) => void
  /** The "now" strip (current object) above the footer links. */
  now?: React.ReactNode
  /** Footer links: Settings · Setup · Dark. */
  foot?: React.ReactNode
}) {
  return (
    <aside className="flex w-[var(--sidebar-w)] shrink-0 flex-col border-r border-ink bg-paper">
      <nav className="flex flex-col border-b border-ink">
        {items.map((n, i) => {
          const on = active === n.id
          return (
            <button
              key={n.id}
              type="button"
              onClick={() => onSelect(n.id)}
              className={cn('group flex h-14 items-center gap-4 border-b border-ink-12 px-5 text-left transition-colors duration-[120ms] last:border-b-0', on ? 'bg-ink text-paper' : 'hover:bg-ink-06')}
            >
              <span className={cn('t-mono text-[11px]', on ? 'text-paper/60' : 'text-ink-45')}>{String(i + 1).padStart(2, '0')}</span>
              <span className="t-h2 flex-1">{n.label}</span>
              {n.count ? <span className={cn('t-mono text-[11px]', on ? 'text-paper' : 'text-ink')}>{n.count}</span> : null}
              <span className={cn('text-[16px] transition-transform duration-[120ms]', on ? 'translate-x-0' : '-translate-x-1 opacity-0 group-hover:translate-x-0 group-hover:opacity-100')}>→</span>
            </button>
          )
        })}
      </nav>
      <div className="mt-auto flex flex-col">
        {now}
        {foot ? <div className="flex items-center justify-between border-t border-ink px-5 py-3">{foot}</div> : null}
      </div>
    </aside>
  )
}

/** Micro-caps link for the rail footer. */
export function RailLink({ on, children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & { on?: boolean }) {
  return (
    <button type="button" className={cn('t-micro link', on ? 'text-ink' : 'text-ink-70')} {...props}>
      {children}
    </button>
  )
}

/** 88px footer with the strong rule. Left 280 · centre flexible · right 220. */
export function Footer({ left, children, right }: { left?: React.ReactNode; children?: React.ReactNode; right?: React.ReactNode }) {
  return (
    <footer className="relative z-30 flex h-[var(--shell-bottom-h)] shrink-0 items-center gap-6 border-t-2 border-ink bg-paper px-4">
      <div className="flex w-[280px] min-w-0 items-center gap-3">{left}</div>
      <div className="flex min-w-0 flex-1 flex-col items-center gap-1">{children}</div>
      <div className="flex w-[220px] items-center justify-end gap-2">{right}</div>
    </footer>
  )
}

/** Inverted system banner under the title bar (only while there is a problem). */
export function Banner({ kicker, children, actions }: { kicker: string; children: React.ReactNode; actions?: React.ReactNode }) {
  return (
    <div className="flex items-center gap-4 bg-ink px-4 py-2 text-[13px] text-paper">
      <span className="t-micro">{kicker}</span>
      <span className="flex-1 truncate">{children}</span>
      {actions}
    </div>
  )
}

/** Right-anchored drawer inside <main>. Pair with motion/react for the 180ms slide (see guides/MOTION.md). */
export function Drawer({ open, onClose, children, className }: { open: boolean; onClose: () => void; children: React.ReactNode; className?: string }) {
  React.useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent): void => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])
  if (!open) return null
  return (
    <>
      <div className="absolute inset-0 z-40 bg-overlay" onClick={onClose} />
      <aside className={cn('absolute bottom-0 right-0 top-0 z-50 w-[min(800px,85vw)] border-l border-ink bg-paper', className)}>{children}</aside>
    </>
  )
}
