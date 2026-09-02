export const meta = {
  name: 'pre-release-audit',
  description:
    'Judgment half of the steer pre-release audit: delta-scoped coherence reviewers plus the docs reviewer, then one verifier per finding, returned as ledger-ready candidates',
  whenToUse:
    'Invoked by /release Phase A and by /audit-loop each round for PRE-RELEASE-AUDIT.md Steps 3 and 4a. Pass { lastRelease } to skip the scout. Pass { dimensions: [...] } only for a non-final /audit-loop round that is allowed to trim.',
  phases: [
    { title: 'Scout', detail: 'resolve $LAST_RELEASE and the delta file list' },
    { title: 'Review', detail: 'one read-only reviewer per dimension, scoped to the delta; a failed dispatch is retried once' },
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
    unreleased: { type: 'string', description: 'the ### [Unreleased] bullets under ## steer in CHANGELOG.md, verbatim' },
    pluginVersion: { type: 'string' },
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
You are a READ-ONLY reviewer for one dimension of the steer plugin's pre-release audit.
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
Delta (${ctx.files.length} paths, git diff --name-only ${ctx.lastRelease}..HEAD):
${ctx.files.map((f) => '- ' + f).join('\n')}

### [Unreleased] bullets:
${ctx.unreleased}
`
}

// Dimension numbers follow PRE-RELEASE-AUDIT.md. Dimension 2 (version/manifest)
// is deterministic (Step 2) and deliberately absent.
const DIMENSIONS = [
  {
    ruleId: 'changelog-coherence',
    number: 1,
    prompt: (ctx) => `${COMMON_RULES}
Dimension 1 -- CHANGELOG <-> change coherence, both directions.
Compare the [Unreleased] bullets with the delta under plugins/steer/ (run git diff ${ctx.lastRelease}..HEAD -- plugins/steer/ as needed).
Flag (a) a bullet with no corresponding change in the diff (phantom or overstated entry) and (b) a behaviour-affecting change under plugins/steer/ with no bullet. Do not assume check_changelog.py covered (b): it only asks whether CHANGELOG.md is in the changed set.
Also state, in the claim of a single low-severity finding on CHANGELOG.md if and only if it applies, whether the highest-impact bullet implies a LARGER semver bump than a naive reading (e.g. a renamed skill hidden in a "Changed" bullet).
${context(ctx)}`,
  },
  {
    ruleId: 'cross-reference',
    number: 3,
    prompt: (ctx) => `${COMMON_RULES}
Dimension 3 -- cross-reference and inventory integrity, semantic drift only.
For changed skills, rules, and docs: does every /steer:<skill> reference resolve to a skill on disk; does a changed skill's description still describe its body; do the hand-maintained enumerations that name it (CLAUDE.md skills block, README inventory, CROSS-SURFACE.md, docs/reference/*) still agree with what is on disk. scripts/check_standards.py already guards the structural part -- report only what a regex cannot see.
${context(ctx)}`,
  },
  {
    ruleId: 'namespace-brand',
    number: 4,
    prompt: (ctx) => `${COMMON_RULES}
Dimension 4 -- namespace and brand hygiene in the changed files.
No stale /e22-* invocation survives; every invocation is written /steer:<skill>; no org-specific brand or client name leaks into shipped plugins/steer/templates/** (scaffold, spec and reference templates stay client-agnostic).
${context(ctx)}`,
  },
  {
    ruleId: 'payload-placeholder',
    number: 5,
    prompt: (ctx) => `${COMMON_RULES}
Dimension 5 -- payload and placeholder hygiene in the changed files.
No unresolved TODO / FIXME / [Replace placeholder leaks into shipped non-template content under plugins/steer/; every scaffold dotfile stored without its leading dot in templates/scaffold/ has a matching row in templates/scaffold/MANIFEST.md; every path a templates/reference/MIGRATIONS.md entry targets exists. Intentional placeholders carrying a steer:placeholder marker are not findings.
${context(ctx)}`,
  },
  {
    ruleId: 'behavioral-coherence',
    number: 6,
    prompt: (ctx) => `${COMMON_RULES}
Dimension 6 -- behavioural coherence across surfaces, for the changed files.
rules/, skills/, agents/ and templates/ must not contradict each other: a rule asserting X while a changed skill does not-X; an allowed-tools / disallowed-tools boundary a skill's own prose then violates; a hook comment describing behaviour the script below it does not implement. For any claim about what Claude Code itself does, the hostPlatformQuote rule applies.
${context(ctx)}`,
  },
  {
    ruleId: 'docs-accuracy',
    number: '4a',
    agentType: 'documentation-reviewer',
    prompt: (ctx) => `${COMMON_RULES}
Step 4a -- documentation accuracy for this release delta.
Deep-review the docs/ pages that describe the changed plugin surfaces (skills, rules, hooks, agents in the delta list) against the plugin source of truth, plus every docs/ file in the delta itself. Report staleness, coverage gaps, and claims that do not trace back to source. Map your usual grades as: blocker -> high, should-fix -> medium, nit -> low; the path-based ceiling will cap docs pages to low afterwards, which is expected. Use path = the docs page (or the plugin file when the docs are right and the plugin comment is wrong).
${context(ctx)}`,
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

async function review(dim, ctx) {
  const opts = { label: `review:${dim.ruleId}`, phase: 'Review', schema: FINDINGS_SCHEMA }
  if (dim.agentType) opts.agentType = dim.agentType
  let result = await agent(dim.prompt(ctx), opts)
  if (!result || !Array.isArray(result.findings)) {
    log(`dimension ${dim.number} (${dim.ruleId}) returned nothing usable -- re-dispatching once`)
    result = await agent(
      dim.prompt(ctx) + '\n\n(Second dispatch: the first attempt returned no usable findings list. Return the structured result.)',
      { ...opts, label: `review:${dim.ruleId}:retry` },
    )
  }
  return { dim, result: result && Array.isArray(result.findings) ? result : null }
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

// ---------------------------------------------------------------------------

const wanted = Array.isArray(args && args.dimensions) && args.dimensions.length
  ? DIMENSIONS.filter((d) => args.dimensions.includes(d.ruleId))
  : DIMENSIONS
if (wanted.length !== DIMENSIONS.length) {
  log(`TRIMMED RUN: ${wanted.length}/${DIMENSIONS.length} dimensions -- this round cannot be the converging round`)
}

phase('Scout')
let ctx
if (args && args.lastRelease && Array.isArray(args.files) && args.unreleased !== undefined) {
  ctx = { lastRelease: args.lastRelease, files: args.files, unreleased: args.unreleased, pluginVersion: args.pluginVersion || 'unknown' }
  log(`scout skipped: caller supplied ${ctx.files.length} delta paths since ${ctx.lastRelease}`)
} else {
  ctx = await agent(
    `From the repository root, gather these facts and return them structured (no commentary):
1. lastRelease: the output of: git describe --tags --match 'v*' --abbrev=0   (if that fails, the SHA of the newest commit whose subject starts with "chore(release):")
2. files: every path from: git diff --name-only <lastRelease>..HEAD
3. unreleased: the bullet lines under the FIRST "### [Unreleased]" heading beneath "## steer" in CHANGELOG.md, verbatim, up to the next "### " heading
4. pluginVersion: the "version" field of plugins/steer/.claude-plugin/plugin.json`,
    { label: 'scout:delta', phase: 'Scout', schema: SCOUT_SCHEMA, effort: 'low' },
  )
  if (!ctx) throw new Error('scout returned nothing; cannot bound the audit to the release delta')
}
log(`auditing ${ctx.files.length} changed paths since ${ctx.lastRelease}`)

// Barrier is deliberate: cross-dimension dedupe needs every reviewer's list.
const reviews = (await parallel(wanted.map((d) => () => review(d, ctx)))).filter(Boolean)

const coverage = {}
for (const d of wanted) coverage[d.ruleId] = 'unverified'
const raw = []
for (const r of reviews) {
  coverage[r.dim.ruleId] = r.result ? 'reported' : 'unverified'
  if (!r.result) continue
  for (const f of r.result.findings) raw.push({ ...f, ruleId: r.dim.ruleId })
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
  trimmed: wanted.length !== DIMENSIONS.length,
  coverage,
  clean,
  candidates,
  unverified,
  refuted,
  outOfDelta,
  next: [
    'Write `candidates` (plus `unverified`, conservatively) to a JSON file and run: uv run python scripts/audit_ledger.py new --candidates <file>, then record.',
    'Severity is capped by path when recorded; only release-critical manifests can reach [blocker].',
    'A dimension marked unverified means the round is NOT clean; say so in the report.',
  ],
}
