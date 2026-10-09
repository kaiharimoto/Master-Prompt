#!/usr/bin/env node
/**
 * master-ui check — finds what breaks the Master UI laws in a source tree.
 *
 * Self-contained (no dependencies). `init` copies this file into a project as
 * master-ui/check.mjs so it works without the kit repo:
 *
 *   node master-ui/check.mjs [dir=.] [--allow <glob>]... [--json] [--quiet]
 *
 * Errors (exit 1): non-zero border-radius; box/text-shadow; blur / drop-shadow /
 * backdrop-filter; linear/radial/conic gradients (the hatch, the link underline
 * and the range track are allowed); any colour that is not black, white, their
 * alphas, transparent or currentColor; Tailwind rounded-*, shadow-*, blur-*,
 * drop-shadow-*, bg-gradient-* and colour utilities.
 * Warnings: emoji, exclamation marks ending a string, ⌘ / Cmd, font weights
 * 600/800/900.
 * Allowed: `--allow` globs, a line containing `master-ui: allow`, anything in a
 * `.claude-room` / guest-palette scope (`--c-*`, `c-*` utilities, `spark`).
 */
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative, sep } from 'node:path'
import { pathToFileURL } from 'node:url'

const EXT = new Set(['.css', '.scss', '.less', '.html', '.htm', '.tsx', '.jsx', '.ts', '.js', '.mjs', '.cjs', '.vue', '.svelte', '.astro'])
const SKIP_DIRS = new Set(['node_modules', 'dist', 'out', 'build', '.git', 'master-ui', 'coverage', '.next', '.nuxt', '.svelte-kit', '.venv', 'venv', '__pycache__', '.cache', 'release', 'target'])

const PALETTE = 'red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|slate|gray|grey|zinc|neutral|stone'
const NAMED = `${PALETTE}|brown|gold|silver|navy|maroon|olive|crimson|coral|salmon|tomato|khaki|beige|ivory|tan|aqua|magenta|turquoise|orchid|plum|chocolate|firebrick|goldenrod|steelblue|royalblue|dodgerblue|deepskyblue|limegreen|forestgreen|seagreen|darkorange|orangered|hotpink|deeppink|whitesmoke|gainsboro|lightgray|lightgrey|darkgray|darkgrey|dimgray|dimgrey|lightblue|lightgreen|yellowgreen|palegreen|rebeccapurple|indianred|lightcoral|darkred|darkgreen|darkblue|midnightblue|slateblue|slategray|slategrey|lightslategray|cornflowerblue|skyblue|powderblue|cadetblue|darkcyan|darkturquoise|mediumseagreen|springgreen|chartreuse|greenyellow|lemonchiffon|papayawhip|moccasin|peachpuff|wheat|burlywood|sandybrown|peru|sienna|saddlebrown|rosybrown|mistyrose|lavender|thistle|violet|mediumpurple|blueviolet|darkviolet|darkorchid|mediumorchid|palevioletred|mediumvioletred|lightpink|honeydew|mintcream|azure|aliceblue|ghostwhite|seashell|linen|oldlace|floralwhite|antiquewhite|bisque|blanchedalmond|cornsilk|lightyellow|lightcyan|darkkhaki|darkgoldenrod|darkolivegreen|darkseagreen|darkslategray|darkslategrey|darkslateblue|darkmagenta|mediumblue|mediumaquamarine|mediumspringgreen|mediumturquoise|mediumslateblue|lightseagreen|lightskyblue|lightsteelblue|lightsalmon|lawngreen|olivedrab|paleturquoise|palegoldenrod|navajowhite|snow`
const GUEST = /claude-room|claude-button|claude-mark|\bspark\b|--c-(?:dark|light|mid|gray|surface|orange|blue|green)\b|(?<![\w-])(?:bg|text|border|ring|fill|stroke|from|via|to|outline|decoration|divide|placeholder|hover:bg|hover:text|hover:border|focus-within:border|data-\[[^\]]+\]:bg|group-hover:text)-c-(?:dark|light|mid|gray|surface|orange|blue|green)\b/
const ALLOWED_GLYPHS = new Set([...'✓✕★☆♥●○◁▷▶■□–—→←↑↓▼▲≈×└┌•♪♫▁▂▃▅▇✔✗–'].map((c) => c.codePointAt(0)))

/** @typedef {{ file: string, line: number, rule: string, level: 'error'|'warn', snippet: string }} Finding */

const RULES = [
  // ---- errors -------------------------------------------------------------
  {
    id: 'radius',
    level: 'error',
    test: (l) => {
      const out = []
      for (const m of l.matchAll(/border(?:[A-Z][a-z]+)*Radius\s*:\s*['"`]([^'"`]+)['"`]/g)) {
        const v = m[1].trim()
        if (!/^(?:0(?:px|rem|em|%)?\s*)+$/.test(v)) out.push(m[0])
      }
      for (const m of l.matchAll(/border(?:-[a-z]+)*-radius\s*:\s*([^;}]+)/g)) {
        const v = m[1].replace(/!important/g, '').trim()
        if (!/^(?:0(?:px|rem|em|%)?\s*)+$/.test(v) && !/^var\(--radius/.test(v)) out.push(m[0])
      }
      for (const m of l.matchAll(/(?<![\w-])(?:[a-z-]+:)*rounded(?:-(?!none\b)[\w-]+|-\[[^\]]+\])?(?![\w-])/g)) out.push(m[0])
      return out
    }
  },
  {
    id: 'shadow',
    level: 'error',
    test: (l) => {
      const out = []
      for (const m of l.matchAll(/(?:box|text)Shadow\s*:\s*['"`]([^'"`]+)['"`]/g)) {
        if (m[1].trim() !== 'none') out.push(m[0])
      }
      for (const m of l.matchAll(/(?:box|text)-shadow\s*:\s*([^;}]+)/g)) {
        const v = m[1].replace(/!important/g, '').trim()
        if (v !== 'none' && !/^var\(--shadow/.test(v)) out.push(m[0])
      }
      for (const m of l.matchAll(/(?<![\w-])(?:[a-z-]+:)*(?:inset-)?(?:drop-)?shadow(?:-(?!none\b)[\w-]+|-\[[^\]]+\])?(?![\w-])/g)) out.push(m[0])
      return out
    }
  },
  {
    id: 'blur',
    level: 'error',
    test: (l) => {
      const out = []
      for (const m of l.matchAll(/(?:backdropFilter|filter)\s*:\s*['"`]([^'"`]+)['"`]/g)) {
        if (/blur\(|drop-shadow\(/.test(m[1]) || (/^backdrop/.test(m[0]) && m[1].trim() !== 'none')) out.push(m[0])
      }
      for (const m of l.matchAll(/(?:backdrop-)?filter\s*:\s*([^;}]+)/g)) {
        const v = m[1].trim()
        if (/blur\(|drop-shadow\(/.test(v) || (/^backdrop/.test(m[0]) && v !== 'none')) out.push(m[0])
      }
      for (const m of l.matchAll(/(?<![\w.-])(?:[a-z-]+:)*(?:backdrop-)?blur(?:-[\w-]+|-\[[^\]]+\])?(?![\w(-])/g)) out.push(m[0])
      return out
    }
  },
  {
    id: 'gradient',
    level: 'error',
    test: (l) => {
      const out = []
      for (const m of l.matchAll(/(?<!repeating-)(?:linear|radial|conic)-gradient\(/g)) {
        const args = l.slice(m.index, m.index + 160)
        // Sanctioned: the link underline and the range track.
        if (/currentColor\s*,\s*currentColor/.test(args)) continue
        if (/var\(--pct/.test(args)) continue
        out.push(m[0])
      }
      for (const m of l.matchAll(/(?<![\w-])(?:[a-z-]+:)*bg-(?:linear|radial|conic|gradient)(?:-[\w-]+|-\[[^\]]+\])?(?![\w-])/g)) out.push(m[0])
      return out
    }
  },
  {
    id: 'colour',
    level: 'error',
    test: (l) => {
      const out = []
      for (const m of l.matchAll(/(?<![\w&])#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})(?![\w-])/g)) {
        // An id selector that happens to be hex-like (#face, #bad) is not a colour.
        const before = l.slice(0, m.index)
        if (/^\s*[{,>.:[]/.test(l.slice(m.index + m[0].length)) && /^(\s*|.*,\s*)$/.test(before) && !before.includes('(')) continue
        const h = m[1].toLowerCase()
        const rgb = h.length <= 4 ? h.slice(0, 3) : h.slice(0, 6)
        const norm = rgb.length === 3 ? rgb.split('').map((c) => c + c).join('') : rgb
        if (norm !== '000000' && norm !== 'ffffff') out.push(m[0])
      }
      for (const m of l.matchAll(/\b(rgba?|hsla?)\(\s*([^)]*)\)/g)) {
        const nums = m[2].split(/[\s,\/]+/).filter(Boolean)
        if (m[1].startsWith('rgb')) {
          const [r, g, b] = nums
          const ok = (r === '0' && g === '0' && b === '0') || (r === '255' && g === '255' && b === '255') || (r === '0%' && g === '0%' && b === '0%') || (r === '100%' && g === '100%' && b === '100%')
          if (!ok) out.push(m[0])
        } else {
          const light = nums[2]
          if (light !== '0%' && light !== '100%') out.push(m[0])
        }
      }
      for (const m of l.matchAll(/\b(?:oklch|oklab|lab|lch)\(\s*([^)]*)\)/g)) {
        const first = m[1].split(/[\s,]+/)[0]
        if (!['0', '0%', '1', '100%'].includes(first)) out.push(m[0])
      }
      const named = new RegExp(`(?:^|[\\s;{])(?:color|background(?:-color)?|border(?:-[a-z]+)?(?:-color)?|fill|stroke|outline(?:-color)?|caret-color|accent-color|text-decoration-color)\\s*:\\s*[^;}]*?\\b(${NAMED})\\b`, 'g')
      for (const m of l.matchAll(named)) out.push(m[0].trim())
      const tw = new RegExp(`(?<![\\w-])(?:[a-z-]+:)*(?:bg|text|border|ring|fill|stroke|from|via|to|outline|decoration|divide|accent|caret|placeholder|shadow|inset-ring)-(?:${PALETTE})-\\d{2,3}(?:/\\d+)?(?![\\w-])`, 'g')
      for (const m of l.matchAll(tw)) out.push(m[0])
      return out
    }
  },
  // ---- warnings -----------------------------------------------------------
  {
    id: 'emoji',
    level: 'warn',
    test: (l) => {
      const out = []
      for (const ch of l) {
        const cp = ch.codePointAt(0)
        const emoji = (cp >= 0x1f000 && cp <= 0x1faff) || cp === 0xfe0f || (cp >= 0x2600 && cp <= 0x27bf && !ALLOWED_GLYPHS.has(cp)) || (cp >= 0x1f900 && cp <= 0x1f9ff)
        if (emoji) out.push(ch)
      }
      return out
    }
  },
  {
    id: 'exclamation',
    level: 'warn',
    test: (l) => [...l.matchAll(/\w!(?=["'`]|\s*<\/|\s*$)/g)].map((m) => m[0])
  },
  {
    id: 'cmd-glyph',
    level: 'warn',
    test: (l) => [...l.matchAll(/⌘|\bCmd\s*\+|\bCMD\b/g)].map((m) => m[0])
  },
  {
    id: 'weight',
    level: 'warn',
    test: (l) => {
      const out = []
      for (const m of l.matchAll(/font-weight\s*:\s*(600|800|900)\b/g)) out.push(m[0])
      for (const m of l.matchAll(/(?<![\w-])(?:[a-z-]+:)*font-(?:semibold|extrabold|black)(?![\w-])/g)) out.push(m[0])
      return out
    }
  }
]

/** Strips comments; keeps state for block comments that span lines. */
function commentStripper() {
  let inBlock = false
  return (line) => {
    let out = ''
    let i = 0
    while (i < line.length) {
      if (inBlock) {
        const end = line.indexOf('*/', i)
        if (end < 0) return out
        inBlock = false
        i = end + 2
      } else {
        const start = line.indexOf('/*', i)
        if (start < 0) {
          out += line.slice(i)
          break
        }
        out += line.slice(i, start)
        inBlock = true
        i = start + 2
      }
    }
    return out.replace(/(^|\s)\/\/.*$/, '$1').replace(/<!--.*?-->/g, '')
  }
}

function globToRegExp(glob) {
  const esc = glob
    .replace(/\\/g, '/')
    .replace(/[.+^${}()|[\]]/g, '\\$&')
    .replace(/\*\*\//g, '(?:.*/)?')
    .replace(/\*\*/g, '.*')
    .replace(/\*/g, '[^/]*')
    .replace(/\?/g, '[^/]')
  return new RegExp(`^${esc}$`)
}

function* walk(dir) {
  let entries
  try {
    entries = readdirSync(dir, { withFileTypes: true })
  } catch {
    return
  }
  for (const e of entries) {
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue
      yield* walk(join(dir, e.name))
    } else if (e.isFile()) {
      const dot = e.name.lastIndexOf('.')
      if (dot >= 0 && EXT.has(e.name.slice(dot))) yield join(dir, e.name)
    }
  }
}

/**
 * Tracks CSS blocks so anything inside a guest-room rule is allowed.
 * Returns a function (line) => boolean "inside guest scope".
 */
function cssScopeTracker() {
  const stack = []
  let pending = ''
  return (line) => {
    const before = stack.some(Boolean)
    for (const ch of line) {
      if (ch === '{') {
        stack.push(GUEST.test(pending))
        pending = ''
      } else if (ch === '}') {
        stack.pop()
        pending = ''
      } else if (ch === ';') pending = ''
      else pending += ch
    }
    return before || stack.some(Boolean)
  }
}

/**
 * @param {{ dir?: string, allow?: string[] }} opts
 * @returns {{ findings: Finding[], files: number, errors: number, warnings: number }}
 */
export function check(opts = {}) {
  const root = opts.dir ?? '.'
  const allow = (opts.allow ?? []).map(globToRegExp)
  const findings = []
  let files = 0
  const rootStat = statSync(root)
  const list = rootStat.isFile() ? [root] : [...walk(root)]
  for (const file of list) {
    const rel = (rootStat.isFile() ? file : relative(root, file)).split(sep).join('/')
    if (allow.some((re) => re.test(rel))) continue
    if (/claude-room\.css$/.test(rel)) continue
    files++
    const text = readFileSync(file, 'utf8')
    const isCss = /\.(css|scss|less)$/.test(rel)
    const scope = isCss ? cssScopeTracker() : null
    const strip = commentStripper()
    const lines = text.split(/\r?\n/)
    for (let i = 0; i < lines.length; i++) {
      const raw = lines[i]
      const inGuest = scope ? scope(raw) : false
      if (inGuest || /master-ui:\s*allow/.test(raw) || GUEST.test(raw)) continue
      const line = strip(raw)
      if (!line.trim()) continue
      for (const rule of RULES) {
        const hits = rule.test(line)
        for (const hit of hits) findings.push({ file: rel, line: i + 1, rule: rule.id, level: rule.level, snippet: hit.length > 80 ? hit.slice(0, 77) + '…' : hit })
      }
    }
  }
  findings.sort((a, b) => (a.level === b.level ? a.file.localeCompare(b.file) || a.line - b.line : a.level === 'error' ? -1 : 1))
  return { findings, files, errors: findings.filter((f) => f.level === 'error').length, warnings: findings.filter((f) => f.level === 'warn').length }
}

export function format(result, dir) {
  const lines = []
  for (const f of result.findings) lines.push(`${f.file}:${f.line}  ${f.level === 'error' ? '✕' : '–'} ${f.rule.padEnd(11)} ${f.snippet}`)
  lines.push('')
  lines.push(`${result.errors} error${result.errors === 1 ? '' : 's'} · ${result.warnings} warning${result.warnings === 1 ? '' : 's'} · ${result.files} file${result.files === 1 ? '' : 's'} in ${dir}`)
  return lines.join('\n')
}

export function parseArgs(argv) {
  const opts = { dir: '.', allow: [], json: false, quiet: false }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--allow') opts.allow.push(argv[++i])
    else if (a.startsWith('--allow=')) opts.allow.push(a.slice(8))
    else if (a === '--json') opts.json = true
    else if (a === '--quiet') opts.quiet = true
    else if (!a.startsWith('-')) opts.dir = a
  }
  return opts
}

export function main(argv = process.argv.slice(2)) {
  const opts = parseArgs(argv)
  const result = check(opts)
  if (opts.json) process.stdout.write(JSON.stringify(result, null, 2) + '\n')
  else if (!opts.quiet) process.stdout.write(format(result, opts.dir) + '\n')
  return result.errors ? 1 : 0
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main()
}
