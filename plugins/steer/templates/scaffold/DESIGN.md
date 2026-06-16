---
version: alpha
name: "[Replace with product name]"
description: "[Replace with one-line description of the product's visual identity]"

colors:
  primary: "#000000"
  on-primary: "#FFFFFF"
  surface: "#FFFFFF"
  on-surface: "#0A0A0A"
  error: "#B91C1C"
  on-error: "#FFFFFF"

typography:
  h1:
    fontFamily: "[Replace with heading font]"
    fontSize: 2.25rem
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "[Replace with body font]"
    fontSize: 1rem
    fontWeight: 400
    lineHeight: 1.5

spacing:
  1: 4px
  2: 8px
  3: 12px
  4: 16px

rounded:
  md: 8px
  lg: 12px

components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "{spacing.3}"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "{spacing.3}"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: "{spacing.4}"
---

# DESIGN.md

This is your product's visual identity. It starts as a small valid stub — a few
colors, two type tokens, a spacing and radius scale, and three components. **Grow
it as reusable patterns emerge** (add a token or component once the same choice
shows up in **3+ places**), not before.

**Scope:** product-wide *reusable* rules only. Feature-specific design lives in
`/spec/features/[id]/intent.md`; implementation contracts in `contract.md`.

**One product-wide file, consumed by all apps.** This root `DESIGN.md` is the
shared identity. An app with a genuinely distinct identity may carry its own
`apps/<app>/DESIGN.md`, which overrides the root for that app; otherwise apps
inherit this one.

## Format spec

The **format** of this file — section order, the token schema, and lint rules —
is defined by the design.md specification, not by this repo:

<https://github.com/google-labs-code/design.md>

That URL is the source of truth for the **format**, not for this product's
design system. To pull the format spec into agent context:

```bash
npx @google/design.md spec
```

## Validate

```bash
npx @google/design.md lint DESIGN.md
```

CI runs this linter as an **advisory** (non-blocking) step whenever a `DESIGN.md`
changes — it is not a merge gate.
