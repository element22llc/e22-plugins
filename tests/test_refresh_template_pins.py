"""Tests for the pin refresher: action tags, gh-actions-lock, re-listed plugins.

Every lookup is injected, so the suite never touches the network: what is under
test is the tag rewrite (including a trailing zizmor-suppression comment), the
gh-actions-lock extension pin, the marketplace SHA pins, the bump-up-only rule,
and that a failed lookup is loud rather than a silent no-op.
"""

from __future__ import annotations

import json
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


OLD, NEW = "a" * 40, "b" * 40
SLUG = "acme/plugins"


def _manifest(tmp_path: Path, *sources: dict[str, str]) -> Path:
    plugins = [{"name": f"p{i}", "source": src} for i, src in enumerate(sources)]
    path = tmp_path / "marketplace.json"
    path.write_text(json.dumps({"plugins": plugins}, indent=2) + "\n", encoding="utf-8")
    return path


def _subdir(sha: str = OLD, path: str = "plugins/ui", url: str = f"https://github.com/{SLUG}.git"):
    return {"source": "git-subdir", "url": url, "path": path, "sha": sha}


def _upstream(newest: dict[str, str], status: str = "ahead", gone: frozenset[str] = frozenset()):
    """Fake the three lookups; ``newest`` maps a path to its newest commit."""

    def fetch(api: str):
        assert api.startswith(f"repos/{SLUG}/"), api
        rest = api.removeprefix(f"repos/{SLUG}/")
        if rest.startswith("contents/"):
            if rest.removeprefix("contents/") in gone:
                raise LookupError("gh: Not Found (HTTP 404)")
            return []
        if rest.startswith("commits?path="):
            return [{"sha": newest[rest.removeprefix("commits?path=").removesuffix("&per_page=1")]}]
        assert rest.startswith("compare/"), api
        return {"status": status}

    return fetch


def test_bumps_a_stale_marketplace_sha_in_place(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir())
    before = manifest.read_text()
    bumps, failures = rtp.refresh_marketplace(
        manifest, write=True, fetch=_upstream({"plugins/ui": NEW})
    )
    assert failures == []
    assert bumps == [
        f"- marketplace.json: {SLUG}/plugins/ui aaaaaaa -> bbbbbbb",
        f"  review: https://github.com/{SLUG}/commits/{NEW}/plugins/ui",
    ]
    assert manifest.read_text() == before.replace(OLD, NEW)


def test_a_current_marketplace_sha_is_left_alone(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir())
    before = manifest.read_text()
    fetch = _upstream({"plugins/ui": OLD})
    assert rtp.refresh_marketplace(manifest, write=True, fetch=fetch) == ([], [])
    assert manifest.read_text() == before


def test_a_path_deleted_upstream_fails_instead_of_pinning_the_deletion(tmp_path: Path):
    # The newest commit touching a deleted path is the commit that deleted it.
    manifest = _manifest(tmp_path, _subdir())
    before = manifest.read_text()
    bumps, failures = rtp.refresh_marketplace(
        manifest,
        write=True,
        fetch=_upstream({"plugins/ui": NEW}, gone=frozenset({"plugins/ui"})),
    )
    assert bumps == []
    assert failures and f"{SLUG}/plugins/ui" in failures[0]
    assert manifest.read_text() == before


def test_a_pin_ahead_of_the_path_history_is_a_deliberate_pick(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir())
    fetch = _upstream({"plugins/ui": NEW}, status="behind")
    assert rtp.refresh_marketplace(manifest, write=True, fetch=fetch) == ([], [])


def test_a_diverged_pin_is_a_failure(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir())
    fetch = _upstream({"plugins/ui": NEW}, status="diverged")
    bumps, failures = rtp.refresh_marketplace(manifest, write=True, fetch=fetch)
    assert bumps == []
    assert failures and "diverged" in failures[0]


def test_a_non_github_source_is_a_failure_not_a_skip(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir(url="https://gitlab.com/acme/plugins.git"))
    bumps, failures = rtp.refresh_marketplace(manifest, write=True, fetch=_upstream({}))
    assert bumps == []
    assert failures and "gitlab.com" in failures[0]


def test_a_malformed_or_short_pin_is_a_failure(tmp_path: Path):
    # An exception here would exit 1, which the workflow reads as "bumps applied".
    no_path = {"source": "git-subdir", "url": f"https://github.com/{SLUG}.git", "sha": OLD}
    manifest = _manifest(tmp_path, no_path, _subdir(sha="abc1234"))
    bumps, failures = rtp.refresh_marketplace(manifest, write=True, fetch=_upstream({}))
    assert bumps == []
    assert len(failures) == 2


def test_entries_sharing_a_sha_are_rewritten_independently(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir(path="plugins/ui"), _subdir(path="plugins/db"))
    fetch = _upstream({"plugins/ui": NEW, "plugins/db": OLD})
    bumps, _ = rtp.refresh_marketplace(manifest, write=True, fetch=fetch)
    assert len(bumps) == 2
    sources = [p["source"] for p in json.loads(manifest.read_text())["plugins"]]
    assert [s["sha"] for s in sources] == [NEW, OLD]


def test_an_unpinned_or_local_source_is_skipped(tmp_path: Path):
    unpinned = {"source": "git-subdir", "url": f"https://github.com/{SLUG}.git", "path": "x"}
    manifest = _manifest(tmp_path, unpinned)
    manifest.write_text(
        manifest.read_text().replace('"plugins": [', '"plugins": [{"source": "./local"},'),
        encoding="utf-8",
    )
    assert rtp.refresh_marketplace(manifest, write=True, fetch=_upstream({})) == ([], [])


def test_main_reports_a_marketplace_bump_and_its_review_link(tmp_path: Path, capsys):
    manifest = _manifest(tmp_path, _subdir())
    upstream = _upstream({"plugins/ui": NEW})

    def fetch(api: str):
        # main() also walks the real gh-actions-lock pins; an old release moves none.
        return [{"tag_name": "v0.0.1"}] if "/releases?" in api else upstream(api)

    before = manifest.read_text()
    args = ["--workflows", str(_wf(tmp_path, "")), "--marketplace", str(manifest)]
    assert rtp.main(args, fetch=fetch) == 1
    assert manifest.read_text() == before
    out = capsys.readouterr().out.splitlines()
    assert out[1].startswith("- marketplace.json: ")
    # Not a bullet: the workflow's changelog step collects every `- ...:` line.
    assert out[2].startswith("  review: https://github.com/")


def test_main_fails_on_a_missing_manifest(tmp_path: Path):
    args = ["--workflows", str(_wf(tmp_path, "")), "--marketplace", str(tmp_path / "nope.json")]
    assert rtp.main(args) == 2


def test_real_marketplace_pins_are_watched():
    # A source object the regex cannot match is a pin this job would never refresh.
    from conftest import REPO_ROOT

    text = (REPO_ROOT / rtp.MARKETPLACE).read_text(encoding="utf-8")
    pinned = [
        p["source"]
        for p in json.loads(text)["plugins"]
        if isinstance(p["source"], dict) and p["source"].get("sha")
    ]
    matched = [json.loads(m[0]) for m in rtp.SUBDIR_SOURCE.finditer(text)]
    assert pinned and matched == pinned
    for src in matched:
        assert rtp.GITHUB_URL.match(src["url"]), src["url"]
