#!/usr/bin/env python3
"""Refuse to start an eval sweep whose model calls would leave via a proxy.

`claude plugin eval` children inherit ANTHROPIC_BASE_URL from the shell, and
Claude Code also applies the `env` block of the user's settings itself - so
`env -u` in the shell does not clear a value set there. A compressing proxy
(headroom, say) then rewrites what each run reads, and the sweep reports runs
rebuilding "garbled" skill output as routing failures. Every sweep through
2026-10-05 was measured that way before anyone noticed.

Set STEER_EVALS_ALLOW_BASE_URL=1 to run through a gateway you trust to pass
requests through unmodified.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

VAR = "ANTHROPIC_BASE_URL"
OVERRIDE = "STEER_EVALS_ALLOW_BASE_URL"


def settings_files(environ: dict[str, str]) -> list[Path]:
    config = Path(environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
    return [config / "settings.json", config / "settings.local.json"]


def find_base_urls(environ: dict[str, str]) -> list[str]:
    found = []
    if environ.get(VAR):
        found.append(f"shell environment: {VAR}={environ[VAR]}")
    for path in settings_files(environ):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        value = (data.get("env") or {}).get(VAR) if isinstance(data, dict) else None
        if value:
            found.append(f"{path} env: {VAR}={value}")
    return found


def main(environ: dict[str, str] | None = None) -> int:
    environ = dict(os.environ if environ is None else environ)
    found = find_base_urls(environ)
    if not found or environ.get(OVERRIDE) == "1":
        return 0
    print(f"check_eval_env: {VAR} is set, so every eval call would go through it:", file=sys.stderr)
    for line in found:
        print(f"  - {line}", file=sys.stderr)
    print(
        "A compressing proxy corrupts what runs read and the scores with it. Remove it\n"
        "for the sweep (`env -u` does not clear a settings.json value), or set\n"
        f"{OVERRIDE}=1 for a gateway that passes requests through unmodified.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
