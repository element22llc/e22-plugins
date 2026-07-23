---
theme: seriph
title: Building software with steer — the SDLC
info: |
  ## The steer SDLC, for clients
  How software gets built on the steer standards — the lifecycle from idea to
  shipped change, what stays human, and what you gain: traceability,
  predictability, and audit-ready records. Written for a mixed audience:
  the big picture in plain language, the machinery in the fine print.
class: text-center
transition: slide-left
mdc: true
# Hash routing (/presentation/sdlc/#/2) keeps every slide inside index.html, so
# the deck works on static subdirectory hosts (GitHub Pages) with no SPA
# fallback — history mode would request /presentation/sdlc/2 and 404 on
# GitHub Pages.
routerMode: hash
fonts:
  sans: Inter
  mono: JetBrains Mono
drawings:
  persist: false
---

# Building software with <span class="accent">steer</span>

## From idea to shipped change — every step on the record

<div class="opacity-70 mt-6 text-xl">

The development lifecycle we run, **why it looks the way it does**, and what you gain from it

</div>

<div class="abs-br m-6 text-sm opacity-50">
press <kbd>Space</kbd> to advance
</div>

<style>
.accent { color: #38bdf8; }
kbd {
  background: rgba(255,255,255,0.1); border-radius: 6px; padding: 2px 8px;
  border: 1px solid rgba(255,255,255,0.2);
}
</style>

<!--
Client-facing deck. Two audiences in the room: non-technical stakeholders who
want to know "how does my idea become working software, and can I trust the
process?", and developers who want to know what the machinery actually does.
Every slide leads with the plain-language point; the technical grounding is in
the cards and fine print.
-->

---
layout: center
class: text-center
---

# How to read this deck

<div class="grid grid-cols-2 gap-8 mt-8 text-left">

<div v-click class="p-6 rounded-xl border border-sky-400/30 bg-sky-400/5">

### 🧭 The big picture
**For everyone**

- How an idea becomes shipped software
- What's written down, and where
- What stays a **human decision**
- What you gain as a client

<div class="text-sm opacity-60 mt-3">No code knowledge needed 👋</div>

</div>

<div v-click class="p-6 rounded-xl border border-emerald-400/30 bg-emerald-400/5">

### ⚙️ The machinery
**For developers**

- The artifacts: specs, contracts, ADRs, issues
- The gates: what blocks, what nudges
- The traceability chain, end to end
- Claude Code **and** GitHub Copilot

</div>

</div>

<div v-click class="mt-8 opacity-70">

Same slides, two depths — headlines for the first lens, fine print for the second.

</div>

---

# The problem worth solving

<div class="text-sm opacity-60 mb-4">AI assistants made writing code cheap. That moved the risk — it didn't remove it.</div>

<div class="grid grid-cols-3 gap-4">

<div v-click class="p-4 rounded-xl border border-rose-400/25 bg-rose-400/5">

### 🌀 Fast, but opaque
Features appear quickly — and six months later **nobody can say why** the app behaves the way it does, or who decided it should.

</div>

<div v-click class="p-4 rounded-xl border border-amber-400/25 bg-amber-400/5">

### 🧠 Knowledge in heads
Requirements live in chat threads and memory. When a person (or a chat session) is gone, **the context is gone**.

</div>

<div v-click class="p-4 rounded-xl border border-violet-400/25 bg-violet-400/5">

### 🎲 Every repo different
Each project invents its own process, tooling and habits — so quality depends on **who happened to build it**.

</div>

</div>

<div v-click class="mt-8 text-center text-xl">

The fix isn't slowing the AI down — it's making the process <span class="accent">durable, traceable and consistent</span> around it.

</div>

<style>.accent { color: #38bdf8; }</style>

<!--
Frame the deck around the real pain: AI-assisted development is fast, and speed
without records creates "vibe-coded" software — it runs, but intent, decisions
and accountability evaporate. steer exists to keep the speed and add the record.
-->

---

# What is steer?

<div class="text-xl mt-6 leading-relaxed">

<v-clicks>

- An **engineering-standards plugin** that rides inside the AI coding assistant.
- It carries a complete **software development life cycle**: the same path from rough idea to shipped, documented change — on **every** project, with **every** developer.
- Installed once per repo. From then on, every AI session works to the same standards **without anyone re-explaining them**.

</v-clicks>

</div>

<div v-click class="mt-10 p-5 rounded-xl border border-emerald-400/30 bg-emerald-400/5 text-lg">

Think of it as **a senior engineer's discipline, always in the room**: agree what to build, track the work, test it, and have a human review it before it ships.

</div>

<div v-click class="mt-4 text-center text-sm opacity-60">

Runs in <b>Claude Code</b> and in <b>GitHub Copilot</b> — same standards, generated from one source of truth. <i>(More on that later.)</i>

</div>

---
layout: center
---

# One rule holds it all together

<div class="grid grid-cols-3 gap-5 mt-8">

<div v-click class="p-5 rounded-xl border border-violet-400/30 bg-violet-400/5 text-center">

### 📐 The spec
is durable **product truth**

<div class="text-sm opacity-60 mt-2">What the software should do and why — written down, in the repo, in plain language.</div>

</div>

<div v-click class="p-5 rounded-xl border border-amber-400/30 bg-amber-400/5 text-center">

### 🎫 The tracker
is the **work & decision layer**

<div class="text-sm opacity-60 mt-2">Every change starts as a tracked issue. Discussion and status live there.</div>

</div>

<div v-click class="p-5 rounded-xl border border-rose-400/30 bg-rose-400/5 text-center">

### 🧑‍⚖️ Human review
is **the gate**

<div class="text-sm opacity-60 mt-2">Nothing merges or deploys without a human developer approving it. Ever.</div>

</div>

</div>

<div v-click class="mt-8 text-center text-lg opacity-80">

Neither layer silently overwrites the other — and the AI **never crosses the review gate on its own**.

</div>

<!--
This is steer's core invariant, verbatim from the docs: "/spec is durable
product truth. The issue tracker is the work/decision layer. The human PR
review is the gate." Everything else in the deck hangs off this slide.
-->

---
layout: center
---

# The lifecycle at a glance

<div class="flex justify-center mt-4">

```mermaid {scale: 0.8}
flowchart LR
    B["0 · Bootstrap<br/><small>set the repo up</small>"] --> S["1 · Shape<br/><small>agree what to build</small>"]
    S --> P["2 · Plan<br/><small>break it into issues</small>"]
    P --> W["3 · Build<br/><small>implement & test</small>"]
    W --> V["4 · Verify<br/><small>human review</small>"]
    V --> D["5 · Deliver<br/><small>merge & deploy</small>"]
    D --> M["6 · Maintain<br/><small>audit & improve</small>"]
    M -.re-enters.-> P
    style B fill:#64748b,color:#fff,stroke:#475569
    style S fill:#8b5cf6,color:#fff,stroke:#7c3aed
    style P fill:#f59e0b,color:#fff,stroke:#d97706
    style W fill:#10b981,color:#fff,stroke:#059669
    style V fill:#ec4899,color:#fff,stroke:#db2777
    style D fill:#22c55e,color:#fff,stroke:#16a34a
    style M fill:#0ea5e9,color:#fff,stroke:#0284c7
```

</div>

<div v-click class="mt-6 text-center text-xl">

Every project walks the **same path**, and every phase ends at a **named gate**.

</div>

<div v-click class="mt-3 text-center text-sm opacity-60">

Devs drive each phase with <code>/steer:</code> commands — <code>spec</code>, <code>issues</code>, <code>work</code>, <code>audit</code>… The next four slides walk the loop.

</div>

---

# 1 · Shape — agree before building

<div class="text-sm opacity-60 mb-3">Working out <i>what</i> and <i>why</i> before any code exists — the cheapest place to change your mind</div>

<div class="grid grid-cols-2 gap-5">

<div v-click class="p-4 rounded-xl border border-sky-400/30 bg-sky-400/5">

### 📄 Intent — <span class="opacity-60 text-base">for product owners</span>
Each feature gets an **intent** document: what it does, why it matters, and how we'll know it's done — **in plain language you can read and approve**.

</div>

<div v-click class="p-4 rounded-xl border border-violet-400/30 bg-violet-400/5">

### 📑 Contract — <span class="opacity-60 text-base">for developers</span>
Behavior, data and error rules precise enough to build and test against. Hard-to-reverse choices get a numbered **decision record (ADR)**.

</div>

<div v-click class="p-4 rounded-xl border border-amber-400/30 bg-amber-400/5">

### ❓ Open questions
Anything unresolved becomes a numbered question with an owner — **visible, not forgotten**. Your answers are captured back into the spec.

</div>

<div v-click class="p-4 rounded-xl border border-emerald-400/30 bg-emerald-400/5">

### 🚦 The gate
The spec can't be **approved** while a blocking question is unanswered. Approval is the owner's sign-off on intent — recorded, dated, in the repo.

</div>

</div>

<div v-click class="mt-4 text-center text-sm opacity-60">

Your Word / PowerPoint / Excel briefs are absorbed directly (<code>/steer:intake</code>) — versioned, diffed against the previous edition, and mapped to open questions.

</div>

<!--
Non-technical takeaway: you can read and approve what will be built, and your
unanswered questions are tracked artifacts — not lost Slack messages.
Technical: intent.md + contract.md per feature, ADRs under /spec/decisions/,
Q-NNN open questions, /steer:spec approve is blocked on blocking questions.
-->

---

# 2 · Plan &nbsp;→&nbsp; 3 · Build

<div class="grid grid-cols-2 gap-6 mt-4">

<div v-click class="p-5 rounded-xl border border-amber-400/30 bg-amber-400/5">

### 🎫 Plan — issue-first
The approved spec is decomposed into **tracked issues** — triaged, sized, prioritized.

**The rule: no change without an issue.** Every modification traces back to a ticket *before* the first line changes — enforced by a session gate, not just good intentions.

<div class="text-sm opacity-60 mt-3">Tracker-agnostic: GitHub Issues, Jira, Linear or Azure DevOps — one file in the repo declares which, everything else adapts.</div>

</div>

<div v-click class="p-5 rounded-xl border border-emerald-400/30 bg-emerald-400/5">

### ⚙️ Build — one issue, end to end
The AI claims the issue, branches, loads the linked spec, implements, **writes the tests**, and opens the pull request — updating the issue as it goes.

**Autonomy where it's safe:** commits, pushes and opening the PR are autonomous. **Merge and deploy are never implied.**

<div class="text-sm opacity-60 mt-3">Optional <code>--reviewed</code> mode adds independent plan- and code-review passes by a separate read-only reviewer agent <i>before</i> the PR.</div>

</div>

</div>

<div v-click class="mt-5 text-center text-lg">

Speed comes from autonomy on the safe steps — <span class="accent">not from skipping the record</span>.

</div>

<style>.accent { color: #38bdf8; }</style>

<!--
Plan: /steer:issues — capture → triage → decompose; issue-first is enforced by
a PreToolUse/Stop gate in Claude Code. Build: /steer:work — claim, branch,
implement, test, PR; steer-reviewer subagent on --reviewed. The autonomy
boundary is the key message for both audiences.
-->

---

# 4 · Verify — the human gate

<div class="text-sm opacity-60 mb-3">"Review <i>is</i> productionization" — the one gate no AI crosses</div>

<div class="grid grid-cols-2 gap-6">

<div v-click class="p-5 rounded-xl border border-sky-400/30 bg-sky-400/5">

### ✅ Definition of Done
A PR isn't reviewable until it clears the checklist: **tests cover what changed**, docs updated, CI green, spec kept in sync — the same bar on every project.

</div>

<div v-click class="p-5 rounded-xl border border-rose-400/30 bg-rose-400/5">

### 🚩 Drift gates
Nine classes of sensitive change — intent drift, contract drift, security-sensitive, compliance-impacting, … — are **flagged in the PR** the moment they're noticed.

A raised flag **blocks merge** until the human reviewer resolves it — and the AI **may not waive its own flag**.

</div>

</div>

<div v-click class="mt-6 p-4 rounded-xl border border-emerald-400/30 bg-emerald-400/5 text-center text-lg">

A human developer approves every pull request. That's not a formality — it's **the** quality gate the whole lifecycle is built around.

</div>

<!--
Drift gate classes (rule 55): intent drift, contract drift, undocumented
behavior change, security-sensitive, compliance-impacting, operational, local
setup changed, app docs invalidated, architecture/stack drift. The "can't waive
its own flag" rule is the honest differentiator — worth saying out loud.
-->

---

# 5 · Deliver &nbsp;·&nbsp; 6 · Maintain

<div class="grid grid-cols-2 gap-6 mt-4">

<div v-click class="p-5 rounded-xl border border-emerald-400/30 bg-emerald-400/5">

### 🚀 Deliver
Merge → deploy, behind **enforced branch protection**: no direct pushes to main, production deploys gated by a reviewed PR.

<div class="text-sm opacity-60 mt-3">Early-stage projects can run a lighter solo mode — with CI backstops, and automatic nudges to graduate to full PR flow once a deploy target or second contributor appears.</div>

</div>

<div v-click class="p-5 rounded-xl border border-sky-400/30 bg-sky-400/5">

### 🔍 Maintain
Scheduled **read-only audits** sweep the codebase against the standards and check the built software still matches the spec — findings are **filed as ranked issues**, never silently fixed.

<div class="text-sm opacity-60 mt-3">Plus: <code>/steer:status</code> renders a shareable, client-ready progress report straight from the record — real counts, no fabricated status.</div>

</div>

</div>

<div v-click class="mt-6 text-center text-lg">

Findings feed back into **Plan** — the loop closes instead of decaying.

</div>

<!--
Deliver: /steer:protect, prod-branch gating (rule 52), solo-trunk graduation.
Maintain: /steer:audit code/spec (read-only, files findings), /steer:next,
/steer:status (artifact report). Production incidents have a sanctioned
fast-path (work --hotfix) that relaxes ordering but keeps every human gate and
requires post-incident backfill — mention verbally if asked about emergencies.
-->

---
layout: center
---

# The thread you can pull, months later

<div class="flex justify-center mt-2">

```mermaid {scale: 0.75}
flowchart LR
    I["💡 idea"] --> IN["📄 intent<br/><small>what & why</small>"]
    IN --> C["📑 contract<br/><small>exact behavior</small>"]
    C --> T["🎫 issue<br/><small>the work</small>"]
    T --> PR["🔀 pull request<br/><small>the change + review</small>"]
    PR --> H["📜 HISTORY<br/><small>the permanent log</small>"]
    style I fill:#0ea5e9,color:#fff,stroke:#0284c7
    style IN fill:#8b5cf6,color:#fff,stroke:#7c3aed
    style C fill:#a855f7,color:#fff,stroke:#9333ea
    style T fill:#f59e0b,color:#fff,stroke:#d97706
    style PR fill:#ec4899,color:#fff,stroke:#db2777
    style H fill:#22c55e,color:#fff,stroke:#16a34a
```

</div>

<div v-click class="mt-6 text-center text-xl max-w-4xl mx-auto leading-relaxed">

Ask *"why does the app do this?"* about **any behavior, at any time** —
and walk from the answer back to the decision, the discussion and the person who approved it.

</div>

<div v-click class="mt-5 text-center text-sm opacity-60">

Documentation is written **in the same PR as the change** — extract-don't-embellish — so the record never lags the code.
Every merged change appends one entry to an append-only <code>HISTORY.md</code>: what, why, who, references.

</div>

<!--
This is the traceability chain from TRACEABILITY.md: intent → contract →
tracker ref → implementation → PR review → HISTORY. The "living docs" rule
means the artifacts update in the same PR, not in a doc sprint later. New
joiner onboarding: read the last quarter of HISTORY.md in five minutes.
-->

---

# What stays human — always

<div class="text-sm opacity-60 mb-4">The AI proposes, drafts, flags and files. These decisions it <b>never</b> takes:</div>

<div class="grid grid-cols-2 gap-4">

<div v-click class="p-4 rounded-xl border border-rose-400/40 bg-rose-400/5 flex gap-4 items-start">
<div class="text-3xl">🔀</div>
<div><b>Merging a pull request</b> — pushing a branch and opening the PR are autonomous; <b>approving and merging is a human developer's call</b>.</div>
</div>

<div v-click class="p-4 rounded-xl border border-rose-400/40 bg-rose-400/5 flex gap-4 items-start">
<div class="text-3xl">🚀</div>
<div><b>Deploying</b> — releases to any environment are decided by people, gated by branch protection.</div>
</div>

<div v-click class="p-4 rounded-xl border border-rose-400/40 bg-rose-400/5 flex gap-4 items-start">
<div class="text-3xl">⚖️</div>
<div><b>Ratifying decisions</b> — an architecture decision stays <i>Proposed</i> until a human accepts it.</div>
</div>

<div v-click class="p-4 rounded-xl border border-rose-400/40 bg-rose-400/5 flex gap-4 items-start">
<div class="text-3xl">🔑</div>
<div><b>Secrets & settings</b> — real credentials and repository security settings are never written by the AI.</div>
</div>

</div>

<div v-click class="mt-6 text-center text-lg">

That pause at the PR isn't friction — it's the **design**. Accountability stays with people.

</div>

<!--
From the authorization model / rule 95-not-the-gate. This is the slide that
answers the unspoken client question: "so the AI just does whatever it wants?"
No — four hard human gates, by construction.
-->

---

# What you gain — as a client

<div class="grid grid-cols-2 gap-5 mt-4">

<div v-click class="p-4 rounded-xl border border-sky-400/30 bg-sky-400/5">

### 👀 Visibility, on demand
Progress reports generated **from the record** — real issue states, real PR status. Specs you can read; open questions with your name on them.

</div>

<div v-click class="p-4 rounded-xl border border-violet-400/30 bg-violet-400/5">

### 🧾 Audit-ready by construction
The everyday artifacts double as evidence: an append-only change log, decision records with status, reviewed PRs as the production gate. Practices **aligned with SOC 2 / ISO 27001 expectations** — produced as a side effect of working, not a scramble before an audit.

</div>

<div v-click class="p-4 rounded-xl border border-emerald-400/30 bg-emerald-400/5">

### 🔓 No lock-in to heads
Any developer — yours or ours — can open the repo and reconstruct intent, decisions and history **without archaeology**. Reading the last quarter of the change log takes five minutes.

</div>

<div v-click class="p-4 rounded-xl border border-amber-400/30 bg-amber-400/5">

### 📏 Predictability
Every repo has the same shape, the same gates, the same definition of done — so quality doesn't depend on **who** built it or **which week** it was built in.

</div>

</div>

<!--
Careful wording on compliance (from TRACEABILITY.md): "aligned", never
"compliant" — steer produces evidence and practices; certification is an
organizational scope. If asked directly: the artifacts map cleanly to SOC 2
change-management evidence requests, but no tool makes you compliant.
-->

---

# What you gain — as a developer

<div class="grid grid-cols-3 gap-4 mt-4">

<div v-click class="p-4 rounded-xl border border-sky-400/25 bg-sky-400/5">

### 📦 A repo that arrives ready
Bootstrap installs the full scaffold: pinned toolchain (mise), CI workflows, compose file, PR template — **identical across projects**.

</div>

<div v-click class="p-4 rounded-xl border border-violet-400/25 bg-violet-400/5">

### 🧠 Context that survives
Specs, decisions and work state live in **files, not chat memory** — a new session (or a new dev) picks up exactly where the last one left off.

</div>

<div v-click class="p-4 rounded-xl border border-emerald-400/25 bg-emerald-400/5">

### 🛡️ Guardrails, not bureaucracy
Ceremony scales with risk: small changes flow, high-risk changes get flagged. The gates that block are few, named, and there for a reason.

</div>

<div v-click class="p-4 rounded-xl border border-amber-400/25 bg-amber-400/5">

### 🔍 An independent reviewer
A read-only reviewer agent examines plans and diffs in an **isolated context** — findings must cite file-and-line evidence. No evidence, no finding.

</div>

<div v-click class="p-4 rounded-xl border border-rose-400/25 bg-rose-400/5">

### 🧭 Never lost
<code>/steer:next</code> reconstructs the workspace state cold and points at the single best next action. <code>/steer:help</code> browses everything.

</div>

<div v-click class="p-4 rounded-xl border border-cyan-400/25 bg-cyan-400/5">

### ♻️ Standards that update
One plugin version, all repos: <code>/steer:sync</code> reconciles a repo against the latest standards and opens the update as a normal, reviewable PR.

</div>

</div>

---

# Works where you work

<div class="text-sm opacity-60 mb-3">One source of truth, two assistants — the standards are <b>generated</b>, not maintained twice</div>

<div class="grid grid-cols-2 gap-6">

<div v-click class="p-5 rounded-xl border border-sky-400/30 bg-sky-400/5">

### 🤖 Claude Code
The full engine: always-on rules injected every session, live gates at the moment of action, the reviewer agent, tracker integration.

<div class="text-sm opacity-60 mt-2">CLI, IDE extension, or the Desktop Code tab.</div>

</div>

<div v-click class="p-5 rounded-xl border border-violet-400/30 bg-violet-400/5">

### 🐙 GitHub Copilot
The same standards, **generated into Copilot's native formats** and committed to the repo:

- <code>.github/copilot-instructions.md</code> — the full ruleset
- <code>.github/prompts/steer-*.prompt.md</code> — the workflows
- <code>.github/agents/</code> — the reviewer agent

<div class="text-sm opacity-60 mt-2">Regenerated from the same source on every release — parity by build, not by hand.</div>

</div>

</div>

<div v-click class="mt-5 text-center text-lg">

Your developers keep their tools. The **process and the record are identical** either way —
because the spec, the tracker and the PR gate live in the repo, not in the assistant.

</div>

<!--
Grounded in CROSS-SURFACE.md: rules → generated copilot-instructions.md;
skills → prompt capsules; reviewer agent ported; two gate scripts dual-target
(Copilot CLI). Honest nuance if asked: Copilot is best-effort tier — content
parity yes, but the live hook gates only exist on Copilot CLI, not VS Code.
The durable artifacts (spec/tracker/PR) are assistant-independent, which is
the real portability argument.
-->

---

# A change, end to end

<div class="text-sm opacity-60 mb-3">What "add CSV export" actually looks like on the record</div>

<div class="timeline text-base">

<div v-click class="flex gap-3 items-start p-2.5 rounded-lg border border-white/10 bg-white/5">
<div class="w-40 shrink-0 opacity-60">You ask</div>
<div>"Our analysts need to export results as CSV" — said in a meeting, or sent as a document.</div>
</div>

<div v-click class="flex gap-3 items-start p-2.5 rounded-lg border border-violet-400/20 bg-violet-400/5">
<div class="w-40 shrink-0 opacity-60">Shape</div>
<div>An <b>intent</b> is drafted for you to read; the contract pins the details. One open question — <i>"which columns?"</i> — is assigned to you. You answer; the spec is <b>approved</b>.</div>
</div>

<div v-click class="flex gap-3 items-start p-2.5 rounded-lg border border-amber-400/20 bg-amber-400/5">
<div class="w-40 shrink-0 opacity-60">Plan</div>
<div>Issue <b>#142 — CSV export</b> is filed, linking back to the spec.</div>
</div>

<div v-click class="flex gap-3 items-start p-2.5 rounded-lg border border-emerald-400/20 bg-emerald-400/5">
<div class="w-40 shrink-0 opacity-60">Build</div>
<div>The AI implements on branch <code>issue/142-csv-export</code>, writes the tests, updates the user docs, opens <b>PR #143</b> — and stops.</div>
</div>

<div v-click class="flex gap-3 items-start p-2.5 rounded-lg border border-rose-400/20 bg-rose-400/5">
<div class="w-40 shrink-0 opacity-60">Verify · Deliver</div>
<div>A developer reviews and merges; the change deploys through the protected branch. <code>HISTORY.md</code> gains one line: <i>what, why, who, refs #142/#143</i>.</div>
</div>

<div v-click class="flex gap-3 items-start p-2.5 rounded-lg border border-sky-400/20 bg-sky-400/5">
<div class="w-40 shrink-0 opacity-60">A year later</div>
<div>Someone asks <i>"why does the export quote every field?"</i> — the contract says why, and the trail leads back to your answer on the open question.</div>
</div>

</div>

<style>.timeline > div + div { margin-top: 0.45rem; }</style>

<!--
The concrete walk-through that makes the abstractions land. Every artifact
named here is real: intent/contract, Q-NNN answer captured, issue-first,
issue/<n>-<slug> branch, PR + human merge, HISTORY.md entry.
-->

---

# Starting a project — three doors in

<div class="grid grid-cols-3 gap-4 mt-6">

<div v-click class="p-4 rounded-xl border border-sky-400/30 bg-sky-400/5">

### 🌱 New build
A greenfield repo is bootstrapped **standards-compliant from commit one** — scaffold, CI, spec spine all installed before the first feature.

</div>

<div v-click class="p-4 rounded-xl border border-violet-400/30 bg-violet-400/5">

### 🏗️ Existing codebase
Adoption reverse-engineers the spec **from the code you already have**, triages what to keep / refactor / rewrite, and adds the standards without flattening working software.

</div>

<div v-click class="p-4 rounded-xl border border-emerald-400/30 bg-emerald-400/5">

### 💡 Just an idea
Non-technical owners start from a **guided interview** — idea → spec → working prototype — then hand off to a developer for the review lane. No tooling knowledge needed.

</div>

</div>

<div v-click class="mt-8 text-center text-lg opacity-80">

Prototype-fast **or** production-grade isn't a fork in the road here — the prototype is already on the rails that lead to production.

</div>

<!--
init / adopt / build. The closing line is the differentiator: /steer:build
output lands with a spec spine and tracker, so "productionizing the prototype"
is a review, not a rewrite. adopt's Keep/Refactor/Rewrite/Reject triage lands
in PRODUCTIONIZATION.md.
-->

---
layout: center
class: text-center
---

# In one line

<div class="text-3xl mt-10 leading-relaxed max-w-4xl mx-auto">

AI speed, with <span class="accent">every decision on the record</span> —
and a human hand on every gate that matters.

</div>

<div v-click class="mt-12 grid grid-cols-3 gap-6 max-w-4xl mx-auto text-left text-base">

<div class="p-4 rounded-xl border border-violet-400/30 bg-violet-400/5">
<b>Traceable</b> — idea to shipped change, one walkable thread.
</div>

<div class="p-4 rounded-xl border border-amber-400/30 bg-amber-400/5">
<b>Consistent</b> — same lifecycle, gates and quality bar on every repo.
</div>

<div class="p-4 rounded-xl border border-emerald-400/30 bg-emerald-400/5">
<b>Accountable</b> — humans approve; the record proves it.
</div>

</div>

<style>.accent { color: #38bdf8; }</style>

---
layout: center
class: text-center
---

# Thank you

<div class="text-xl opacity-70 mt-6 leading-relaxed">

Full documentation, workflows and reference:

</div>

<div class="mt-6 text-2xl">

**<https://ai.element-22.com>**

</div>

<div class="mt-10 flex justify-center gap-4 text-lg">

<div class="px-5 py-3 rounded-xl border border-sky-400/40 bg-sky-400/5">
Product owner? → bring an idea, we'll shape it together
</div>
<div class="px-5 py-3 rounded-xl border border-emerald-400/40 bg-emerald-400/5">
Developer? → the docs walk every workflow
</div>

</div>

<div class="mt-12 text-2xl">

Questions? 🙋

</div>
