import type { On } from 'claude-code'
import { describe, expect, test } from 'claude-code/testing'

import { bandText, parseBrief, parseItems } from '../register'

const ran = (stdout: string) => ({
  value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
})

const ABOVE_PROMPT = {
  plugin: 'steer',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 120, scroll: { offset: 0, bodyRows: 4 }, view: {} },
} as const

const PANE = { plugin: 'steer', component: 'Pane', requestId: 'steer' } as const

const ITEMS = [
  'F\tcheckout\tdraft',
  'F\tlogin\tapproved',
  'Q\tvision\tQ-003\tinvestigating\tnon-blocking\t-\tWho is the buyer?',
  'Q\tcheckout\tQ-001\topen\tblocking\tintent-approval\tWhich payment provider?',
  'A\t7\t7. Use Better Auth',
  'C\t42\tissue/42-checkout',
].join('\n')

const MANAGED = [
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
      'steer - pr-flow - 2 features (1 draft) - 3 open questions - 1 ADR to ratify',
    )
  })

  test('leaves out what the status line already shows', async () => {
    expect(bandText(parseBrief(`${MANAGED}\nbranch=issue/42-checkout\ncwd=/repo`))).not.toContain('issue/42')
  })

  test('offers only advisory mode where steer does not manage the repo', async () => {
    expect(bandText(parseBrief('spine=unmanaged\nfeatures=0'))).toBe('steer - advisory mode')
    expect(bandText(parseBrief('spine=foreign\nquestions=4'))).toBe('steer - advisory mode')
    expect(bandText(parseBrief(''))).toBeNull()
  })

  test('advisory mode replaces the spine counts with a way out', async () => {
    expect(bandText(parseBrief(`${MANAGED}\nmode=advisory`))).toBe('steer - advisory - leave advisory')
  })

  test('pluralises drafts', async () => {
    expect(bandText(parseBrief('spine=managed\nfeatures=3\ndrafts=2'))).toBe('steer - 3 features (2 drafts)')
  })

  test('names an abnormal spine and routes faults to a report ask', async () => {
    expect(bandText(parseBrief('spine=damaged\ndelivery=solo-trunk\nfaults=2'))).toBe(
      'steer - solo-trunk - spine: damaged - 2 steer faults -> report them',
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
    expect((await ui.find({ key: 'band-questions' }))?.props.label).toBe('3 open questions')
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

describe('parseItems', () => {
  test('reads each record kind and ranks blocking questions first', async () => {
    const items = parseItems(ITEMS)
    expect(items.features).toEqual([
      { id: 'checkout', status: 'draft' },
      { id: 'login', status: 'approved' },
    ])
    expect(items.questions.map(q => q.id)).toEqual(['Q-001', 'Q-003'])
    expect(items.questions[1]?.before).toBe('')
    expect(items.adrs).toEqual([{ n: '7', title: '7. Use Better Auth' }])
    expect(items.claims).toEqual([{ issue: '42', branch: 'issue/42-checkout' }])
  })
})

// The engine beneath the mod: the brief or the items per argv, one pane, one prompt box.
function engine(on: On) {
  const filled: string[] = []
  const open = new Set<string>()
  on('process.run', async ($, e) => ran(e.argv.includes('--items') ? ITEMS : MANAGED))
  on('command.register', async ($, e) => ({ value: { command: e.name } }))
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  on('ui.open', async ($, e) => {
    open.add(e.id)
    return { value: { isPlaced: true } }
  })
  on('ui.close', async ($, e) => {
    open.delete(e.id)
    return { value: undefined }
  })
  on('ui.panes', async () => ({
    value: [...open].map(id => ({ id, title: id, isShown: true, isFocused: true, isPlaced: true })),
  }))
  on('prompt.fill', async ($, e) => {
    filled.push(e.text)
    return { isFilled: true, box: { text: e.text, cursor: e.text.length } }
  })
  return { filled, open }
}

const PANE_PROPS = {
  title: 'steer',
  isFocused: true,
  bodyColumns: 100,
  placement: 'dock',
  scroll: { offset: 0, bodyRows: 20 },
  view: {},
} as const

test('a band count opens the pane on its items, and a row fills the prompt', async ($, on) => {
  const { filled, open } = engine(on)
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  for (const surface of ['terminal', 'desktop'] as const) {
    const band = await $.ui.mount({ ...ABOVE_PROMPT, surface })
    await band.press({ key: 'band-adrs' })
    expect(open.has('steer')).toBe(true)
    await band.unmount()
    const pane = await $.ui.mount({ ...PANE, surface, props: PANE_PROPS })
    expect(await pane.find({ type: 'Text', text: /Use Better Auth/ })).toBeDefined()
    await pane.press({ key: 'do-a-0' })
    expect(filled.at(-1)).toBe('/steer:spec adr accept 7')
    expect(open.has('steer')).toBe(false)
    await pane.unmount()
  }
})

test('the pane tabs between sections and routes each row to its owning skill', async ($, on) => {
  const { filled } = engine(on)
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  const band = await $.ui.mount({ ...ABOVE_PROMPT, surface: 'terminal' })
  await band.press({ key: 'band-questions' })
  await band.unmount()
  const pane = await $.ui.mount({ ...PANE, surface: 'terminal', props: PANE_PROPS })
  await pane.press({ key: 'do-q-0' })
  expect(filled.at(-1)).toBe('/steer:spec checkout')
  await pane.press({ key: 'do-q-1' })
  expect(filled.at(-1)).toBe('/steer:spec questions')
  await pane.press({ key: 'bundle' })
  expect(filled.at(-1)).toBe('/steer:spec questions bundle')
  await pane.press({ key: 'tab-features' })
  await pane.press({ key: 'do-f-0' })
  expect(filled.at(-1)).toBe('/steer:spec checkout')
  await pane.press({ key: 'do-f-1' })
  expect(filled.at(-1)).toBe('/steer:status feature login')
  await pane.press({ key: 'tab-claims' })
  await pane.press({ key: 'do-c-0' })
  expect(filled.at(-1)).toBe('/steer:work resume #42')
  await pane.unmount()
})

test('the advisory switch fills the setup mode and never submits', async ($, on) => {
  const filled: string[] = []
  let brief = 'spine=unmanaged\nmode='
  on('process.run', async () => ran(brief))
  on('command.register', async ($, e) => ({ value: { command: e.name } }))
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  on('classic.CwdChanged', async () => ({}))
  on('ui.close', async () => ({ value: undefined }))
  on('ui.panes', async () => ({ value: [] }))
  on('prompt.fill', async ($, e) => {
    filled.push(e.text)
    return { isFilled: true, box: { text: e.text, cursor: e.text.length } }
  })
  await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
  let band = await $.ui.mount({ ...ABOVE_PROMPT, surface: 'terminal' })
  await band.press({ key: 'band-advisory' })
  expect(filled.at(-1)).toBe('/steer:setup advisory')
  await band.unmount()
  brief = 'spine=unmanaged\nmode=advisory'
  await $.classic.CwdChanged({ old_cwd: '/repo', new_cwd: '/repo' })
  band = await $.ui.mount({ ...ABOVE_PROMPT, surface: 'terminal' })
  await band.press({ key: 'band-advisory' })
  expect(filled.at(-1)).toBe('/steer:setup advisory off')
  await band.unmount()
})
