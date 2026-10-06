// steer mod - read-only status band above the prompt + /steer-snapshot. Every
// count comes from scripts/workspace-snapshot.sh; this module only draws. It
// enforces nothing: gates stay in the sh hooks, which run where mods do not.
import type { EngineInterface, Register } from 'claude-code'

export type Brief = Record<string, string>

const QUIET_SPINES = new Set(['unmanaged', 'foreign'])

export function parseBrief(stdout: string): Brief {
  const brief: Brief = {}
  for (const line of stdout.split('\n')) {
    const at = line.indexOf('=')
    if (at > 0) brief[line.slice(0, at)] = line.slice(at + 1)
  }
  return brief
}

function count(n: string | undefined, one: string, many: string): string | null {
  const v = Number(n ?? 0)
  return v > 0 ? `${v} ${v === 1 ? one : many}` : null
}

export function bandText(b: Brief): string | null {
  if (!b.spine || QUIET_SPINES.has(b.spine)) return null
  const drafts = Number(b.drafts ?? 0)
  const features = count(b.features, 'feature', 'features')
  const parts = [
    'steer',
    b.delivery,
    b.branch,
    b.spine === 'managed' ? null : `spine: ${b.spine}`,
    features && drafts > 0 ? `${features} (${drafts} draft)` : features,
    count(b.questions, 'open question', 'open questions'),
    count(b.proposed_adrs, 'ADR to ratify', 'ADRs to ratify'),
    count(b.claims, 'work claim', 'work claims'),
    count(b.faults, 'steer fault -> /steer:report', 'steer faults -> /steer:report'),
  ]
  return parts.filter(Boolean).join(' - ')
}

function snapshot($: EngineInterface, args: string[]) {
  return $.process.run(['sh', `${$.plugin.root}/scripts/workspace-snapshot.sh`, ...args], {
    env: { CLAUDE_PLUGIN_ROOT: $.plugin.root },
    timeoutMs: 10_000,
  })
}

let line: string | null = null

async function refresh($: EngineInterface) {
  const run = await snapshot($, ['--brief'])
  const fresh = run.exitCode === 0 ? bandText(parseBrief(run.stdout)) : null
  if (fresh !== line) {
    line = fresh
    $.ui.invalidate('ui.render')
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    void refresh($)
    await $.command.register({
      name: 'steer-snapshot',
      description: 'Print the steer workspace snapshot now, without a Claude turn',
      immediate: true,
    })
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    void refresh($)
    return next(e)
  })

  on('command.run', { command: 'steer-snapshot' }, async $ => {
    const run = await snapshot($, [])
    return { text: run.exitCode === 0 ? run.stdout : `steer snapshot failed: ${run.stderr}` }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (line === null || e.props.hasSurvey) return next(e)
    const { Text } = $.ui.resolve(e)
    return <Text dimColor>{line}</Text>
  })
}
