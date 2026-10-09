/**
 * Master UI — reference primitives (React 19, Tailwind 4, radix-ui, cva, lucide).
 *
 * Portable copy of the Music Master primitives. Every class string here is the
 * spec; see ../guides/COMPONENTS.md. Requires:
 *   react react-dom radix-ui class-variance-authority clsx tailwind-merge lucide-react
 * and the stylesheets ../css/master-ui.css + ../css/master-ui.tailwind.css.
 */
import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { Dialog as RDialog, DropdownMenu as RDropdown, Tooltip as RTooltip, Tabs as RTabs, Switch as RSwitch, Select as RSelect, ScrollArea as RScroll, Popover as RPopover } from 'radix-ui'
import { Loader2, X } from 'lucide-react'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs))
}

/* ------------------------------------------------------------------------ */
/* Button                                                                    */
/* ------------------------------------------------------------------------ */

export const buttonVariants = cva(
  'inline-flex select-none items-center justify-center gap-2 whitespace-nowrap font-medium transition-colors duration-[120ms] disabled:pointer-events-none disabled:opacity-30 [&_svg]:pointer-events-none [&_svg]:shrink-0 no-drag',
  {
    variants: {
      variant: {
        primary: 'border border-ink bg-ink text-paper hover:bg-paper hover:text-ink',
        secondary: 'border border-ink bg-paper text-ink hover:bg-ink hover:text-paper',
        subtle: 'border border-ink-25 bg-paper text-ink hover:border-ink hover:bg-ink hover:text-paper',
        ghost: 'border border-transparent text-ink-70 hover:text-ink hover:bg-ink-06',
        link: 'link h-auto p-0 text-ink'
      },
      size: {
        sm: 'h-8 px-3 text-[11px] font-medium uppercase tracking-[0.08em] [&_svg]:size-3.5',
        md: 'h-9 px-4 text-[12px] uppercase tracking-[0.08em] [&_svg]:size-4',
        lg: 'h-12 px-6 text-[13px] uppercase tracking-[0.08em] [&_svg]:size-4',
        icon: 'size-9 [&_svg]:size-4',
        'icon-sm': 'size-7 [&_svg]:size-3.5',
        'icon-lg': 'size-12 [&_svg]:size-5'
      }
    },
    defaultVariants: { variant: 'secondary', size: 'md' }
  }
)

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  loading?: boolean
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(({ className, variant, size, loading, children, disabled, ...props }, ref) => (
  <button ref={ref} className={cn(buttonVariants({ variant, size }), className)} disabled={disabled || loading} {...props}>
    {loading ? <Loader2 className="animate-spin" /> : null}
    {children}
  </button>
))
Button.displayName = 'Button'

/* ------------------------------------------------------------------------ */
/* Fields                                                                    */
/* ------------------------------------------------------------------------ */

/** Single line: underline only. */
export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(({ className, ...props }, ref) => (
  <input
    ref={ref}
    className={cn(
      'h-9 w-full border-0 border-b border-ink-25 bg-transparent px-0 text-[14px] text-ink placeholder:text-ink-45 transition-colors focus:border-ink focus:outline-none disabled:opacity-40',
      className
    )}
    {...props}
  />
))
Input.displayName = 'Input'

/** Multi line: boxed. */
export const Textarea = React.forwardRef<HTMLTextAreaElement, React.TextareaHTMLAttributes<HTMLTextAreaElement>>(({ className, ...props }, ref) => (
  <textarea
    ref={ref}
    className={cn(
      'w-full resize-none border border-ink-25 bg-transparent px-3 py-2 text-[14px] leading-relaxed text-ink placeholder:text-ink-45 transition-colors focus:border-ink focus:outline-none disabled:opacity-40',
      className
    )}
    {...props}
  />
))
Textarea.displayName = 'Textarea'

/** Micro-caps label with an optional right-aligned, normal-case hint (usually mono). */
export function Label({ className, hint, children, ...props }: React.LabelHTMLAttributes<HTMLLabelElement> & { hint?: React.ReactNode }) {
  return (
    <label className={cn('t-micro flex items-center justify-between text-ink-70', className)} {...props}>
      <span>{children}</span>
      {hint ? <span className="normal-case tracking-normal text-ink-45">{hint}</span> : null}
    </label>
  )
}

/** Helper text under a control. */
export function Help({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={cn('text-[11px] leading-snug text-ink-45', className)}>{children}</div>
}

/** Label / control / help, 8px apart. */
export function Stack({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={cn('flex flex-col gap-2', className)}>{children}</div>
}

/* ------------------------------------------------------------------------ */
/* Slider (native range; track/thumb styled in master-ui.css via --pct)     */
/* ------------------------------------------------------------------------ */

export function Slider({
  value,
  min,
  max,
  step = 1,
  onChange,
  className,
  disabled
}: {
  value: number
  min: number
  max: number
  step?: number
  onChange: (v: number) => void
  className?: string
  disabled?: boolean
}) {
  const pct = max > min ? ((value - min) / (max - min)) * 100 : 0
  return (
    <input
      type="range"
      min={min}
      max={max}
      step={step}
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(Number(e.target.value))}
      className={cn('w-full', className)}
      style={{ ['--pct' as string]: `${pct}%` }}
    />
  )
}

/* ------------------------------------------------------------------------ */
/* Switch                                                                    */
/* ------------------------------------------------------------------------ */

export function Switch({ checked, onCheckedChange, disabled, className }: { checked: boolean; onCheckedChange: (v: boolean) => void; disabled?: boolean; className?: string }) {
  return (
    <RSwitch.Root
      checked={checked}
      onCheckedChange={onCheckedChange}
      disabled={disabled}
      className={cn('relative h-[18px] w-9 shrink-0 border border-ink bg-paper transition-colors duration-[120ms] data-[state=checked]:bg-ink disabled:opacity-30 no-drag', className)}
    >
      <RSwitch.Thumb className="block size-3 translate-x-[2px] bg-ink transition-transform duration-[120ms] data-[state=checked]:translate-x-[20px] data-[state=checked]:bg-paper" />
    </RSwitch.Root>
  )
}

/* ------------------------------------------------------------------------ */
/* Select                                                                    */
/* ------------------------------------------------------------------------ */

export function Select<T extends string | number>({
  value,
  onChange,
  options,
  className,
  placeholder,
  size = 'md'
}: {
  value: T
  onChange: (v: T) => void
  options: { value: T; label: string; help?: string }[]
  className?: string
  placeholder?: string
  size?: 'sm' | 'md'
}) {
  const isNum = typeof (options[0]?.value ?? value) === 'number'
  return (
    <RSelect.Root value={String(value)} onValueChange={(v) => onChange((isNum ? Number(v) : v) as T)}>
      <RSelect.Trigger
        className={cn(
          'inline-flex w-full items-center justify-between gap-2 border border-ink-25 bg-paper px-3 text-left text-[13px] text-ink transition-colors hover:border-ink focus:border-ink focus:outline-none data-[placeholder]:text-ink-45 data-[state=open]:border-ink no-drag',
          size === 'sm' ? 'h-8 text-[12px]' : 'h-9',
          className
        )}
      >
        <RSelect.Value placeholder={placeholder} />
        <RSelect.Icon>
          <span className="text-[10px] text-ink-70">▼</span>
        </RSelect.Icon>
      </RSelect.Trigger>
      <RSelect.Portal>
        <RSelect.Content position="popper" sideOffset={-1} className="z-50 min-w-[var(--radix-select-trigger-width)] border border-ink bg-paper">
          <RSelect.Viewport>
            {options.map((o) => (
              <RSelect.Item
                key={String(o.value)}
                value={String(o.value)}
                className="relative flex cursor-default select-none flex-col border-b border-ink-12 px-3 py-2 text-[13px] outline-none last:border-b-0 data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[state=checked]:font-medium"
              >
                <RSelect.ItemText>{o.label}</RSelect.ItemText>
                {o.help ? <span className="text-[11px] opacity-60">{o.help}</span> : null}
              </RSelect.Item>
            ))}
          </RSelect.Viewport>
        </RSelect.Content>
      </RSelect.Portal>
    </RSelect.Root>
  )
}

/* ------------------------------------------------------------------------ */
/* Segmented control                                                         */
/* ------------------------------------------------------------------------ */

export function Segmented<T extends string | number>({
  value,
  onChange,
  options,
  className,
  size = 'md'
}: {
  value: T
  onChange: (v: T) => void
  options: { value: T; label: React.ReactNode; title?: string }[]
  className?: string
  size?: 'sm' | 'md'
}) {
  return (
    <div className={cn('inline-flex border border-ink no-drag', className)}>
      {options.map((o, i) => (
        <button
          key={String(o.value)}
          type="button"
          title={o.title}
          aria-pressed={value === o.value}
          onClick={() => onChange(o.value)}
          className={cn(
            'px-3 font-medium uppercase tracking-[0.08em] transition-colors duration-[120ms]',
            i > 0 && 'border-l border-ink',
            size === 'sm' ? 'h-7 text-[10px]' : 'h-9 text-[11px]',
            value === o.value ? 'bg-ink text-paper' : 'text-ink hover:bg-ink-06'
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

/* ------------------------------------------------------------------------ */
/* Tabs                                                                      */
/* ------------------------------------------------------------------------ */

export const Tabs = RTabs.Root
export function TabsList({ className, ...props }: React.ComponentProps<typeof RTabs.List>) {
  return <RTabs.List className={cn('flex items-end gap-6 border-b border-ink-12 no-drag', className)} {...props} />
}
export function TabsTrigger({ className, ...props }: React.ComponentProps<typeof RTabs.Trigger>) {
  return (
    <RTabs.Trigger
      className={cn(
        't-micro -mb-px border-b-2 border-transparent pb-2 text-ink-45 transition-colors hover:text-ink data-[state=active]:border-ink data-[state=active]:text-ink disabled:opacity-30',
        className
      )}
      {...props}
    />
  )
}
export const TabsContent = RTabs.Content

/* ------------------------------------------------------------------------ */
/* Tooltip                                                                   */
/* ------------------------------------------------------------------------ */

export const TooltipProvider = RTooltip.Provider

export function Tip({ content, children, side = 'top', delay = 300 }: { content: React.ReactNode; children: React.ReactElement; side?: 'top' | 'bottom' | 'left' | 'right'; delay?: number }) {
  if (!content) return children
  return (
    <RTooltip.Root delayDuration={delay}>
      <RTooltip.Trigger asChild>{children}</RTooltip.Trigger>
      <RTooltip.Portal>
        <RTooltip.Content side={side} sideOffset={6} className="z-[60] max-w-xs bg-ink px-3 py-2 text-[12px] leading-snug text-paper">
          {content}
        </RTooltip.Content>
      </RTooltip.Portal>
    </RTooltip.Root>
  )
}

/* ------------------------------------------------------------------------ */
/* Dropdown menu                                                             */
/* ------------------------------------------------------------------------ */

export const Menu = RDropdown.Root
export const MenuTrigger = RDropdown.Trigger
export function MenuContent({ className, ...props }: React.ComponentProps<typeof RDropdown.Content>) {
  return (
    <RDropdown.Portal>
      <RDropdown.Content sideOffset={4} align="end" className={cn('z-50 min-w-52 border border-ink bg-paper text-[13px]', className)} {...props} />
    </RDropdown.Portal>
  )
}
/** `danger` is weight, not colour; prefix the label with ✕. */
export function MenuItem({ className, danger, ...props }: React.ComponentProps<typeof RDropdown.Item> & { danger?: boolean }) {
  return (
    <RDropdown.Item
      className={cn(
        'flex cursor-default select-none items-center gap-3 px-3 py-2 outline-none transition-colors data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[disabled]:opacity-30 [&_svg]:size-3.5',
        danger && 'font-medium',
        className
      )}
      {...props}
    />
  )
}
export function MenuSeparator() {
  return <RDropdown.Separator className="h-px bg-ink-12" />
}
export function MenuLabel({ children }: { children: React.ReactNode }) {
  return <div className="t-micro px-3 pb-1 pt-2 text-ink-45">{children}</div>
}
export const MenuSub = RDropdown.Sub
export function MenuSubTrigger({ className, ...props }: React.ComponentProps<typeof RDropdown.SubTrigger>) {
  return (
    <RDropdown.SubTrigger
      className={cn('flex cursor-default select-none items-center gap-3 px-3 py-2 outline-none data-[highlighted]:bg-ink data-[highlighted]:text-paper data-[state=open]:bg-ink data-[state=open]:text-paper [&_svg]:size-3.5', className)}
      {...props}
    />
  )
}
export function MenuSubContent({ className, ...props }: React.ComponentProps<typeof RDropdown.SubContent>) {
  return (
    <RDropdown.Portal>
      <RDropdown.SubContent sideOffset={-1} className={cn('z-50 min-w-44 border border-ink bg-paper text-[13px]', className)} {...props} />
    </RDropdown.Portal>
  )
}

/* ------------------------------------------------------------------------ */
/* Popover                                                                   */
/* ------------------------------------------------------------------------ */

export const Popover = RPopover.Root
export const PopoverTrigger = RPopover.Trigger
export function PopoverContent({ className, ...props }: React.ComponentProps<typeof RPopover.Content>) {
  return (
    <RPopover.Portal>
      <RPopover.Content sideOffset={4} className={cn('z-50 border border-ink bg-paper p-3 outline-none', className)} {...props} />
    </RPopover.Portal>
  )
}

/* ------------------------------------------------------------------------ */
/* Dialog                                                                    */
/* ------------------------------------------------------------------------ */

export const Dialog = RDialog.Root
export const DialogTrigger = RDialog.Trigger
export function DialogContent({
  className,
  title,
  description,
  children,
  size = 'md',
  ...props
}: React.ComponentProps<typeof RDialog.Content> & { title?: React.ReactNode; description?: React.ReactNode; size?: 'sm' | 'md' | 'lg' | 'xl' }) {
  const widths = { sm: 'max-w-sm', md: 'max-w-lg', lg: 'max-w-2xl', xl: 'max-w-4xl' }
  return (
    <RDialog.Portal>
      <RDialog.Overlay className="fixed inset-0 z-50 bg-overlay" />
      <RDialog.Content
        className={cn('fixed left-1/2 top-1/2 z-50 w-[calc(100%-2rem)] -translate-x-1/2 -translate-y-1/2 border border-ink bg-paper p-6 focus:outline-none', widths[size], className)}
        {...props}
      >
        {title ? <RDialog.Title className="t-h2 pr-8">{title}</RDialog.Title> : <RDialog.Title className="sr-only">Dialog</RDialog.Title>}
        {description ? <RDialog.Description className="mt-1 text-[13px] text-ink-70">{description}</RDialog.Description> : null}
        <div className={cn(title ? 'mt-5' : '')}>{children}</div>
        <RDialog.Close className="absolute right-4 top-4 p-1 text-ink-45 transition-colors hover:text-ink">
          <X className="size-4" />
        </RDialog.Close>
      </RDialog.Content>
    </RDialog.Portal>
  )
}
export const DialogClose = RDialog.Close

/** Ghost Cancel, then the primary. */
export function DialogFooter({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={cn('mt-6 flex justify-end gap-2', className)}>{children}</div>
}

/** Strong-rule action bar for big dialogs and sticky page footers. */
export function Bar({ children, className, sticky }: { children: React.ReactNode; className?: string; sticky?: boolean }) {
  return (
    <div className={cn('flex items-center justify-between gap-6 border-t-2 border-ink pt-4', sticky && 'sticky bottom-0 z-10 mt-auto bg-paper px-8 py-3 pt-3', className)}>
      {children}
    </div>
  )
}

/* ------------------------------------------------------------------------ */
/* Badge / Chip / Tag / Progress / Kbd / ScrollArea / Spinner               */
/* ------------------------------------------------------------------------ */

export function Badge({ className, tone = 'neutral', children }: { className?: string; tone?: 'neutral' | 'invert'; children: React.ReactNode }) {
  return (
    <span className={cn('t-micro inline-flex h-5 items-center border px-1.5', tone === 'invert' ? 'border-ink bg-ink text-paper' : 'border-ink-25 text-ink-70', className)}>
      {children}
    </span>
  )
}

/** Kind marker on a row that may be inverted: border follows the text colour. */
export function Chip({ children, className }: { children: React.ReactNode; className?: string }) {
  return <span className={cn('t-micro shrink-0 border border-current px-1', className)}>{children}</span>
}

/** Selectable tag. */
export function Tag({ on, children, className, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & { on?: boolean }) {
  return (
    <button
      type="button"
      aria-pressed={on}
      className={cn('h-7 border px-2.5 text-[12px] transition-colors duration-[120ms]', on ? 'border-ink bg-ink text-paper' : 'border-ink-25 text-ink-70 hover:border-ink hover:text-ink', className)}
      {...props}
    >
      {children}
    </button>
  )
}

export function Progress({ value, className, indeterminate }: { value: number; className?: string; indeterminate?: boolean }) {
  return (
    <div className={cn('relative h-[3px] w-full overflow-hidden bg-ink-12', className)}>
      {indeterminate ? <div className="hatch-live absolute inset-0" /> : <div className="h-full bg-ink transition-[width] duration-300 ease-linear" style={{ width: `${Math.max(0, Math.min(100, value * 100))}%` }} />}
    </div>
  )
}

export function Kbd({ children }: { children: React.ReactNode }) {
  return <kbd className="t-mono border border-ink-25 px-1.5 py-0.5 text-[10px] text-ink-70">{children}</kbd>
}

export function ScrollArea({ className, children, viewportClassName }: { className?: string; children: React.ReactNode; viewportClassName?: string }) {
  return (
    <RScroll.Root className={cn('overflow-hidden', className)}>
      <RScroll.Viewport className={cn('size-full', viewportClassName)}>{children}</RScroll.Viewport>
      <RScroll.Scrollbar orientation="vertical" className="flex w-2 touch-none select-none">
        <RScroll.Thumb className="relative flex-1 bg-ink-25" />
      </RScroll.Scrollbar>
    </RScroll.Root>
  )
}

export function Spinner({ className }: { className?: string }) {
  return <Loader2 className={cn('size-4 animate-spin text-ink-70', className)} />
}

/* ------------------------------------------------------------------------ */
/* Family primitives                                                         */
/* ------------------------------------------------------------------------ */

/** Horizontal rule; `strong` for major divisions. */
export function Rule({ strong, className }: { strong?: boolean; className?: string }) {
  return <hr className={cn('border-0', strong ? 'h-[2px] bg-ink' : 'h-px bg-ink-12', className)} />
}

/** Index numeral, e.g. "01". */
export function Numeral({ n, className }: { n: number; className?: string }) {
  return <span className={cn('t-mono text-[11px] text-ink-45', className)}>{String(n).padStart(2, '0')}</span>
}

/** Animated diagonal hatch fill; the material for "running". */
export function Hatch({ className, live = true }: { className?: string; live?: boolean }) {
  return <div className={cn(live ? 'hatch-live' : 'hatch', className)} aria-hidden />
}

/** The 6px live square. Breathes while `on`. */
export function Dot({ on = true, className }: { on?: boolean; className?: string }) {
  return <span className={cn('inline-block size-1.5 shrink-0 bg-current', on && 'breathe', className)} aria-hidden />
}

/** Scrolls text horizontally when it overflows its container. */
export function Marquee({ text, className }: { text: string; className?: string }) {
  const ref = React.useRef<HTMLDivElement>(null)
  const [overflow, setOverflow] = React.useState(false)
  React.useEffect(() => {
    const el = ref.current
    if (!el) return
    const check = (): void => setOverflow(el.scrollWidth > el.clientWidth + 2)
    check()
    const ro = new ResizeObserver(check)
    ro.observe(el)
    return () => ro.disconnect()
  }, [text])
  return (
    <div ref={ref} className={cn('overflow-hidden whitespace-nowrap', className)} title={text}>
      {overflow ? (
        <span className="marquee">
          <span className="pr-8">{text}</span>
          <span className="pr-8">{text}</span>
        </span>
      ) : (
        <span className="block truncate">{text}</span>
      )}
    </div>
  )
}

/** Segmented meter of cells (discrete levels). */
export function Meter({ value, max, labels, className, onCellClick }: { value: number; max: number; labels?: string[]; className?: string; onCellClick?: (index: number) => void }) {
  return (
    <div className={cn('flex gap-[2px]', className)}>
      {Array.from({ length: max }).map((_, i) => {
        const on = i < value
        const label = labels?.[i]
        return (
          <button
            key={i}
            type="button"
            title={label}
            onClick={onCellClick ? () => onCellClick(i) : undefined}
            className={cn('h-2 flex-1 border border-ink transition-colors', on ? 'bg-ink' : 'bg-paper', onCellClick && !on && 'hover:bg-ink-25')}
            aria-label={label}
          />
        )
      })}
    </div>
  )
}

/** Loading placeholder block. */
export function Skeleton({ className }: { className?: string }) {
  return <div className={cn('skeleton', className)} aria-hidden />
}

/** Stacked skeleton blocks in the page padding. */
export function PageSkeleton() {
  return (
    <div className="flex h-full flex-col gap-6 p-8">
      <div className="skeleton h-8 w-48" />
      <div className="skeleton h-24 w-full" />
      <div className="skeleton h-24 w-full" />
      <div className="skeleton h-24 w-2/3" />
    </div>
  )
}

/** A short sentence with a full stop, one line, optional action. Never an icon. */
export function EmptyState({ title, description, action, boxed, className }: { title: string; description?: React.ReactNode; action?: React.ReactNode; boxed?: boolean; className?: string }) {
  return (
    <div className={cn('flex flex-col items-start gap-4', boxed ? 'border border-ink p-10' : 'px-8 py-16', className)}>
      <div className="t-display max-w-2xl">{title}</div>
      {description ? <div className="max-w-md text-[14px] text-ink-70">{description}</div> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  )
}

export function SectionTitle({ children, right, className, n }: { children: React.ReactNode; right?: React.ReactNode; className?: string; n?: number }) {
  return (
    <div className={cn('mb-4 flex items-end justify-between border-b border-ink pb-2', className)}>
      <h2 className="t-h2 flex items-baseline gap-3">
        {n != null ? <Numeral n={n} /> : null}
        {children}
      </h2>
      {right}
    </div>
  )
}

/** Page header: numeral + title, micro subtitle, actions right. */
export function PageHeader({ n, title, subtitle, children, className }: { n?: number; title: React.ReactNode; subtitle?: React.ReactNode; children?: React.ReactNode; className?: string }) {
  return (
    <div className={cn('flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b border-ink px-8 pb-4 pt-8', className)}>
      <div>
        <h1 className="t-h1 flex items-baseline gap-4">
          {n != null ? <Numeral n={n} /> : null}
          {title}
        </h1>
        {subtitle ? <p className="t-micro mt-2 text-ink-45">{subtitle}</p> : null}
      </div>
      {children ? <div className="ml-auto flex flex-wrap items-center gap-3">{children}</div> : null}
    </div>
  )
}

/** Micro-caps strip that heads a list section. */
export function Strip({ children, right, className }: { children: React.ReactNode; right?: React.ReactNode; className?: string }) {
  return (
    <div className={cn('t-micro flex items-center justify-between border-b border-ink px-8 py-3 text-ink-45', className)}>
      <span>{children}</span>
      {right}
    </div>
  )
}

/** Settings row: label + help left, control(s) right. */
export function Row({ label, help, children }: { label: string; help?: string; children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-[260px_1fr] items-center gap-6 border-b border-ink-12 py-3 last:border-b-0">
      <div>
        <div className="text-[13px]">{label}</div>
        {help ? <div className="mt-0.5 text-[11px] leading-snug text-ink-45">{help}</div> : null}
      </div>
      <div className="flex items-center gap-3">{children}</div>
    </div>
  )
}

/** Micro label over a value. */
export function Stat({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="t-micro text-ink-45">{label}</div>
      <div className="text-[14px]">{children}</div>
    </div>
  )
}

/** Stage row: glyph, label, mono right; progress while running. */
export type StageStatus = 'pending' | 'running' | 'done' | 'skipped' | 'failed'
const STAGE_GLYPH: Record<StageStatus, string> = { done: '✓', running: '●', skipped: '–', failed: '✕', pending: '○' }
export function Stage({ status, label, right, progress, detail }: { status: StageStatus; label: string; right?: string; progress?: number | null; detail?: string }) {
  const muted = status === 'pending' || status === 'skipped'
  return (
    <div className="py-1">
      <div className="flex items-center gap-3">
        {status === 'running' ? <span className="breathe mx-[3px] block size-1.5 shrink-0 bg-ink" /> : <span className={cn('t-mono w-3 text-[11px]', muted && 'text-ink-45')}>{STAGE_GLYPH[status]}</span>}
        <span className={cn('min-w-0 flex-1 truncate text-[12px]', muted ? 'text-ink-45' : 'text-ink')}>{label}</span>
        {right ? <span className="t-mono shrink-0 text-[11px] text-ink-70">{right}</span> : null}
      </div>
      {status === 'running' ? (
        <div className="mt-1 flex items-center gap-2 pl-6">
          <Progress value={progress ?? 0} indeterminate={progress == null} className="flex-1" />
          {detail ? <span className="max-w-[45%] truncate text-[11px] text-ink-45">{detail}</span> : null}
        </div>
      ) : null}
    </div>
  )
}

/** Inverted (system / problem) or outlined (information) full-width bar. */
export function Notice({ kicker, children, actions, invert, className }: { kicker?: string; children: React.ReactNode; actions?: React.ReactNode; invert?: boolean; className?: string }) {
  return (
    <div className={cn('flex items-center gap-4 text-[13px]', invert ? 'bg-ink px-4 py-2 text-paper' : 'border border-ink px-4 py-3', className)}>
      {kicker ? <span className="t-micro">{kicker}</span> : null}
      <span className="min-w-0 flex-1 truncate">{children}</span>
      {actions}
    </div>
  )
}

/** Numbered steps in one frame. */
export function Steps({ steps, current, onSelect, className }: { steps: string[]; current: number; onSelect?: (i: number) => void; className?: string }) {
  return (
    <div className={cn('flex border border-ink', className)}>
      {steps.map((label, i) => {
        const n = i + 1
        const done = n < current
        return (
          <button
            key={label}
            type="button"
            disabled={!done || !onSelect}
            onClick={() => onSelect?.(n)}
            className={cn('t-micro flex h-8 items-center gap-2 border-r border-ink px-3 last:border-r-0', current === n ? 'bg-ink text-paper' : done ? 'hover:bg-ink-06' : 'text-ink-45')}
          >
            <span className="t-mono">{String(n).padStart(2, '0')}</span> {label}
          </button>
        )
      })}
    </div>
  )
}
