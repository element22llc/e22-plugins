<!-- steer:inject-when=code-project -->
## Internal ids stay out of end-user surfaces

ADR ids, tracker refs, `Q-NNN` ids, feature slugs and `spec/**` paths are
internal traceability. Never let one reach **app UI copy** (titles, labels,
badges, tooltips, empty/error states, emails) or **`/spec/app/` guide copy and
release notes** — state what changed for the user, not the record behind it;
use the product's own domain language (`spec/glossary.md`). Refs
belong in intent, contracts, ADRs, history, runbook, PRs, commits.
