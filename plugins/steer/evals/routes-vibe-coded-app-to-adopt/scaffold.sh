#!/bin/sh
# Build a VIBE-CODED repo — real code, no spec spine, no toolchain — for the
# adopt routing case.
#
# The ask says "no spec, no toolchain; adopt it", so the fixture must carry
# neither: a mise.toml or a spec/ directory would contradict the prompt, and the
# volume of unspecified code is what distinguishes adopt from a greenfield init.
#
# Referenced by context.scaffold_script and run only under
# `claude plugin eval --scaffold` (author-supplied bash, off by default;
# `mise run evals` passes the flag).
set -eu

git init -q .
git config user.email eval@example.com
git config user.name "eval"

cat >README.md <<'EOF'
# snippet-box

Paste snippets, get a link back. Built over a weekend.
EOF

mkdir -p static

cat >app.py <<'EOF'
import sqlite3
import uuid

from flask import Flask, jsonify, request

app = Flask(__name__)
DB = "snippets.db"


def db():
    c = sqlite3.connect(DB)
    c.execute("create table if not exists snippets (id text, body text, lang text)")
    return c


@app.route("/api/snippets", methods=["POST"])
def create():
    body = request.json.get("body")
    lang = request.json.get("lang", "text")
    sid = uuid.uuid4().hex[:8]
    c = db()
    c.execute("insert into snippets values (?, ?, ?)", (sid, body, lang))
    c.commit()
    return jsonify({"id": sid})


@app.route("/api/snippets/<sid>")
def read(sid):
    c = db()
    row = c.execute("select body, lang from snippets where id = '" + sid + "'").fetchone()
    if not row:
        return jsonify({"error": "not found"}), 404
    return jsonify({"body": row[0], "lang": row[1]})


@app.route("/api/snippets/<sid>", methods=["DELETE"])
def delete(sid):
    c = db()
    c.execute("delete from snippets where id = ?", (sid,))
    c.commit()
    return "", 204


if __name__ == "__main__":
    app.run(debug=True)
EOF

cat >highlight.py <<'EOF'
LANGS = ["python", "js", "sh", "sql", "text"]


def guess(body):
    if "def " in body or "import " in body:
        return "python"
    if "function " in body or "=>" in body:
        return "js"
    if body.startswith("#!"):
        return "sh"
    if "select " in body.lower():
        return "sql"
    return "text"


def render(body, lang):
    if lang not in LANGS:
        lang = guess(body)
    return '<pre class="lang-' + lang + '">' + body.replace("<", "&lt;") + "</pre>"
EOF

cat >static/app.js <<'EOF'
async function save() {
  const body = document.querySelector("#editor").value;
  const r = await fetch("/api/snippets", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ body }),
  });
  const { id } = await r.json();
  location.hash = id;
}
document.querySelector("#save").addEventListener("click", save);
EOF

cat >requirements.txt <<'EOF'
flask
EOF

git add -A
git commit -qm "it works"
