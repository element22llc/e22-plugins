"""Tests for the pin refresher: action tags, gh-actions-lock, Semgrep, re-listed plugins.

Every lookup is injected, so the suite never touches the network: what is under
test is the tag rewrite (including a trailing zizmor-suppression comment), the
gh-actions-lock extension pin, the Semgrep version + exclude-newer pair and its
cooldown, the marketplace SHA pins, the bump-up-only rule, and that a failed
lookup is loud rather than a silent no-op.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
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
    args += ["--security-script", str(_security(tmp_path))]
    assert rtp.main(args, fetch=fetch, pypi=_pypi(), now=NOW) == 1
    assert manifest.read_text() == before
    out = capsys.readouterr().out.splitlines()
    assert out[1].startswith("- marketplace.json: ")
    # Not a bullet: the workflow's changelog step collects every `- ...:` line.
    assert out[2].startswith("  review: https://github.com/")


def test_main_fails_on_a_missing_manifest(tmp_path: Path):
    args = ["--workflows", str(_wf(tmp_path, "")), "--marketplace", str(tmp_path / "nope.json")]
    assert rtp.main(args) == 2


NOW = datetime(2026, 11, 26, 6, 31, tzinfo=UTC)
# NOW - 7 days is 2026-11-19; that date can start as early as 2026-11-18T10:00Z.
COOLED = "2026-11-18T09:59:59Z"
WARM = "2026-11-18T10:00:00Z"
PIN = 'X=1\nSTEER_SEMGREP_VERSION=1.185.0\nSTEER_SEMGREP_EXCLUDE_NEWER=2026-11-16\nuvx "$X"\n'


def _security(tmp_path: Path, body: str = PIN) -> Path:
    path = tmp_path / "ci-security.sh"
    path.write_text(body, encoding="utf-8")
    return path


def _file(name: str, uploaded: str, yanked: bool | str = False) -> dict[str, object]:
    return {"filename": name, "upload-time": uploaded, "yanked": yanked}


def _wheel(ver: str, uploaded: str, yanked: bool | str = False) -> dict[str, object]:
    return _file(f"semgrep-{ver}-cp310-abi3-manylinux_2_35_x86_64.whl", uploaded, yanked)


def _pypi(*files: dict[str, object], fail: Exception | None = None):
    def fetch(package: str):
        assert package == "semgrep", package
        if fail:
            raise fail
        return {"meta": {"api-version": "1.4"}, "files": list(files)}

    return fetch


def _semgrep(script: Path, fetch):
    return rtp.refresh_semgrep(script, write=True, now=NOW, fetch=fetch)


def test_bumps_the_semgrep_pair_together(tmp_path: Path):
    script = _security(tmp_path)
    fetch = _pypi(
        _wheel("1.185.0", "2026-11-10T09:33:11Z"),
        _wheel("1.186.0", "2026-11-18T00:22:47.885605Z"),
        _file("semgrep-1.186.0.tar.gz", "2026-11-18T00:23:16Z"),
    )
    bumps, failures = _semgrep(script, fetch)
    assert failures == []
    assert bumps == [
        "- ci-security.sh: semgrep 1.185.0 -> 1.186.0, exclude-newer 2026-11-16 -> 2026-11-19"
    ]
    assert script.read_text() == PIN.replace("1.185.0", "1.186.0").replace(
        "2026-11-16", "2026-11-19"
    )


def test_a_release_inside_the_cooldown_is_skipped(tmp_path: Path):
    script = _security(tmp_path)
    fetch = _pypi(_wheel("1.186.0", COOLED), _wheel("1.187.0", "2026-11-24T21:39:35Z"))
    bumps, _ = _semgrep(script, fetch)
    assert bumps == [
        "- ci-security.sh: semgrep 1.185.0 -> 1.186.0, exclude-newer 2026-11-16 -> 2026-11-19"
    ]


def test_the_cutoff_holds_for_the_earliest_timezone(tmp_path: Path):
    # Past 7 days at NOW, but a UTC+14 machine reads 2026-11-19 as excluding it.
    script = _security(tmp_path)
    assert _semgrep(script, _pypi(_wheel("1.186.0", WARM))) == ([], [])
    assert script.read_text() == PIN


def test_a_late_file_holds_back_its_whole_release(tmp_path: Path):
    script = _security(tmp_path)
    fetch = _pypi(_wheel("1.186.0", COOLED), _file("semgrep-1.186.0.tar.gz", WARM))
    assert _semgrep(script, fetch) == ([], [])
    assert script.read_text() == PIN


def test_a_current_semgrep_pin_is_a_no_op(tmp_path: Path):
    script = _security(tmp_path)
    fetch = _pypi(_wheel("1.184.0", "2026-11-05T19:17:23Z"), _wheel("1.185.0", COOLED))
    assert _semgrep(script, fetch) == ([], [])
    assert script.read_text() == PIN


def test_never_moves_the_semgrep_pin_backwards(tmp_path: Path):
    script = _security(tmp_path, PIN.replace("1.185.0", "1.190.0"))
    assert _semgrep(script, _pypi(_wheel("1.186.0", COOLED))) == ([], [])
    assert "STEER_SEMGREP_VERSION=1.190.0\n" in script.read_text()


def test_a_later_hand_set_date_is_kept_on_a_bump(tmp_path: Path):
    script = _security(tmp_path, PIN.replace("2026-11-16", "2026-11-21"))
    bumps, _ = _semgrep(script, _pypi(_wheel("1.186.0", COOLED)))
    assert bumps and bumps[0].endswith("exclude-newer 2026-11-21 -> 2026-11-21")
    assert "STEER_SEMGREP_EXCLUDE_NEWER=2026-11-21\n" in script.read_text()


def test_versions_compare_numerically(tmp_path: Path):
    script = _security(tmp_path)
    bumps, _ = _semgrep(script, _pypi(_wheel("1.186.9", COOLED), _wheel("1.186.10", COOLED)))
    assert bumps and "-> 1.186.10," in bumps[0]


def test_pre_releases_and_yanked_releases_are_ignored(tmp_path: Path):
    script = _security(tmp_path)
    fetch = _pypi(
        _file("semgrep-1.186.0rc1.tar.gz", COOLED),
        _file("semgrep-1.186.0.post1-py3-none-any.whl", COOLED),
        _wheel("1.187.0", COOLED, yanked="broken wheel"),
        _file("semgrep-1.187.0.tar.gz", COOLED),
    )
    assert _semgrep(script, fetch) == ([], [])
    assert script.read_text() == PIN


def test_a_malformed_old_release_does_not_fail_the_run(tmp_path: Path):
    script = _security(tmp_path)
    fetch = _pypi({"filename": "semgrep-0.1.0.tar.gz"}, _wheel("1.186.0", COOLED))
    bumps, failures = _semgrep(script, fetch)
    assert failures == []
    assert len(bumps) == 1


def test_a_failed_or_malformed_pypi_lookup_is_a_failure(tmp_path: Path):
    # An exception here would exit 1, which the workflow reads as "bumps applied".
    script = _security(tmp_path)
    for fetch in (
        _pypi(fail=LookupError("pypi.org/simple/semgrep: HTTP Error 503")),
        lambda package: [],
        lambda package: {"files": [None]},
        _pypi({"filename": "semgrep-1.186.0.tar.gz"}),
        _pypi(_wheel("1.186.0", "not a timestamp")),
        _pypi(_wheel("1.186.0", "2026-11-10T00:00:00")),
    ):
        bumps, failures = _semgrep(script, fetch)
        assert bumps == []
        assert failures and failures[0].startswith("ci-security.sh: semgrep - ")
    assert script.read_text() == PIN


def test_an_impossible_pinned_date_is_a_failure(tmp_path: Path):
    script = _security(tmp_path, PIN.replace("2026-11-16", "2026-13-45"))
    bumps, failures = _semgrep(script, _pypi(_wheel("1.186.0", COOLED)))
    assert bumps == []
    assert failures and failures[0].startswith("ci-security.sh: semgrep - ")


def test_a_reshaped_semgrep_pin_is_a_failure(tmp_path: Path):
    script = _security(tmp_path, PIN.replace("\nSTEER_SEMGREP_EXC", "\n\nSTEER_SEMGREP_EXC"))
    bumps, failures = _semgrep(script, _pypi(_wheel("1.186.0", COOLED)))
    assert bumps == []
    assert failures and "STEER_SEMGREP_VERSION" in failures[0]


def test_main_fails_on_a_semgrep_lookup_failure(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir())
    args = ["--workflows", str(_wf(tmp_path, "")), "--marketplace", str(manifest)]
    args += ["--security-script", str(_security(tmp_path))]

    upstream = _upstream({"plugins/ui": OLD})

    def fetch(api: str):
        return [{"tag_name": "v0.0.1"}] if "/releases?" in api else upstream(api)

    pypi = _pypi(fail=LookupError("pypi.org/simple/semgrep: timed out"))
    assert rtp.main(args, fetch=fetch, pypi=pypi, now=NOW) == 2


def test_main_fails_on_a_missing_security_script(tmp_path: Path):
    manifest = _manifest(tmp_path, _subdir())
    args = ["--workflows", str(_wf(tmp_path, "")), "--marketplace", str(manifest)]
    args += ["--security-script", str(tmp_path / "nope.sh")]
    assert rtp.main(args) == 2


def test_real_semgrep_pin_is_watched():
    # A pin pair the regex cannot match is a pin this job would never refresh.
    from conftest import REPO_ROOT

    assert rtp.SEMGREP_PIN.search((REPO_ROOT / rtp.SECURITY_SCRIPT).read_text(encoding="utf-8"))


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
