// steer - `mise run changelog:new`: record a changelog fragment from KIND / SLUG / BODY.
// Node, not inline sh: mise runs inline tasks through cmd.exe on Windows, and spawning
// changie with an argv array means no shell ever re-parses a BODY holding quotes or `&`.
import { spawnSync } from "node:child_process"

const hints = {
  KIND: "set KIND=Added|Changed|Fixed|Security|Docs",
  SLUG: "set SLUG to 3-6 kebab-case words",
  BODY: "set BODY to the entry text",
}

const missing = Object.keys(hints).filter((name) => !process.env[name])
for (const name of missing) console.error(`changelog:new: ${hints[name]}`)
if (missing.length > 0) process.exit(1)

const { KIND, SLUG, BODY } = process.env
const result = spawnSync("changie", ["new", "-k", KIND, "-m", `Slug=${SLUG}`, "-b", BODY], {
  stdio: "inherit",
})
if (result.error) {
  console.error(`changelog:new: could not run changie (${result.error.message})`)
  process.exit(1)
}
process.exit(result.status ?? 1)
