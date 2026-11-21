export const meta = {
  name: 'pre-release-audit',
  description:
    'Judgment half of the steer pre-release audit: delta-scoped coherence reviewers plus the docs reviewer, then one verifier per finding, returned as ledger-ready candidates',
  whenToUse:
    'Invoked by /release Phase A and by /audit-loop each round for PRE-RELEASE-AUDIT.md Steps 3 and 4a. /release passes the JSON from release_preflight.py --plan as args: it skips both scouts and carries the computed tier (light = one combined reviewer for a small delta, full = one per dimension). No args runs the scouts and the full fan-out. Pass { dimensions: [...] } only for a non-final /audit-loop round that is allowed to trim.',
  phases: [
    { title: 'Scout', detail: 'resolve $LAST_RELEASE and the delta file list' },
    { title: 'Reconcile', detail: 'open ledger rows whose file changed since they were confirmed, re-verified one file at a time; a refuted row is returned for the ledger to close' },
    { title: 'Review', detail: 'read-only review of every dimension, scoped to the delta: one reviewer each (full) or one combined reviewer (light); a failed dispatch is retried once' },
    { title: 'Verify', detail: 'one verifier per deduplicated finding re-reads the cited line and may only lower severity' },
  ],
}

// Why a workflow and not prose. PRE-RELEASE-AUDIT.md Step 3 used to be
// orchestrated turn by turn by the model: dispatch six reviewers, wait for every
// one, re-dispatch the ones that returned nothing, vet each candidate against
// the line it cites, dedupe across dimensions, write the JSON the ledger reads.
// Each of those steps has failed at least once on the release path -- a
// reviewer that landed after the report was written, a dimension counted as
// clean because it never returned, a candidate reported on a summary instead of
// on the cited line. Here the loop is code: parallel() is the barrier that
// waits for every reviewer, a null result is retried exactly once and otherwise
// recorded as `unverified` (never as clean), findings are schema-validated so
// they cannot arrive as prose, and every in-delta finding goes through a
// verifier before it is a candidate. Severity is proposed here and CAPPED by
// path in scripts/audit_severity.py when the caller records the candidates --
// nothing in this file can raise a finding above its ceiling.

const SEVERITIES = ['blocker', 'high', 'medium', 'low']
const SEVERITY_ENUM = { type: 'string', enum: SEVERITIES }

const SCOUT_SCHEMA = {
  type: 'object',
  required: ['lastRelease', 'files', 'unreleased', 'pluginVersion'],
  properties: {
    lastRelease: { type: 'string', description: "output of git describe --tags --match 'v*' --abbrev=0" },
    files: { type: 'array', items: { type: 'string' }, description: 'git diff --name-only <lastRelease>..HEAD' },
    unreleased: { type: 'string', description: 'every pending changelog fragment under .changes/unreleased/, verbatim' },
    pluginVersion: { type: 'string' },
  },
}

const LEDGER_OPEN_SCHEMA = {
  type: 'object',
  required: ['rows'],
  properties: {
    rows: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'ruleId', 'path', 'line', 'claim'],
        properties: {
          id: { type: 'string' },
          ruleId: { type: 'string' },
          path: { type: 'string' },
          line: { type: ['integer', 'null'] },
          claim: { type: 'string' },
        },
      },
    },
  },
}

const RECONCILE_SCHEMA = {
  type: 'object',
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      description: 'exactly one verdict per finding you were given',
      items: {
        type: 'object',
        required: ['id', 'holds', 'reason'],
        properties: {
          id: { type: 'string', description: 'the finding id, copied exactly' },
          holds: { type: 'boolean', description: 'true only if the cited file, read this round, still demonstrates the claim as stated' },
          reason: { type: 'string', description: 'one line: what the file says now, with the line you read' },
        },
      },
    },
  },
}

const FINDING_SCHEMA = {
  type: 'object',
  required: ['path', 'line', 'claim', 'severity', 'disposition', 'evidence', 'hostPlatformQuote'],
  properties: {
    path: { type: 'string', description: 'repo-relative path, exactly as it appears in the delta list' },
    line: { type: ['integer', 'null'] },
    claim: { type: 'string', description: 'one sentence: the incoherence, stated as a checkable fact' },
    severity: SEVERITY_ENUM,
    disposition: { type: 'string', enum: ['fixable-in-tree', 'out-of-tree'] },
    evidence: { type: 'string', description: 'the quoted line(s) that demonstrate it, and the contradicting source' },
    hostPlatformQuote: {
      type: ['string', 'null'],
      description: 'REQUIRED when the claim rests on what Claude Code itself does: the verbatim upstream sentence with its URL. Otherwise null.',
    },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['status', 'findings'],
  properties: {
    status: { type: 'string', enum: ['reported'] },
    findings: { type: 'array', items: FINDING_SCHEMA },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['real', 'reason', 'severity'],
  properties: {
    real: { type: 'boolean', description: 'true only if the cited line, read this round, demonstrates the claim' },
    reason: { type: 'string' },
    severity: SEVERITY_ENUM,
  },
}

const COMMON_RULES = `
You are a READ-ONLY reviewer in the steer plugin's pre-release audit.
Rules that bind every finding:
- Scope: review ONLY the paths in the delta list below. A defect in a file outside the list is out of scope for the gate -- do not report it.
- Evidence: every finding carries the exact path and line you read THIS round, plus a one-line claim stated as a checkable fact. No line, no finding. Never infer from a filename, a description, or memory.
- Default to silence over speculation. Expect to be verified line by line; a weak finding costs a verifier, so bias toward fewer, real ones.
- Host-platform claims (what Claude Code does with a hook exit code, a timeout, a settings or manifest field): fetch the upstream reference raw (curl -sL <url>.md, then grep) and put the verbatim sentence with its URL in hostPlatformQuote. Our own scripts' comments, our docs, and skill prose are NOT authority for that class of claim. Without a verbatim quote, do not report it.
- A contradiction between two surfaces is a finding about the disagreement; do not decide which side is wrong.
- Severity is a proposal only; it is capped by path afterwards. Disposition is out-of-tree when the fix needs a workflow re-run, an upstream bump, a GitHub setting, or a human decision.
- Return ONLY the structured result. If the dimension is clean, return an empty findings list.
`

function context(ctx) {
  return `
Last release anchor: ${ctx.lastRelease} (plugin.json version ${ctx.pluginVersion})
Delta (${ctx.files.length} paths, git diff --name-only ${ctx.lastRelease}..HEAD${ctx.omittedMirrors ? `, minus ${ctx.omittedMirrors} generated mirror(s) whose sources are listed and whose sync a gate proves` : ''}):
${ctx.files.map((f) => '- ' + f).join('\n')}

Pending changelog fragments (.changes/unreleased/; where only paths are listed, read the files):
${ctx.unreleased}
`
}

// Dimension numbers follow PRE-RELEASE-AUDIT.md. Dimension 2 (version/manifest)
// is deterministic (Step 2) and deliberately absent.
const DIMENSIONS = [
  {
    ruleId: 'changelog-coherence',
    number: 1,
    brief: (ctx) => `Dimension 1 -- CHANGELOG <-> change coherence, both directions.
Compare the pending fragments with the delta under plugins/steer/ (run git diff ${ctx.lastRelease}..HEAD -- plugins/steer/ as needed).
Flag (a) a fragment with no corresponding change in the diff (phantom or overstated entry) and (b) a behaviour-affecting change under plugins/steer/ with no fragment. Do not assume check_changelog.py covered (b): it only asks whether SOME fragment was added.
Also state, in the claim of a single low-severity finding on the offending fragment if and only if it applies, whether its content implies a LARGER semver bump than its declared "kind" (e.g. a renamed skill filed under "Changed") -- the kind is what drives "changie batch auto".`,
  },
  {
    ruleId: 'cross-reference',
    number: 3,
    brief: (ctx) => `Dimension 3 -- cross-reference and inventory integrity, semantic drift only.
For changed skills, rules, and docs: does every /steer:<skill> reference resolve to a skill on disk; does a changed skill's description still describe its body; do the hand-maintained enumerations that name it (CLAUDE.md skills block, README inventory, CROSS-SURFACE.md, docs/reference/*) still agree with what is on disk. scripts/check_standards.py already guards the structural part -- report only what a regex cannot see.`,
  },
  {
    ruleId: 'namespace-brand',
    number: 4,
    brief: (ctx) => `Dimension 4 -- namespace and brand hygiene in the changed files.
No stale /e22-* invocation survives; every invocation is written /steer:<skill>; no org-specific brand or client name leaks into shipped plugins/steer/templates/** (scaffold, spec and reference templates stay client-agnostic).`,
  },
  {
    ruleId: 'payload-placeholder',
    number: 5,
    brief: (ctx) => `Dimension 5 -- payload and placeholder hygiene in the changed files.
No unresolved TODO / FIXME / [Replace placeholder leaks into shipped non-template content under plugins/steer/; every scaffold dotfile stored without its leading dot in templates/scaffold/ has a matching row in templates/scaffold/MANIFEST.md; every path a templates/reference/MIGRATIONS.md entry targets exists. Intentional placeholders carrying a steer:placeholder marker are not findings.`,
  },
  {
    ruleId: 'behavioral-coherence',
    number: 6,
    brief: (ctx) => `Dimension 6 -- behavioural coherence across surfaces, for the changed files.
rules/, skills/, agents/ and templates/ must not contradict each other: a rule asserting X while a changed skill does not-X; an allowed-tools / disallowed-tools boundary a skill's own prose then violates; a hook comment describing behaviour the script below it does not implement. For any claim about what Claude Code itself does, the hostPlatformQuote rule applies.`,
  },
  {
    ruleId: 'docs-accuracy',
    number: '4a',
    agentType: 'documentation-reviewer',
    brief: (ctx) => `Step 4a -- documentation accuracy for this release delta.
Deep-review the docs/ pages that describe the changed plugin surfaces (skills, rules, hooks, agents in the delta list) against the plugin source of truth, plus every docs/ file in the delta itself. Report staleness, coverage gaps, and claims that do not trace back to source. Map your usual grades as: blocker -> high, should-fix -> medium, nit -> low; the path-based ceiling will cap docs pages to low afterwards, which is expected. Use path = the docs page (or the plugin file when the docs are right and the plugin comment is wrong).`,
  },
]

// Mirrors scripts/audit_ledger.py claim_slug so two dimensions describing the
// same defect in different words collapse before verification.
const STOPWORDS = new Set(['the', 'a', 'an', 'is', 'are', 'was', 'were', 'of', 'to', 'in', 'on', 'at', 'and', 'that'])
function slug(claim) {
  const tokens = claim.toLowerCase().match(/[a-z0-9]+/g) || []
  return tokens.filter((t) => !STOPWORDS.has(t) && !/^\d+$/.test(t)).slice(0, 12).join('-')
}

function lower(a, b) {
  return SEVERITIES[Math.max(SEVERITIES.indexOf(a), SEVERITIES.indexOf(b))]
}

const RETRY_NOTE = '\n\n(Second dispatch: the first attempt returned no usable findings list. Return the structured result.)'

async function review(dim, ctx) {
  const prompt = `${COMMON_RULES}\n${dim.brief(ctx)}\n${context(ctx)}`
  const opts = { label: `review:${dim.ruleId}`, phase: 'Review', schema: FINDINGS_SCHEMA }
  if (dim.agentType) opts.agentType = dim.agentType
  let result = await agent(prompt, opts)
  if (!result || !Array.isArray(result.findings)) {
    log(`dimension ${dim.number} (${dim.ruleId}) returned nothing usable -- re-dispatching once`)
    result = await agent(prompt + RETRY_NOTE, { ...opts, label: `review:${dim.ruleId}:retry` })
  }
  const reported = Boolean(result && Array.isArray(result.findings))
  return { dim, reported, findings: reported ? result.findings : [] }
}

// The light tier: a delta small enough for one context gets ONE reviewer that
// works through every dimension, instead of one reviewer each. Coverage is not
// assumed from the dispatch -- the reviewer names the dimensions it completed,
// and one it leaves out is `unverified` exactly as a failed dispatch would be.
async function reviewCombined(dims, ctx) {
  const ruleIds = dims.map((d) => d.ruleId)
  const schema = {
    type: 'object',
    required: ['status', 'covered', 'findings'],
    properties: {
      status: { type: 'string', enum: ['reported'] },
      covered: {
        type: 'array',
        items: { type: 'string', enum: ruleIds },
        description: 'the ruleId of every dimension you checked the delta against; leave one out rather than claim a check you did not make',
      },
      findings: {
        type: 'array',
        items: {
          ...FINDING_SCHEMA,
          required: [...FINDING_SCHEMA.required, 'ruleId'],
          properties: { ...FINDING_SCHEMA.properties, ruleId: { type: 'string', enum: ruleIds } },
        },
      },
    },
  }
  const prompt = `${COMMON_RULES}
This delta is small (${ctx.tierReason || 'light tier'}), so you alone review EVERY dimension below rather than one reviewer taking each. Work through them one at a time against the same delta; a dimension is covered only once you have checked the delta against its brief. Tag each finding with the ruleId of its dimension, and list in "covered" the ruleId of every dimension you completed.

${dims.map((d) => `[ruleId: ${d.ruleId}]\n${d.brief(ctx).trim()}`).join('\n\n')}
${context(ctx)}`
  const opts = { label: 'review:combined', phase: 'Review', schema }
  const usable = (r) => r && Array.isArray(r.findings) && Array.isArray(r.covered)
  let result = await agent(prompt, opts)
  if (!usable(result)) {
    log('combined reviewer returned nothing usable -- re-dispatching once')
    result = await agent(prompt + RETRY_NOTE, { ...opts, label: 'review:combined:retry' })
  }
  return dims.map((dim) => ({
    dim,
    reported: Boolean(usable(result) && result.covered.includes(dim.ruleId)),
    findings: usable(result) ? result.findings.filter((f) => f.ruleId === dim.ruleId) : [],
  }))
}

function verifyPrompt(f) {
  return `You are a READ-ONLY verifier for one pre-release audit finding. Your job is to REFUTE it if you can.
Finding (from dimension ${f.ruleId}):
  path: ${f.path}${f.line ? ':' + f.line : ''}
  claim: ${f.claim}
  evidence offered: ${f.evidence}
  proposed severity: ${f.severity}
${f.hostPlatformQuote ? '  host-platform quote offered: ' + f.hostPlatformQuote : ''}

Open the cited path at the cited line THIS round and read the surrounding context. real=true ONLY if what you read demonstrates the claim as stated. Refute when: the line does not say what the claim says; the pattern is intentional and carries a why-comment; the "contradiction" is two surfaces describing different things; the claim rests on host-platform behaviour and the quote offered is missing, paraphrased, or does not support it (fetch the upstream page raw with curl and grep if you need to). If uncertain, real=false.
You may LOWER the severity (a typo in a hook script is not automatically high); never raise it. Return only the structured verdict.`
}

function reconcilePrompt(rows) {
  return `You are a READ-ONLY verifier re-checking ${rows.length} finding(s) already recorded in the pre-release audit ledger against ${rows[0].path}. That file has changed since they were last confirmed; decide, for EACH one separately, whether its claim STILL holds.
${rows
  .map(
    (row) => `Finding ${row.id} (dimension ${row.ruleId}):
  line: ${row.line || 'unknown'}  (from an earlier tree and may have drifted -- search the file for the subject of the claim)
  claim: ${row.claim}`,
  )
  .join('\n')}

Open ${rows[0].path} THIS round. holds=true ONLY if what the file says now still demonstrates that claim as stated. holds=false when the passage was corrected, removed, or reworded so the contradiction no longer exists, or the file no longer contains the subject of the claim at all. Do not judge whether a finding matters; judge only whether it is still true. If you cannot tell, holds=true (an open row costs nothing; a wrongly closed one hides a defect). Return one verdict per finding id, and only the structured result.`
}

// Rows citing the same file share one verifier (it reads the file once); the
// cap keeps a heavily-cited file from becoming one overloaded prompt.
const RECONCILE_GROUP = 8
function groupByFile(rows) {
  const byPath = new Map()
  for (const row of rows) byPath.set(row.path, [...(byPath.get(row.path) || []), row])
  const groups = []
  for (const sameFile of byPath.values()) {
    for (let i = 0; i < sameFile.length; i += RECONCILE_GROUP) groups.push(sameFile.slice(i, i + RECONCILE_GROUP))
  }
  return groups
}

// ---------------------------------------------------------------------------

const wanted = Array.isArray(args && args.dimensions) && args.dimensions.length
  ? DIMENSIONS.filter((d) => args.dimensions.includes(d.ruleId))
  : DIMENSIONS
if (wanted.length !== DIMENSIONS.length) {
  log(`TRIMMED RUN: ${wanted.length}/${DIMENSIONS.length} dimensions -- this round cannot be the converging round`)
}

// The tier is computed by scripts/release_preflight.py (audit_scope) and only
// ever arrives through args: a run with no args is the full fan-out.
const tier = args && args.tier === 'light' ? 'light' : 'full'

phase('Scout')
let ctx
if (args && args.lastRelease && Array.isArray(args.files) && args.unreleased !== undefined) {
  ctx = {
    lastRelease: args.lastRelease,
    files: args.files,
    unreleased: args.unreleased,
    pluginVersion: args.pluginVersion || 'unknown',
    omittedMirrors: args.omittedMirrors || 0,
    tierReason: args.tierReason,
  }
  log(`scout skipped: caller supplied ${ctx.files.length} delta paths since ${ctx.lastRelease}`)
} else {
  ctx = await agent(
    `From the repository root, gather these facts and return them structured (no commentary):
1. lastRelease: the output of: git describe --tags --match 'v*' --abbrev=0   (if that fails, the SHA of the newest commit whose subject starts with "chore(release):")
2. files: every path from: git diff --name-only <lastRelease>..HEAD
3. unreleased: the full contents of every .changes/unreleased/*.yaml file, verbatim, each preceded by its filename
4. pluginVersion: the "version" field of plugins/steer/.claude-plugin/plugin.json`,
    { label: 'scout:delta', phase: 'Scout', schema: SCOUT_SCHEMA, effort: 'low' },
  )
  if (!ctx) throw new Error('scout returned nothing; cannot bound the audit to the release delta')
}
log(`auditing ${ctx.files.length} changed paths since ${ctx.lastRelease} -- ${tier} tier${ctx.tierReason ? ': ' + ctx.tierReason : ''}`)

// The ledger is only as true as the tree its rows were read against. Rows whose
// file has changed since they were confirmed are re-verified here, so a finding
// the tree has already repaired is closed by the machinery instead of sitting
// `open` until a human notices. Bounded by construction: `open --touched` skips
// every row whose file is byte-identical to its recorded tree sha.
phase('Reconcile')
const ledgerOpen = Array.isArray(args && args.ledgerRows)
  ? { rows: args.ledgerRows }
  : await agent(
      `From the repository root run exactly: uv run python scripts/audit_ledger.py open --touched --json
Return its JSON output structured (no commentary). If the command fails, return { "rows": [] }.`,
      { label: 'scout:ledger', phase: 'Reconcile', schema: LEDGER_OPEN_SCHEMA, effort: 'low' },
    )
const stale = ledgerOpen && Array.isArray(ledgerOpen.rows) ? ledgerOpen.rows : []
const groups = groupByFile(stale)
log(`${stale.length} open ledger row(s) whose file changed since confirmation -- re-verifying across ${groups.length} verifier(s)`)
const rechecked = await pipeline(groups, (group, _item, i) =>
  agent(reconcilePrompt(group), { label: `reconcile:${i + 1}:${group[0].path}`, phase: 'Reconcile', schema: RECONCILE_SCHEMA }),
)
const verdictById = new Map()
for (const result of rechecked.filter(Boolean)) {
  for (const v of Array.isArray(result.verdicts) ? result.verdicts : []) verdictById.set(v.id, v)
}
const reconcile = []
const reconcileUnverified = []
for (const row of stale) {
  const v = verdictById.get(row.id)
  if (!v) reconcileUnverified.push(row.id)
  else reconcile.push({ id: row.id, holds: v.holds, reason: v.reason })
}
log(`reconcile: ${reconcile.filter((v) => !v.holds).length} no longer hold, ${reconcile.filter((v) => v.holds).length} still hold, ${reconcileUnverified.length} unverified (left open)`)

phase('Review')
// Barrier is deliberate: cross-dimension dedupe needs every reviewer's list.
const reviews =
  tier === 'light'
    ? await reviewCombined(wanted, ctx)
    : (await parallel(wanted.map((d) => () => review(d, ctx)))).filter(Boolean)

const coverage = {}
for (const d of wanted) coverage[d.ruleId] = 'unverified'
const raw = []
for (const r of reviews) {
  coverage[r.dim.ruleId] = r.reported ? 'reported' : 'unverified'
  for (const f of r.findings) raw.push({ ...f, ruleId: r.dim.ruleId })
}
const unverifiedDims = Object.keys(coverage).filter((k) => coverage[k] === 'unverified')
if (unverifiedDims.length) log(`[warn] dimension(s) not verified after retry: ${unverifiedDims.join(', ')}`)

const delta = new Set(ctx.files)
const seen = new Map()
const deduped = []
const outOfDelta = []
for (const f of raw) {
  const key = `${f.path}|${slug(f.claim)}`
  if (seen.has(key)) {
    seen.get(key).alsoReportedBy.push(f.ruleId)
    continue
  }
  const row = { ...f, alsoReportedBy: [] }
  seen.set(key, row)
  if (delta.has(f.path)) deduped.push(row)
  else outOfDelta.push(row)
}
log(`${raw.length} raw findings -> ${deduped.length} in-delta to verify, ${outOfDelta.length} out-of-delta (ledger only)`)

phase('Verify')
const verified = await pipeline(deduped, (f) =>
  agent(verifyPrompt(f), { label: `verify:${f.path}`, phase: 'Verify', schema: VERDICT_SCHEMA }).then((v) => ({ finding: f, verdict: v })),
)

const candidates = []
const refuted = []
const unverified = []
for (const item of verified.filter(Boolean)) {
  const { finding, verdict } = item
  if (!verdict) {
    unverified.push(finding)
    continue
  }
  if (!verdict.real) {
    refuted.push({ ...finding, refutedBecause: verdict.reason })
    continue
  }
  candidates.push({
    ruleId: finding.ruleId,
    path: finding.path,
    line: finding.line,
    claim: finding.claim,
    severity: lower(finding.severity, verdict.severity),
    disposition: finding.disposition,
    evidence: finding.evidence,
    hostPlatformQuote: finding.hostPlatformQuote,
    alsoReportedBy: finding.alsoReportedBy,
    verifiedBecause: verdict.reason,
  })
}

const clean =
  candidates.length === 0 &&
  unverified.length === 0 &&
  unverifiedDims.length === 0 &&
  wanted.length === DIMENSIONS.length

return {
  lastRelease: ctx.lastRelease,
  pluginVersion: ctx.pluginVersion,
  deltaFiles: ctx.files.length,
  tier,
  tierReason: ctx.tierReason || null,
  omittedMirrors: ctx.omittedMirrors || 0,
  trimmed: wanted.length !== DIMENSIONS.length,
  coverage,
  clean,
  candidates,
  unverified,
  refuted,
  outOfDelta,
  reconcile,
  reconcileUnverified,
  next: [
    'Write `reconcile` to a JSON file and run: uv run python scripts/audit_ledger.py reconcile --verdicts <file> -- this closes the open rows the tree has already repaired. Do it BEFORE `new`, so a candidate that matches a just-closed row surfaces as a recurrence rather than being carried.',
    'Write `candidates` (plus `unverified`, conservatively) to a JSON file and run: uv run python scripts/audit_ledger.py new --candidates <file>, then record. `new` lists recurrences (a previously fixed row reported again) separately; report them as regressions.',
    'Severity is capped by path when recorded; only release-critical manifests can reach [blocker].',
    'A dimension marked unverified means the round is NOT clean; say so in the report.',
    'State the tier and its reason in the verdict: light means one combined reviewer covered every dimension listed as reported.',
  ],
}
