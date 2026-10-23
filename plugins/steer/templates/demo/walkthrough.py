"""Captioned walkthrough of <feature> - re-record with `mise run demo:record`."""

import os
import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path

from playwright.sync_api import Browser, BrowserContext, Locator, Page, sync_playwright

BASE_URL = os.environ.get("DEMO_BASE_URL", "http://localhost:3000")
OUT = Path("demo")
AUTH = OUT / ".auth"
SIZE = {"width": 1280, "height": 720}
VIDEO = OUT / "<feature>_walkthrough.mp4"

# Headless video has no cursor, so every cue the viewer sees is drawn here.
# Injected per document via add_init_script, so it survives navigation.
OVERLAY_JS = """
window.__demo = {
  layer(id, css) {
    let el = document.getElementById(id);
    if (!el) {
      el = document.createElement("div");
      el.id = id;
      el.style.cssText = "position:fixed;z-index:2147483647;pointer-events:none;" + css;
      document.documentElement.appendChild(el);
    }
    return el;
  },
  caption(text) {
    const el = this.layer("__demo_caption",
      "left:50%;bottom:32px;transform:translateX(-50%);max-width:80%;padding:12px 20px;" +
      "border-radius:8px;background:rgba(17,17,17,.85);color:#fff;" +
      "font:500 22px/1.35 system-ui,sans-serif;text-align:center;");
    el.textContent = text;
    el.style.display = text ? "block" : "none";
  },
  card(title, subtitle) {
    const el = this.layer("__demo_card",
      "inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;" +
      "gap:16px;background:#111;color:#fff;font-family:system-ui,sans-serif;text-align:center;");
    el.innerHTML = "";
    const h = document.createElement("div");
    h.style.cssText = "font:600 44px/1.2 system-ui,sans-serif;max-width:80%";
    h.textContent = title;
    const p = document.createElement("div");
    p.style.cssText = "font:400 24px/1.4 system-ui,sans-serif;opacity:.8;max-width:70%";
    p.textContent = subtitle || "";
    el.append(h, p);
    el.style.display = "flex";
  },
  hideCard() {
    const el = document.getElementById("__demo_card");
    if (el) el.style.display = "none";
  },
  ring(target) {
    target.scrollIntoView({ block: "center", inline: "center" });
    const r = target.getBoundingClientRect();
    const left = Math.max(2, r.left - 8), top = Math.max(2, r.top - 8);
    const right = Math.min(innerWidth - 2, r.right + 8);
    const bottom = Math.min(innerHeight - 2, r.bottom + 8);
    const el = document.createElement("div");
    el.className = "__demo_ring";
    el.style.cssText = "position:fixed;z-index:2147483646;pointer-events:none;" +
      "box-sizing:border-box;" +
      "border:4px solid #f5a524;border-radius:8px;box-shadow:0 0 0 6px rgba(245,165,36,.25);" +
      `left:${left}px;top:${top}px;width:${right - left}px;height:${bottom - top}px;`;
    document.documentElement.appendChild(el);
  },
  clearRings() {
    document.querySelectorAll(".__demo_ring").forEach((el) => el.remove());
  },
};
"""


def card(page: Page, title: str, subtitle: str = "", hold_ms: int = 3500) -> None:
    page.evaluate("([t, s]) => window.__demo.card(t, s)", [title, subtitle])
    page.wait_for_timeout(hold_ms)
    page.evaluate("window.__demo.hideCard()")


def caption(page: Page, text: str, hold_ms: int = 3000) -> None:
    page.evaluate("t => window.__demo.caption(t)", text)
    page.wait_for_timeout(hold_ms)


def ring(locator: Locator, hold_ms: int = 1500) -> None:
    """Ring the first visible match; a hidden duplicate would draw an empty box."""
    target = locator.filter(visible=True).first
    target.wait_for(state="visible")
    target.evaluate("el => window.__demo.ring(el)")
    locator.page.wait_for_timeout(hold_ms)


def goto(page: Page, path: str) -> None:
    page.goto(BASE_URL + path)
    page.wait_for_load_state("networkidle")


def sign_in(browser: Browser, persona: str) -> Path | None:
    """Sign in off camera and save the session; None for an app with no sign-in.

    Include IndexedDB: some apps keep the session there, not in cookies.
    """
    return None


def record_clip(
    browser: Browser, name: str, state: Path | None, scenes: Callable[[Page], None]
) -> Path:
    context: BrowserContext = browser.new_context(
        viewport=SIZE,
        record_video_dir=str(OUT / "clips"),
        record_video_size=SIZE,
        storage_state=str(state) if state else None,
    )
    context.add_init_script(OVERLAY_JS)
    page = context.new_page()
    scenes(page)
    page.evaluate("window.__demo.caption('')")
    context.close()
    clip = OUT / "clips" / f"{name}.webm"
    page.video.save_as(clip)
    page.video.delete()
    return clip


def join(clips: list[Path], target: Path) -> None:
    inputs = [arg for clip in clips for arg in ("-i", str(clip))]
    streams = "".join(f"[{i}:v]" for i in range(len(clips)))
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", *inputs,
            "-filter_complex", f"{streams}concat=n={len(clips)}:v=1:a=0[v]",
            "-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", str(target),
        ],
        check=True,
    )  # fmt: skip


def scenes(page: Page) -> None:
    card(page, "<Feature name>", "<one line: what the viewer is about to see>")
    goto(page, "/")
    caption(page, "<Step 1 of the user experience, in the product's words>")
    ring(page.get_by_role("heading").first)
    page.evaluate("window.__demo.clearRings()")
    card(page, "What's next", "<the next outcome, in the product's words>")


def main() -> None:
    shutil.rmtree(OUT / "clips", ignore_errors=True)
    AUTH.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        clips = [record_clip(browser, "main", sign_in(browser, "main"), scenes)]
        browser.close()
    join(clips, VIDEO)
    print(VIDEO)


if __name__ == "__main__":
    main()
