import { useEffect, useMemo, useRef, useState } from 'react'
import { Dialog as RDialog } from 'radix-ui'
import { cn, Kbd } from './ui'

export interface Command {
  id: string
  label: string
  /** Mono hint on the right (a shortcut, a duration, a subtitle). */
  hint?: string
  /** Group label in the left column: Go, Song, App, … */
  group: string
  run: () => void
}

/**
 * Ctrl K: navigate, act on the current object, search. Generic: pass the
 * commands and an optional search function that returns more commands for a
 * query. Selected row is inverted; the prompt arrow blinks.
 */
export function CommandPalette({
  open,
  onOpenChange,
  commands,
  search,
  placeholder = 'Go to, act on the current item, or search'
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  commands: Command[]
  search?: (query: string) => Command[]
  placeholder?: string
}) {
  const [q, setQ] = useState('')
  const [index, setIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const onKey = (e: KeyboardEvent): void => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        onOpenChange(!open)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onOpenChange])

  useEffect(() => {
    if (open) {
      setQ('')
      setIndex(0)
      setTimeout(() => inputRef.current?.focus(), 30)
    }
  }, [open])

  const needle = q.trim().toLowerCase()
  const results = useMemo(() => {
    const cmds = commands.filter((c) => !needle || c.label.toLowerCase().includes(needle))
    const extra = needle && search ? search(needle) : []
    return [...cmds, ...extra]
  }, [commands, needle, search])

  useEffect(() => setIndex(0), [needle])

  const run = (c: Command): void => {
    onOpenChange(false)
    c.run()
  }

  return (
    <RDialog.Root open={open} onOpenChange={onOpenChange}>
      <RDialog.Portal>
        <RDialog.Overlay className="fixed inset-0 z-[70] bg-overlay" />
        <RDialog.Content className="fixed left-1/2 top-[15vh] z-[70] w-[min(640px,90vw)] -translate-x-1/2 border border-ink bg-paper focus:outline-none">
          <RDialog.Title className="sr-only">Command palette</RDialog.Title>
          <div className="flex items-center gap-3 border-b border-ink px-4">
            <span className="t-mono blink text-ink-45">→</span>
            <input
              ref={inputRef}
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'ArrowDown') {
                  e.preventDefault()
                  setIndex((i) => Math.min(results.length - 1, i + 1))
                }
                if (e.key === 'ArrowUp') {
                  e.preventDefault()
                  setIndex((i) => Math.max(0, i - 1))
                }
                if (e.key === 'Enter' && results[index]) run(results[index])
              }}
              placeholder={placeholder}
              className="h-12 flex-1 bg-transparent text-[15px] outline-none placeholder:text-ink-45"
            />
            <Kbd>Esc</Kbd>
          </div>
          <div className="max-h-[50vh] overflow-y-auto">
            {results.length ? (
              results.map((c, i) => (
                <button
                  key={c.id}
                  type="button"
                  onMouseEnter={() => setIndex(i)}
                  onClick={() => run(c)}
                  className={cn('flex w-full items-center gap-4 border-b border-ink-12 px-4 py-2.5 text-left text-[13px] last:border-b-0', i === index ? 'bg-ink text-paper' : '')}
                >
                  <span className={cn('t-micro w-12 shrink-0', i === index ? 'text-paper/60' : 'text-ink-45')}>{c.group}</span>
                  <span className="min-w-0 flex-1 truncate">{c.label}</span>
                  {c.hint ? <span className={cn('t-mono truncate text-[11px]', i === index ? 'text-paper/60' : 'text-ink-45')}>{c.hint}</span> : null}
                </button>
              ))
            ) : (
              <div className="px-4 py-6 text-[13px] text-ink-45">No matches.</div>
            )}
          </div>
        </RDialog.Content>
      </RDialog.Portal>
    </RDialog.Root>
  )
}
