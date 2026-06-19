## When steer itself misbehaves, report it upstream

steer is maintained centrally in `element22llc/e22-plugins`. When the plugin's
**own machinery** misbehaves, treat it as a plugin defect to report — not a
thing to silently work around:

- A SessionStart **self-fault notice** flags recorded hook faults.
- A skill or rule gives **contradictory or impossible** instructions.
- A referenced **template, script, or helper is missing, malformed, or crashes**.

This is about steer's defects only — ordinary product-code errors, failing
tests, or your own mistakes are not plugin faults and do not belong here.

On any of the above: surface it plainly, then **offer `/steer:report`** to file a
scrubbed bug report upstream. Never auto-file — the user confirms first — and
never put secrets, absolute paths, or product code into the report. If you only
worked around the defect to keep going, still offer to report it so it gets
fixed for everyone.
