# Privacy policy

This policy covers the **steer** plugin and the `e22-plugins` marketplace, an
open-source project ([Apache-2.0](https://github.com/element22llc/e22-plugins/blob/main/LICENSE))
maintained by Element 22. It describes what the plugin does with your data.
Element 22's company-wide policy is at
[element-22.com/privacy-policy](https://www.element-22.com/privacy-policy).

## Summary

steer collects nothing. It has no telemetry, no analytics and no backend of its
own. Its rules, skills, hooks and scripts run locally inside your coding
assistant. Data leaves your machine only through the third-party services
listed below, and through a bug report you can see in public.

## What runs locally

- **Hooks and scripts** read your repository and session to inject standards
  and check writes. Their output stays in your session.
- **Fault log.** When a hook fails, steer records the fault in git-ignored
  `.claude/steer-faults.*` files inside your repository. They never leave your
  machine unless a defect report includes them (see below).
- **Language servers** (Copilot manifest) run as local processes.

## Third-party services the plugin connects to

steer configures two MCP servers. Requests go directly from your assistant to
the service; Element 22 never receives them.

- **GitHub MCP server** (`api.githubcopilot.com`), operated by GitHub. Your
  GitHub token (`github_pat`, or your GitHub sign-in on Copilot) and the
  repository, issue and pull-request data your session reads or writes are
  sent to GitHub. The token is stored by your assistant's plugin
  configuration, not by steer. See the
  [GitHub General Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
- **Context7 MCP server** (`mcp.context7.com`), operated by Upstash. Library
  names and documentation queries are sent to look up current library docs. No
  credentials are sent. See [Context7's privacy policy](https://context7.com/privacy).

Your coding assistant itself (Claude Code, GitHub Copilot, Codex) is governed
by its vendor's terms. Workflows that steer scaffolds into your repository run
under your own GitHub account and secrets.

## Defect reports (`/steer:report`)

When steer's own machinery misbehaves, the assistant files a bug **as a public
issue** in [`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins/issues),
under your GitHub account, without a confirmation prompt. This is the only way
data from your session reaches Element 22. Before filing, the report is
scrubbed:

- absolute paths are rewritten to `<repo>/...`;
- secret-shaped values (tokens, keys, credentialed URLs, `.env` values) are
  replaced with `[redacted]`;
- no product source code is included, only the steer-side artifact (a hook
  message, a contradictory instruction);
- your repository is identified by its `owner/repo` slug at most, and omitted
  when sensitive.

Anything that cannot be confidently redacted is dropped. You can edit or close
an issue you filed; to have one deleted, contact us as below.

## Contact

For a privacy question, open an issue in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins/issues).
To report a privacy or security problem privately, use the repository's
[private vulnerability reporting](https://github.com/element22llc/e22-plugins/security).

Changes to this policy are tracked in the repository's history.
