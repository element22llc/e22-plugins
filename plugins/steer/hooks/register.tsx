// steer mod - the status band above the prompt, its detail pane, and
// /steer_snapshot. Every count and item comes from scripts/workspace-snapshot.sh;
// this module only draws. It enforces nothing: a press fills the prompt and
// never submits, so every gate stays the human's Enter and the skill's own.
// The band shows only steer state - nothing the status line or prompt hint
// already carries (cwd, branch, model, context, PR).
import type { EngineInterface, Register } from 'claude-code'

export type Brief = Record<string, string>
export type Section = 'features' | 'questions' | 'adrs' | 'claims'
export type BandPart = { text: string; section?: Section; command?: string }
export type Items = {
  features: { id: string; status: string }[]
  questions: { scope: string; id: string; status: string; impact: string; before: string; title: string }[]
  adrs: { n: string; title: string }[]
  claims: { issue: string; branch: string }[]
}

const QUIET_SPINES = new Set(['unmanaged', 'foreign'])
const PANE = 'steer'
const SECTIONS: { section: Section; label: string }[] = [
  { section: 'features', label: 'Features' },
  { section: 'questions', label: 'Open questions' },
  { section: 'adrs', label: 'ADRs to ratify' },
  { section: 'claims', label: 'Work claims' },
]

export function parseBrief(stdout: string): Brief {
  const brief: Brief = {}
  for (const line of stdout.split('\n')) {
    const at = line.indexOf('=')
    if (at > 0) brief[line.slice(0, at)] = line.slice(at + 1)
  }
  return brief
}

const dash = (v: string | undefined) => (v === undefined || v === '-' ? '' : v)

export function parseItems(stdout: string): Items {
  const items: Items = { features: [], questions: [], adrs: [], claims: [] }
  for (const line of stdout.split('\n')) {
    const [kind, a = '', b = '', c = '', d, e, f] = line.split('\t')
    if (kind === 'F') items.features.push({ id: a, status: b })
    if (kind === 'Q')
      items.questions.push({ scope: a, id: b, status: c, impact: dash(d), before: dash(e), title: dash(f) })
    if (kind === 'A') items.adrs.push({ n: a, title: b })
    if (kind === 'C') items.claims.push({ issue: a, branch: b })
  }
  items.questions.sort((x, y) => Number(y.impact === 'blocking') - Number(x.impact === 'blocking'))
  return items
}

function count(n: string | undefined, one: string, many: string): string | null {
  const v = Number(n ?? 0)
  return v > 0 ? `${v} ${v === 1 ? one : many}` : null
}

export function bandParts(b: Brief): BandPart[] | null {
  if (!b.spine || QUIET_SPINES.has(b.spine)) return null
  const drafts = Number(b.drafts ?? 0)
  const features = count(b.features, 'feature', 'features')
  const parts: (BandPart | null)[] = [
    { text: 'steer' },
    b.delivery ? { text: b.delivery } : null,
    b.spine === 'managed' ? null : { text: `spine: ${b.spine}` },
    part(drafts > 0 && features ? `${features} (${count(b.drafts, 'draft', 'drafts')})` : features, {
      section: 'features',
    }),
    part(count(b.questions, 'open question', 'open questions'), { section: 'questions' }),
    part(count(b.proposed_adrs, 'ADR to ratify', 'ADRs to ratify'), { section: 'adrs' }),
    part(count(b.claims, 'work claim', 'work claims'), { section: 'claims' }),
    part(count(b.faults, 'steer fault -> /steer:report', 'steer faults -> /steer:report'), {
      command: '/steer:report',
    }),
  ]
  return parts.filter((p): p is BandPart => p !== null)
}

function part(text: string | null, rest: Omit<BandPart, 'text'>): BandPart | null {
  return text === null ? null : { text, ...rest }
}

export function bandText(b: Brief): string | null {
  return bandParts(b)?.map(p => p.text).join(' - ') ?? null
}

// What a row's button puts in the prompt: the skill that owns that item.
export function featureCommand(f: Items['features'][number]): string {
  return f.status === 'draft' ? `/steer:spec ${f.id}` : `/steer:status feature ${f.id}`
}

export function questionCommand(q: Items['questions'][number]): string {
  return q.scope === 'vision' ? '/steer:spec questions' : `/steer:spec ${q.scope}`
}

// cwd: the directory the script resolves its repo root from; absent, the
// session's working directory.
function snapshot($: EngineInterface, args: string[], cwd?: string) {
  return $.process.run(['sh', `${$.plugin.root}/scripts/workspace-snapshot.sh`, ...args], {
    cwd,
    env: { CLAUDE_PLUGIN_ROOT: $.plugin.root },
    timeoutMs: 10_000,
  })
}

let parts: BandPart[] | null = null
let items: Items | null = null
let shown: Section = 'questions'
let lastCwd: string | undefined

// A snapshot that fails or cannot start hides the band; it never rejects, so
// the fire-and-forget callers below leave no unhandled rejection.
async function refresh($: EngineInterface, cwd?: string) {
  if (cwd !== undefined) lastCwd = cwd
  let fresh: BandPart[] | null = null
  try {
    const run = await snapshot($, ['--brief'], lastCwd)
    fresh = run.exitCode === 0 ? bandParts(parseBrief(run.stdout)) : null
  } catch {
    fresh = null
  }
  if (JSON.stringify(fresh) !== JSON.stringify(parts)) {
    parts = fresh
    $.ui.invalidate('ui.render')
  }
  const panes = await $.ui.panes().catch(() => [])
  if (panes.some(p => p.id === PANE)) await loadItems($)
}

async function loadItems($: EngineInterface) {
  let fresh: Items | null = null
  try {
    const run = await snapshot($, ['--items'], lastCwd)
    fresh = run.exitCode === 0 ? parseItems(run.stdout) : null
  } catch {
    fresh = null
  }
  items = fresh
  $.ui.invalidate('ui.render')
}

async function show($: EngineInterface, section: Section) {
  shown = section
  $.ui.invalidate('ui.render')
  await $.ui.open({ id: PANE, title: 'steer', focus: true, closeOnEscape: true })
  await loadItems($)
}

// The pane holds the keys while open, and a box under a dialog refuses a fill.
async function suggest($: EngineInterface, text: string) {
  await $.ui.close({ id: PANE })
  await $.prompt.fill({ text, mode: 'replace' })
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    void refresh($, e.cwd)
    await $.command.register({
      name: 'steer_snapshot',
      description: 'Print the steer workspace snapshot now, without a Claude turn',
      immediate: true,
    })
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    void refresh($)
    return next(e)
  })

  // /cd or a worktree move: re-read the new directory's repo now, not at the
  // end of the next turn. CwdChanged also runs steer's shell hook, so a
  // failure here passes the event on untouched.
  on('classic.CwdChanged', async ($, e, next) => {
    void refresh($, e.new_cwd)
    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'steer_snapshot' }, async $ => {
    try {
      const run = await snapshot($, [], lastCwd)
      return { text: run.exitCode === 0 ? run.stdout : `steer snapshot failed: ${run.stderr}` }
    } catch (err) {
      return { text: `steer snapshot failed: ${err instanceof Error ? err.message : String(err)}` }
    }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (parts === null || e.props.hasSurvey) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="row" flexWrap="wrap">
        {parts.flatMap((p, i) => {
          const sep = i > 0 ? [<Text dimColor> - </Text>] : []
          const { section, command } = p
          if (section)
            return [
              ...sep,
              <Button
                key={`band-${section}`}
                label={p.text}
                plain
                dimColor
                onPress={() => show($, section)}
              />,
            ]
          if (command)
            return [
              ...sep,
              <Button key="band-report" label={p.text} plain dimColor onPress={() => suggest($, command)} />,
            ]
          return [...sep, <Text dimColor>{p.text}</Text>]
        })}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const row = (key: string, label: string, command: string, text: string) => (
      <Box key={key} flexDirection="row" gap={1}>
        <Button key={`do-${key}`} label={label} onPress={() => suggest($, command)} />
        <Text wrap="truncate-end">{text}</Text>
      </Box>
    )
    const sizes = items && {
      features: items.features.length,
      questions: items.questions.length,
      adrs: items.adrs.length,
      claims: items.claims.length,
    }
    const body = () => {
      if (items === null) return [<Text dimColor>Reading the spine...</Text>]
      if (sizes?.[shown] === 0) return [<Text dimColor>Nothing here.</Text>]
      if (shown === 'features')
        return items.features.map((f, i) =>
          row(`f-${i}`, f.status === 'draft' ? 'shape' : 'view', featureCommand(f), `${f.id}  ${f.status}`),
        )
      if (shown === 'questions')
        return [
          ...items.questions.map((q, i) =>
            row(
              `q-${i}`,
              'resolve',
              questionCommand(q),
              [q.id, q.scope, q.impact, q.before && `before: ${q.before}`, q.title].filter(Boolean).join('  '),
            ),
          ),
          <Box key="q-all" flexDirection="row" gap={1} marginTop={1}>
            <Button key="sweep" label="sweep all" onPress={() => suggest($, '/steer:spec questions')} />
            <Button key="bundle" label="PO questionnaire" onPress={() => suggest($, '/steer:spec questions bundle')} />
          </Box>,
        ]
      if (shown === 'adrs')
        return items.adrs.map((a, i) => row(`a-${i}`, 'ratify', `/steer:spec adr accept ${a.n}`, a.title || `ADR ${a.n}`))
      return items.claims.map((c, i) =>
        row(
          `c-${i}`,
          'resume',
          c.issue ? `/steer:work resume #${c.issue}` : '/steer:work resume',
          [c.issue && `#${c.issue}`, c.branch].filter(Boolean).join('  '),
        ),
      )
    }
    return (
      <Box flexDirection="column">
        <Box flexDirection="row" flexWrap="wrap" gap={1} marginBottom={1}>
          {SECTIONS.map(s => (
            <Button
              key={`tab-${s.section}`}
              label={sizes ? `${s.label} ${sizes[s.section]}` : s.label}
              variant={s.section === shown ? 'primary' : 'secondary'}
              onPress={() => {
                shown = s.section
                $.ui.invalidate('ui.render')
              }}
            />
          ))}
        </Box>
        {body()}
      </Box>
    )
  })
}
