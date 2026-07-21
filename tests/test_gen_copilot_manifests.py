"""Tests for the Copilot manifest version-stamper.

``gen_copilot_manifests.py`` copies the source ``plugin.json`` version into the
Copilot CLI plugin manifest and the marketplace's ``steer`` entry, touching only
the ``version`` field — never the marketplace-level ``metadata.version``.
"""

from __future__ import annotations

import json
import re

import gen_copilot_manifests


def test_marketplace_pattern_targets_steer_entry_only():
    # metadata.version and the steer entry version differ; the pattern must match
    # only the steer entry, leaving metadata.version alone.
    text = json.dumps(
        {
            "metadata": {"version": "1.0.0"},
            "plugins": [{"name": "steer", "source": "./plugins/steer", "version": "3.20.0"}],
        },
        indent=2,
    )
    new, count = gen_copilot_manifests._MARKETPLACE_STEER_VERSION.subn(
        lambda m: f"{m.group(1)}9.9.9{m.group(2)}", text, count=1
    )
    assert count == 1
    data = json.loads(new)
    assert data["plugins"][0]["version"] == "9.9.9"
    assert data["metadata"]["version"] == "1.0.0"  # untouched


def test_plugin_pattern_matches_single_version():
    text = json.dumps({"name": "steer", "version": "3.20.0", "skills": "skills/"}, indent=2)
    assert len(re.findall(gen_copilot_manifests._PLUGIN_VERSION, text)) == 1


def test_restamp_reports_change(tmp_path):
    path = tmp_path / "plugin.json"
    path.write_text('{\n  "version": "1.0.0"\n}\n', encoding="utf-8")
    new_text, changed = gen_copilot_manifests._restamp(
        path, gen_copilot_manifests._PLUGIN_VERSION, "2.0.0"
    )
    assert changed
    assert '"version": "2.0.0"' in new_text
    # Idempotent: re-stamping the same value is a no-op.
    path.write_text(new_text, encoding="utf-8")
    _, changed_again = gen_copilot_manifests._restamp(
        path, gen_copilot_manifests._PLUGIN_VERSION, "2.0.0"
    )
    assert not changed_again


def test_real_manifests_in_sync(monkeypatch):
    # Running against the real repo must find nothing to change (CI keeps them
    # stamped). --write mode returns 0 and leaves the tree clean.
    from conftest import REPO_ROOT

    monkeypatch.chdir(REPO_ROOT)
    assert gen_copilot_manifests.main([]) == 0
