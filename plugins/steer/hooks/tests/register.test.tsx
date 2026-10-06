import { describe, expect, test } from 'claude-code/testing'

import { bandText, parseBrief } from '../register'

const ran = (stdout: string) => ({
  value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
})

const ABOVE_PROMPT = {
  plugin: 'steer',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 120, scroll: { offset: 0, bodyRows: 4 }, view: {} },
} as const

const MANAGED = [
  'branch=issue/42-checkout',
  'delivery=pr-flow',
  'spine=managed',
  'features=2',
  'drafts=1',
  'questions=3',
  'proposed_adrs=1',
  'claims=0',
  'faults=0',
].join('\n')

describe('bandText', () => {
  test('summarises a managed repo, leaving zero counts out', async () => {
    expect(bandText(parseBrief(MANAGED))).toBe(
      'steer - pr-flow - issue/42-checkout - 2 features (1 draft) - 3 open questions - 1 ADR to ratify',
    )
  })

  test('stays quiet where steer does not manage the repo', async () => {
    expect(bandText(parseBrief('spine=unmanaged\nfeatures=0'))).toBeNull()
    expect(bandText(parseBrief('spine=foreign'))).toBeNull()
    expect(bandText(parseBrief(''))).toBeNull()
  })

  test('pluralises drafts', async () => {
    expect(bandText(parseBrief('spine=managed\nfeatures=3\ndrafts=2'))).toBe('steer - 3 features (2 drafts)')
  })

  test('names an abnormal spine and routes faults to /steer:report', async () => {
    expect(bandText(parseBrief('spine=damaged\ndelivery=solo-trunk\nfaults=2'))).toBe(
      'steer - solo-trunk - spine: damaged - 2 steer faults -> /steer:report',
    )
  })
})

test('the band draws the snapshot on every surface that draws', async ($, on) => {
  on('process.run', async () => ran(MANAGED))
  on('command.register', async ($, e) => ({ value: { command: e.name } }))
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...ABOVE_PROMPT, surface })
    expect(await ui.find({ type: 'Text', text: /3 open questions/ })).toBeDefined()
    await ui.unmount()
  }
})

test('the snapshot reads the session directory, then the one a cwd change moves to', async ($, on) => {
  const cwds: (string | undefined)[] = []
  on('process.run', async ($, e) => {
    cwds.push(e.init?.cwd)
    return ran(MANAGED)
  })
  on('command.register', async ($, e) => ({ value: { command: e.name } }))
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  on('classic.CwdChanged', async () => ({}))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  await $.classic.CwdChanged({ old_cwd: '/repo', new_cwd: '/other' })
  expect(cwds).toEqual(['/repo', '/other'])
})

test('a snapshot that cannot run hides the band and reports the failure', async ($, on) => {
  on('process.run', async () => ({ deny: 'sh not found' }))
  // The engine's own AbovePrompt, drawn when the band steps aside.
  on('ui.render', async ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>prompt</Text>
  })
  on('command.register', async ($, e) => ({ value: { command: e.name } }))
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount({ ...ABOVE_PROMPT, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: 'prompt' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /steer/ })).toBeUndefined()
  await ui.unmount()
  const out = await $.command.run({
    command: 'steer_snapshot',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })
  expect(out.text).toContain('steer snapshot failed')
})

test('/steer_snapshot answers with the full report', async ($, on) => {
  on('process.run', async () => ran('## Workspace snapshot'))
  const out = await $.command.run({
    command: 'steer_snapshot',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })
  expect(out.text).toContain('## Workspace snapshot')
})
