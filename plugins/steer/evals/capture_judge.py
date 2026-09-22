#!/usr/bin/env python3
"""Check `replay_judge.py`'s judge prompt against what this CLI actually sends.

The prompt is version-bound, and reading it out of the binary is how it went
wrong before: `strings` drops empty lines, so every blank line in the template
read as a single newline. This captures the real thing instead. It builds a toy
plugin with one eval case, points the CLI's API base URL at a local stub that
logs request bodies and answers with a fixed message, runs
`claude plugin eval` against it, and diffs the captured judge request against
`replay_judge.judge_prompt()`.

No API call leaves the machine and nothing is billed - the stub answers both the
agent run and the three judge votes. Run it after a CLI upgrade, and after any
change to the prompt in `replay_judge.py`::

    uv run python plugins/steer/evals/capture_judge.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from replay_judge import judge_prompt  # noqa: E402

CRITERIA = "The response must greet the reader.\n\nA greeting in any language counts."
STUB_REPLY = "PASS"
SSE = [
    {
        "type": "message_start",
        "message": {
            "id": "msg_stub",
            "type": "message",
            "role": "assistant",
            "model": "claude-sonnet-5",
            "content": [],
            "stop_reason": None,
            "stop_sequence": None,
            "usage": {"input_tokens": 1, "output_tokens": 1},
        },
    },
    {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}},
    {
        "type": "content_block_delta",
        "index": 0,
        "delta": {"type": "text_delta", "text": STUB_REPLY},
    },
    {"type": "content_block_stop", "index": 0},
    {
        "type": "message_delta",
        "delta": {"stop_reason": "end_turn", "stop_sequence": None},
        "usage": {"output_tokens": 1},
    },
    {"type": "message_stop"},
]


def serve(captured: list[dict]) -> HTTPServer:
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:
            body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
            captured.append(body)
            if body.get("stream"):
                self.send_response(200)
                self.send_header("content-type", "text/event-stream")
                self.end_headers()
                for event in SSE:
                    frame = f"event: {event['type']}\ndata: {json.dumps(event)}\n\n"
                    self.wfile.write(frame.encode())
            else:
                payload = json.dumps(
                    {
                        "id": "msg_stub",
                        "type": "message",
                        "role": "assistant",
                        "model": body.get("model", "stub"),
                        "content": [{"type": "text", "text": STUB_REPLY}],
                        "stop_reason": "end_turn",
                        "usage": {"input_tokens": 1, "output_tokens": 1},
                    }
                ).encode()
                self.send_response(200)
                self.send_header("content-type", "application/json")
                self.send_header("content-length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

        def log_message(self, *args: object) -> None:
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def toy_plugin(root: Path) -> Path:
    (root / ".claude-plugin").mkdir(parents=True)
    (root / ".claude-plugin" / "plugin.json").write_text(
        json.dumps({"name": "judge-capture", "version": "0.0.1", "description": "prompt capture"})
    )
    case = root / "evals" / "greets" / "graders"
    case.mkdir(parents=True)
    (case.parent / "case.yaml").write_text(
        'schema_version: "1.1"\nname: greets\nexecution:\n  prompt: |\n'
        "    Say hello.\n  max_turns: 1\n  allowed_tools: []\nruns: 1\n"
    )
    (case / "answer.md").write_text(
        f"---\ntype: llm\nfocus: last_message\nweight: 2\n---\n\n{CRITERIA}\n"
    )
    return root


def main() -> int:
    captured: list[dict] = []
    server = serve(captured)
    port = server.server_address[1]
    with tempfile.TemporaryDirectory() as tmp:
        root = toy_plugin(Path(tmp) / "plugin")
        run = subprocess.run(
            [
                "claude",
                "plugin",
                "eval",
                "--ablation",
                "none",
                "--judge-model",
                "sonnet",
                "--trust-plugin",
                "--no-publish",
                "--mocks",
                "off",
                str(root),
            ],
            cwd=root,
            env={
                **os.environ,
                "ANTHROPIC_BASE_URL": f"http://127.0.0.1:{port}",
                "ANTHROPIC_API_KEY": "stub-key",
                # Same reason `mise.toml`'s evals task sets it: `plugin eval` is
                # early access and exits without it on a machine the rollout has
                # not reached.
                "CLAUDE_CODE_WALNUT_SPIRE": "1",
            },
            capture_output=True,
            text=True,
            timeout=600,
        )
        server.shutdown()
        if run.returncode != 0:
            sys.exit(f"`claude plugin eval` exited {run.returncode}:\n{run.stderr or run.stdout}")
        results = sorted((root / "evals" / "results").glob("*/aggregate-result.json"))
        payload = json.loads(results[-1].read_text())
        case = payload["cases"][0]
        grader = next(g for g in case["graders"] if g["name"] == "answer")
        run_graders = next(iter(case["arms"].values()))[0]["graders"]
        evidence = next(g["evidence"] for g in run_graders if g["name"] == "answer")

    # The judge call is the tool-less, thinking-disabled one; the agent run is not.
    judges = [
        b
        for b in captured
        if b.get("thinking", {}).get("type") == "disabled" and not b.get("tools")
    ]
    if not judges:
        sys.exit("no judge call captured - the grader never ran")
    sent = judges[0]["messages"][0]["content"]
    sent = sent if isinstance(sent, str) else sent[0]["text"]
    rebuilt = judge_prompt(grader["config"]["criteria"], evidence)

    print(f"judge calls captured: {len(judges)} (the CLI votes 3 times)")
    print("system blocks:")
    for block in judges[0]["system"]:
        print(f"  - {block['text'].splitlines()[0][:72]}")
    print(f"tools: {judges[0].get('tools')}  thinking: {judges[0].get('thinking')}")
    if sent == rebuilt:
        print("\nreplay_judge.judge_prompt matches this CLI byte for byte")
        return 0
    print("\nMISMATCH - update replay_judge.judge_prompt and re-measure fidelity")
    print(f"  sent:     {sent!r}")
    print(f"  rebuilt:  {rebuilt!r}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
