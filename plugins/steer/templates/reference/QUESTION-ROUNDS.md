# Question rounds - how steer interviews a human

Read this before the first question of any interview a skill runs: the
`/steer:spec` brainstorm and its ADR stress test, the `/steer:questions` walk,
the `/steer:build` and `/steer:setup` interviews, `/steer:setup adopt`'s
confirmation pass, and `/steer:work issues brainstorm`. The skill decides *what*
to ask and where answers land; this file decides *how* to ask, and where a
resolved term lands. Adapted from the interview mechanics of Matt Pocock's
`grilling` and `domain-modeling` skills.

## Rounds

- **A round is every question you can ask now** - those whose prerequisites are
  already settled - numbered, in one message. A question whose answer depends on
  another still open this round waits for the next one. After each round,
  recompute what the answers unblocked.
- **Look facts up yourself** - the code, the existing spine, the git remote, the
  scaffold defaults. Ask the human only for decisions. A fact you are still
  looking up holds back only the questions that depend on it.
- **Stop when the rounds run dry** - nothing answerable left unasked, nothing
  silently assumed - and return to the calling skill's next step.

## Recommended answers

- **Give each question your recommended answer**, worded so "yes" accepts it.
  Where the code, a default or a prior decision already implies the answer, that
  is the recommendation - "I read X in the code; keep it?".
- **Never for a gate decision** - approving an intent, accepting an ADR - which
  is never pre-selected (rule `61-gates`). Ask those separately, as the gate.
- **Mark the questions a blanket "yes" cannot settle** - anything in the
  High-risk areas (rule `60-high-risk`), what the PO's data means (what "delete"
  means, retention, who sees what), and scope (in or out of the MVP). Recommend
  for these too, but as options to choose from.
- **A blanket reply accepts every unmarked recommendation**; numbered answers
  override it, and a marked question stays open until answered. Open the next
  message with one line naming what was accepted ("Accepted Q1-Q5 as
  recommended; Q6 still needs your call"). A marked question still unanswered
  when the rounds run dry is parked as an open question, never assumed.
- **Record an accepted recommendation as one** - where the answer lands in a
  `Q-NNN` block, its `_Resolution:_` reads `recommended, accepted by <who>`, not
  `decided by`, so the reviewer can see which answers nobody actively chose.

## Questions talk cannot settle

Don't talk through a question only something concrete can answer ("one long form
or three steps?", "how should this feel?"). Record it as a `Q-NNN` whose title
says it settles with a prototype, naming the option to build first, with
`impact: non-blocking` and `required_before: implementation` - the build settles
it (`/steer:work` `start`) - and move on.

## Language and code

Read `spec/glossary.md` before the first round (the workspace's, in a polyrepo
member). Ask each of these inside the normal rounds, with a recommended answer:

- **A term that conflicts with the glossary** - challenge it at once: "the
  glossary defines a cart as items before payment; you seem to mean a paid
  order - which is it?"
- **A fuzzy or overloaded word** - propose one canonical term: "account - the
  customer or the user?"
- **A boundary between two concepts** - invent the edge case that forces it:
  "a shopper pays, then adds an item - same order or a new one?"
- **A claim about how the product works** - check it against the code and
  surface a contradiction; a PO hears it as product behavior ("today the app
  cancels the whole order"), per Audience.

**Write a resolved term to the glossary in the same turn**, not in a batch: in
the main product language, naming its English code identifier (rule
`85-practices`), with no implementation detail. With no glossary to write - an
unmanaged repo, a caller that writes no spine - it lands with the other answers.
Renaming code to match is a Behavioral change for `/steer:work`, never part of
the interview.

## Audience

A PO gets plain language and the product's own words: no stack, file or id
vocabulary, and a recommendation phrased as what the user will experience. A dev
gets the technical framing. The mechanics above are the same for both.
