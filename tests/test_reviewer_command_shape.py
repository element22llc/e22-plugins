"""steer-pr-reviewer keeps its Bash calls off the auto-mode classifier.

Reviewer runs sent almost every Bash call to the classifier: a `cd` prefix, a
`VAR=...;` preamble, the rubric extracted with `sed`, the diff paged with
`sed -n`. The agent body carries the command shape, and `/steer:work review`
hands it files to Read rather than commands to run.
"""

from __future__ import annotations

from conftest import REPO_ROOT

PLUGIN = REPO_ROOT / "plugins" / "steer"


def test_reviewer_body_carries_the_command_shape():
    body = (PLUGIN / "agents" / "steer-pr-reviewer.md").read_text()
    for anchor in (
        "## Commands - stay on the allowlist",
        "No `cd` prefix, no `git -C`",
        "no `VAR=...;` preamble",
        "`${SHA}:path`",
        "Read files with Read",
        "never extract the rubric",
    ):
        assert anchor in body, anchor
    assert "`gh api` GETs" not in body


def test_review_mode_hands_the_reviewer_files():
    step3 = (PLUGIN / "skills" / "work" / "modes" / "review.md").read_text()
    step3 = step3.split("## Step 3", 1)[1].split("## Step 4", 1)[0]
    assert 'gh pr diff "$n" >' in step3
    assert "those two file paths" in step3
    assert "absolute\npath of [`REVIEW-LOOP.md`]" in step3
