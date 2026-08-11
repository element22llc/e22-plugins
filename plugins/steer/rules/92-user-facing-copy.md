<!-- steer:inject-when=code-project -->
## Internal ids stay out of end-user surfaces

ADR ids, tracker refs, `Q-NNN` ids, feature slugs and `spec/**` paths are
internal traceability. Never let one reach **app UI copy** (titles, labels,
badges, tooltips, empty/error states, emails) or the **`/spec/app/` guide and
release notes** — state what changed for the user, not the record behind it;
use the product's own domain language (`spec/glossary.md`). Refs
stay dev-side: contracts, ADRs, history, runbook, PRs, commits.
