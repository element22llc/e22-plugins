<!-- steer:inject-when=code-project -->
## Internal ids stay out of end-user surfaces

ADR ids, tracker refs, `Q-NNN` ids, feature slugs and `spec/**` paths are
internal traceability. Keep them out of **app UI copy** (titles, labels, badges,
tooltips, empty/error states, emails) and **`/spec/app/` guide copy and release
notes** — state what changed for the user, not the record behind it; use the
product's own domain language (`spec/glossary.md`, linked not copied). Refs
belong in intent, contracts, ADRs, history, runbook, PRs, commits.
