"""Tests for the shipped-template action-pin refresher.

Every lookup is injected, so the suite never touches the network: what is under
test is the pin rewrite (including the zizmor-suppression comment form), the
bump-up-only rule, and that a failed lookup is loud rather than a silent no-op.
"""

from __future__ import annotations

from pathlib import Path

import refresh_template_pins as rtp

RELEASES = "repos/{}/releases?per_page=100"


def _fetch(tags: dict[str, list[str]], commits: dict[str, str], fail: set[str] | None = None):
    def fetch(path: str):
        action = path.split("repos/", 1)[1].split("/git/", 1)[0].split("/releases", 1)[0]
        if fail and action in fail:
            raise LookupError("boom")
        if "/releases" in path:
            return [{"tag_name": t, "draft": False, "prerelease": False} for t in tags[action]]
        if "/git/ref/tags/" in path:
            tag = path.rsplit("/", 1)[1]
            return {"object": {"type": "tag", "sha": f"annotated-{tag}"}}
        if "/git/tags/" in path:
            tag = path.rsplit("annotated-", 1)[1]
            return {"object": {"sha": commits[f"{action}@{tag}"]}}
        raise AssertionError(path)

    return fetch


def _wf(tmp_path: Path, body: str) -> Path:
    d = tmp_path / "workflows"
    d.mkdir()
    (d / "ci.yml").write_text(body, encoding="utf-8")
    return d


OLD = "a" * 40
NEW = "b" * 40


def test_bumps_a_stale_pin(tmp_path: Path):
    wf = _wf(tmp_path, f"      - uses: acme/act@{OLD} # v1.0.1\n")
    fetch = _fetch({"acme/act": ["v1.0.2", "v1.0.1"]}, {"acme/act@v1.0.2": NEW})
    bumps, failures = rtp.refresh(wf, write=True, fetch=fetch)
    assert failures == []
    assert bumps == ["- ci.yml: acme/act v1.0.1 -> v1.0.2"]
    assert (wf / "ci.yml").read_text() == f"      - uses: acme/act@{NEW} # v1.0.2\n"


def test_preserves_a_zizmor_suppression_comment(tmp_path: Path):
    # The version sits at the END of the comment on a suppressed line, so a
    # regex anchored right after the `#` would silently skip these pins.
    wf = _wf(tmp_path, f"      - uses: acme/act@{OLD} # zizmor: ignore[artipacked] - v1.0.1\n")
    fetch = _fetch({"acme/act": ["v1.0.2"]}, {"acme/act@v1.0.2": NEW})
    rtp.refresh(wf, write=True, fetch=fetch)
    assert (
        wf / "ci.yml"
    ).read_text() == f"      - uses: acme/act@{NEW} # zizmor: ignore[artipacked] - v1.0.2\n"


def test_never_moves_a_pin_backwards(tmp_path: Path):
    body = f"      - uses: acme/act@{OLD} # v2.0.0\n"
    wf = _wf(tmp_path, body)
    fetch = _fetch({"acme/act": ["v1.9.9"]}, {"acme/act@v1.9.9": NEW})
    bumps, _ = rtp.refresh(wf, write=True, fetch=fetch)
    assert bumps == []
    assert (wf / "ci.yml").read_text() == body


def test_ignores_a_moving_major_tag(tmp_path: Path):
    # anthropics/claude-code-action publishes `v1` alongside vX.Y.Z, and
    # releases/latest returns it - a tag whose commit moves under the pin.
    wf = _wf(tmp_path, f"      - uses: acme/act@{OLD} # v1.0.1\n")
    fetch = _fetch({"acme/act": ["v1", "v1.0.2"]}, {"acme/act@v1.0.2": NEW})
    bumps, failures = rtp.refresh(wf, write=True, fetch=fetch)
    assert failures == []
    assert bumps == ["- ci.yml: acme/act v1.0.1 -> v1.0.2"]


def test_a_failed_lookup_is_reported_not_swallowed(tmp_path: Path):
    body = f"      - uses: acme/act@{OLD} # v1.0.1\n"
    wf = _wf(tmp_path, body)
    fetch = _fetch({}, {}, fail={"acme/act"})
    bumps, failures = rtp.refresh(wf, write=True, fetch=fetch)
    assert bumps == []
    assert failures and "acme/act" in failures[0]
    assert (wf / "ci.yml").read_text() == body


def test_real_templates_parse():
    # Guards the regex against the pins actually shipped: a form it cannot match
    # is a pin this job would silently never refresh.
    from conftest import REPO_ROOT

    found = set()
    for path in (REPO_ROOT / rtp.WORKFLOWS).glob("*.yml"):
        for line in path.read_text(encoding="utf-8").splitlines():
            if "uses:" in line and "@" in line:
                m = rtp.PIN.search(line)
                assert m, f"{path.name}: unparsed pin {line.strip()!r}"
                found.add(m["action"])
    assert "actions/checkout" in found
