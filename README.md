# e22-plugins

Element 22's plugin marketplace for Claude Code, Claude Chat, and Claude
Cowork — the AI-native collaborative workflow **from local MVP to governed
production**.

> Let the PO explore locally. Let Claude extract the meaning. Let
> engineering decide what becomes production.

This repository is a [Claude Code plugin
marketplace](https://code.claude.com/docs/en/plugin-marketplaces). Installing
it on a workspace gives the team:

- **Three zones**, one workflow: a **Local MVP Sandbox** for Product Owners
  to explore brand-new MVPs without commands or governance overhead; a
  **Handoff / Extraction** zone built around a single `HANDOFF.md`; a
  **Governed Production** zone where the normal engineering controls apply.
- **An always-on organization plugin** (`e22-org`) — the PO's only required
  installation. Provides plain-language affordances, the natural-language
  handoff trigger, sandbox guardrails, and a shared zone detector.
- **Seven plugins** covering both zones. Update a plugin once, every Claude
  session picks it up tomorrow.

The marketplace works on all three Claude surfaces:

- **Claude Chat** — web/mobile, where most POs will start their MVPs.
- **Claude Cowork** — the desktop tool for file and task automation.
- **Claude Code** — the terminal coding agent, where hooks are hard
  controls.

Plugins behave identically across surfaces with one caveat: hooks fire only
where the surface supports them (Claude Code today). On Chat / Cowork the
same rules apply as instructions in always-loaded `CLAUDE.md` files. The
sandbox is safe for instruction-only enforcement because it cannot deploy
to production, use real customer data, or access production credentials.

## The arc of a change

```text
Local MVP Sandbox   →    Handoff / Extraction   →    Governed Production
PO explores              HANDOFF.md generated          PR / CI / review / approval
naturally, fake          from chat + workspace         Dev decides Harden /
data, no commands        evidence; 15 sections;        Extract / Rewrite /
                         5 mandatory                    Reject / Continue
```

Speed lives on the left. Safety lives on the right. The handoff packet is
the bridge.

## Zones and ownership

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, disposable previews | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md` at workspace root | Dev reviews the packet before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

Zone detection is shared logic in `plugins/e22-org/lib/zone.sh`. A workspace
is **governed** when it is a git repo with an `origin` remote pointing at
GitHub. Otherwise it is **sandbox**.

## The seven plugins

### Always-on (install for PO bundle and Dev bundle)

| Plugin | What it does |
|---|---|
| [`e22-org`](./plugins/e22-org) | The always-on org plugin. Always-loaded `CLAUDE.md` baseline, sandbox guardrails (PII / prod-DB connection strings), natural-language handoff trigger, the shared zone-detection helper. The PO's only required installation. |
| [`security-rails`](./plugins/security-rails) | Universal hard guardrails in both zones — secrets, AWS keys, Stripe live keys, raw-SQL interpolation, force-push, push-to-main. |
| [`handoff-packager`](./plugins/handoff-packager) | Per-section guidance for filling `HANDOFF.md` when the handoff trigger fires. Single-file output (spec v0.4 §7.2). No slash command. |
| [`house-style`](./plugins/house-style) | Always-loaded tech-stack and latest-stable-version guidance in both zones; lint/format PostToolUse hook gated to the governed zone. |

### Production (install for Dev bundle only)

| Plugin | What it does |
|---|---|
| [`always-test`](./plugins/always-test) | Test-floor enforcement in governed repos. Zone-gated — silent in sandbox; exit-2 on PostToolUse miss and Stop-continue on session end when governed. |
| [`spine-writer`](./plugins/spine-writer) | Product Spine generation. Zone-gated PostToolUse nudge. `/spine-refresh` refuses in sandbox. |
| [`production-lane`](./plugins/production-lane) | `/validate` (Harden / Extract / Rewrite / Reject / Continue exploring), `/propose`, `/from-design`, `/promote`. Auto-trigger skills route Dev intent to the right command. SOC2 governance overlay applies. |

## Install

### PO bundle (sandbox-safe four)

```bash
claude plugin marketplace add element22llc/e22-plugins
claude plugin install e22-org@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install handoff-packager@e22-plugins
claude plugin install house-style@e22-plugins
```

### Dev bundle (all seven)

```bash
claude plugin marketplace add element22llc/e22-plugins
claude plugin install e22-org@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install handoff-packager@e22-plugins
claude plugin install house-style@e22-plugins
claude plugin install always-test@e22-plugins
claude plugin install spine-writer@e22-plugins
claude plugin install production-lane@e22-plugins
```

POs may also install the full Dev bundle without issue — the three
production plugins are silent in the sandbox.

## The PO experience

1. Install the PO bundle.
2. Open Claude on any supported surface. Say: *"Build me an MVP for a
   restaurant reservations app."*
3. Iterate naturally: *"add a waitlist feature"*, *"try a different
   checkout"*, *"show me three variants of the homepage."*
4. When you're done, say: *"handoff this to dev"* or *"package this for
   engineering"* or *"I'm done with the MVP."*
5. Claude writes `HANDOFF.md` at your workspace root. Send the file (and
   any screenshots in `assets/`) to your engineering counterpart.

There are no commands to remember. There is no GitHub setup. There is no
Product Spine to maintain. The handoff is what Dev reads first.

## The Dev experience

When you receive `HANDOFF.md`:

1. Open `/validate` (or just say *"let's review the handoff for X"* — the
   `validation-decision` skill auto-fires).
2. Make one of five decisions: **Harden / Extract / Rewrite / Reject /
   Continue exploring** (spec v0.4 §7.4). For brand-new MVPs the default is
   Extract or Rewrite; Harden requires you to accept ownership of the
   prototype's technical choices.
3. If Harden or Extract: import the relevant source into a governed repo
   and run `/propose`.
4. If Rewrite: open a fresh PR off `main`; use `HANDOFF.md` as the spec.
5. If Reject: respond with reasoning grounded in `HANDOFF.md §15` so the
   PO knows what would change the decision.
6. If Continue exploring: reply with what specifically is unclear or
   unfinished — usually tied to `HANDOFF.md §13` (open questions) and §8
   (risks).

Once you accept the work, normal engineering rules apply: PR, CI, review,
approval, rollback path, secret scanning, branch protection, CODEOWNERS,
sensitive-area review.

## Where to learn more

- [`CONSTITUTION.md`](./CONSTITUTION.md) — always-loaded baseline for every
  Claude session in this org.
- [`docs/collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md)
  — the full operational spec (v0.4).
- [`TECH-STACK.md`](./TECH-STACK.md) — preferred languages and tooling.
- [`CONNECTORS.md`](./CONNECTORS.md) — connector requirements per zone.
- [`PRODUCT_SPINE_TEMPLATE.md`](./PRODUCT_SPINE_TEMPLATE.md) — the
  durable-spec template, used after the work is imported into a governed
  repo.
- [`MARKETPLACE_VALIDATION.md`](./MARKETPLACE_VALIDATION.md) — marketplace
  conformance and version baselines.

## Versions

| Plugin | Version |
|---|---|
| `e22-org` | 0.1.0 |
| `security-rails` | 0.2.1 |
| `handoff-packager` | 0.2.0 |
| `house-style` | 0.2.0 |
| `always-test` | 0.3.0 |
| `spine-writer` | 0.2.0 |
| `production-lane` | 0.3.0 |
