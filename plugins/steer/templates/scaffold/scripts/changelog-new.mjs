// steer - `mise run changelog:new`: record a changelog fragment from --kind/--slug/--body
// (mise exposes them as usage_* env vars) or the KIND / SLUG / BODY env fallback.
// Node, not inline sh: mise runs inline tasks through cmd.exe on Windows, and spawning
// changie with an argv array means no shell ever re-parses a BODY holding quotes or `&`.
import { spawnSync } from "node:child_process"

const hints = {
  KIND: "pass --kind (or KIND=) Added|Changed|Fixed|Security|Docs",
  SLUG: "pass --slug (or SLUG=) 3-6 kebab-case words",
  BODY: "pass --body (or BODY=) the entry text",
}

const value = (name) => process.env[`usage_${name.toLowerCase()}`] || process.env[name]

const missing = Object.keys(hints).filter((name) => !value(name))
for (const name of missing) console.error(`changelog:new: ${hints[name]}`)
if (missing.length > 0) process.exit(1)

const result = spawnSync(
  "changie",
  ["new", "-k", value("KIND"), "-m", `Slug=${value("SLUG")}`, "-b", value("BODY")],
  { stdio: "inherit" },
)
if (result.error) {
  console.error(`changelog:new: could not run changie (${result.error.message})`)
  process.exit(1)
}
process.exit(result.status ?? 1)
