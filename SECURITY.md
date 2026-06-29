# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue, PR, or
discussion for a suspected vulnerability.

Use GitHub's **private vulnerability reporting**: go to the
[Security tab](https://github.com/element22llc/e22-plugins/security) of this
repository and choose **Report a vulnerability**. This opens a private advisory
visible only to you and the maintainers.

When reporting, please include:

- a description of the issue and its impact;
- the affected file(s), skill, hook, or workflow;
- steps to reproduce, and a proof of concept if you have one.

We aim to acknowledge a report within a few business days and will keep you
updated as we investigate and prepare a fix.

## Scope

This repository ships engineering-standards content: the `steer` plugin (rules,
skills, hooks, templates, helper scripts) and the bundled repo scaffold. The
most security-relevant surfaces are:

- the POSIX-sh **hook scripts** under `plugins/steer/hooks/` (they run in a
  user's Claude Code session);
- the helper **scripts** under `plugins/steer/scripts/`;
- the **GitHub Actions workflows** the scaffold ships (e.g. `claude.yml`).

Secrets are never committed to this repository; credentials referenced by the
tooling are supplied at runtime via environment variables or CI secrets.

## Supported versions

Only the latest released version of the `steer` plugin is supported. Fixes ship
in a new release rather than as patches to older versions.
