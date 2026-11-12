"""Tests for the shipped-template action-tag refresher.

Every lookup is injected, so the suite never touches the network: what is under
test is the tag rewrite (including a trailing zizmor-suppression comment), the
gh-actions-lock extension pin, the bump-up-only rule, and that a failed lookup is
loud rather than a silent no-op.
"""

from __future__ import annotations

from pathlib import Path

import refresh_template_pins as rtp


def _fetch(tags: dict[str, list[str]], fail: set[str] | None = None):
    def fetch(path: str):
        action = path.split("repos/", 1)[1].split("/releases", 1)[0]
        if fail and action in fail:
            raise LookupError("boom")
        assert path.endswith("/releases?per_page=100"), path
        return [{"tag_name": t, "draft": False, "prerelease": False} for t in tags[action]]

    return fetch


def _wf(tmp_path: Path, body: str) -> Path:
    d = tmp_path / "workflows"
    d.mkdir()
    (d / "ci.yml").write_text(body, encoding="utf-8")
    return d


def _refresh(wf: Path, fetch, pins: tuple[Path, ...] = ()):
    return rtp.refresh(wf, write=True, fetch=fetch, extension_pins=pins)


def test_bumps_a_stale_tag(tmp_path: Path):
    wf = _wf(tmp_path, "      - uses: acme/act@v1.0.1\n")
    bumps, failures = _refresh(wf, _fetch({"acme/act": ["v1.0.2", "v1.0.1"]}))
    assert failures == []
    assert bumps == ["- ci.yml: acme/act v1.0.1 -> v1.0.2"]
    assert (wf / "ci.yml").read_text() == "      - uses: acme/act@v1.0.2\n"


def test_preserves_a_trailing_zizmor_comment(tmp_path: Path):
    wf = _wf(tmp_path, "        uses: acme/act@v1.0.1 # zizmor: ignore[artipacked]\n")
    _refresh(wf, _fetch({"acme/act": ["v1.0.2"]}))
    assert (
        wf / "ci.yml"
    ).read_text() == "        uses: acme/act@v1.0.2 # zizmor: ignore[artipacked]\n"


def test_never_moves_a_tag_backwards(tmp_path: Path):
    body = "      - uses: acme/act@v2.0.0\n"
    wf = _wf(tmp_path, body)
    bumps, _ = _refresh(wf, _fetch({"acme/act": ["v1.9.9"]}))
    assert bumps == []
    assert (wf / "ci.yml").read_text() == body


def test_ignores_a_moving_major_tag(tmp_path: Path):
    # anthropics/claude-code-action publishes `v1` alongside vX.Y.Z.
    wf = _wf(tmp_path, "      - uses: acme/act@v1.0.1\n")
    bumps, failures = _refresh(wf, _fetch({"acme/act": ["v1", "v1.0.2"]}))
    assert failures == []
    assert bumps == ["- ci.yml: acme/act v1.0.1 -> v1.0.2"]


def test_a_failed_lookup_is_reported_not_swallowed(tmp_path: Path):
    body = "      - uses: acme/act@v1.0.1\n"
    wf = _wf(tmp_path, body)
    bumps, failures = _refresh(wf, _fetch({}, fail={"acme/act"}))
    assert bumps == []
    assert failures and "acme/act" in failures[0]
    assert (wf / "ci.yml").read_text() == body


def test_bumps_the_extension_pin_in_every_copy(tmp_path: Path):
    wf = _wf(tmp_path, "")
    pins = (tmp_path / "ci-lib.sh", tmp_path / "lock-workflows.sh")
    for p in pins:
        p.write_text("x=1\nSTEER_ACTIONS_LOCK_VERSION=v0.4.1\n", encoding="utf-8")
    bumps, failures = _refresh(wf, _fetch({rtp.LOCK_EXTENSION: ["v0.5.0"]}), pins)
    assert failures == []
    assert len(bumps) == 2
    for p in pins:
        assert p.read_text() == "x=1\nSTEER_ACTIONS_LOCK_VERSION=v0.5.0\n"


def test_real_templates_parse():
    # A `uses:` the regex cannot match is a tag this job would never refresh.
    from conftest import REPO_ROOT

    found = set()
    for path in (REPO_ROOT / rtp.WORKFLOWS).glob("*.yml"):
        for line in path.read_text(encoding="utf-8").splitlines():
            if "uses:" in line and "@" in line:
                m = rtp.PIN.search(line)
                assert m, f"{path.name}: unparsed tag {line.strip()!r}"
                found.add(m["action"])
    assert "actions/checkout" in found


def test_real_extension_pins_agree():
    # CI verifies with ci-lib.sh's version and installs lock with the helper's;
    # different versions could disagree on the lockfile format.
    from conftest import REPO_ROOT

    versions = set()
    for rel in rtp.EXTENSION_PINS:
        m = rtp.EXTENSION_PIN.search((REPO_ROOT / rel).read_text(encoding="utf-8"))
        assert m, f"{rel}: no STEER_ACTIONS_LOCK_VERSION line"
        versions.add(m["ver"])
    assert len(versions) == 1, versions
