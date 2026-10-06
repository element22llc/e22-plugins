import { describe, expect, test } from 'claude-code/testing'

import { bandText, parseBrief } from './register'

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

  test('names an abnormal spine and routes faults to /steer:report', async () => {
    expect(bandText(parseBrief('spine=damaged\ndelivery=solo-trunk\nfaults=2'))).toBe(
      'steer - solo-trunk - spine: damaged - 2 steer faults -> /steer:report',
    )
  })
})

test('the band draws the snapshot on every surface that draws', async ($, on) => {
  on('process.run', async () => ({
    value: { exitCode: 0, stdout: MANAGED, stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('command.register', async ($, e) => ({ value: { command: e.name } }))
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'steer',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 120, scroll: { offset: 0, bodyRows: 4 }, view: {} },
    })
    expect(await ui.find({ type: 'Text', text: /3 open questions/ })).toBeDefined()
    await ui.unmount()
  }
})

test('/steer-snapshot answers with the full report', async ($, on) => {
  on('process.run', async () => ({
    value: { exitCode: 0, stdout: '## Workspace snapshot', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  const out = await $.command.run({
    command: 'steer-snapshot',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })
  expect(out.text).toContain('## Workspace snapshot')
})
