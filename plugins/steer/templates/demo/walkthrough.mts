// Captioned walkthrough of <feature> - re-record with `mise run demo:record`.
import { execFileSync } from "node:child_process";
import { mkdirSync, rmSync } from "node:fs";
import { join as joinPath } from "node:path";
import { type Browser, chromium, type Locator, type Page } from "playwright";

const BASE_URL = process.env.DEMO_BASE_URL ?? "http://localhost:3000";
const OUT = "demo";
const AUTH = joinPath(OUT, ".auth");
const SIZE = { width: 1280, height: 720 };
const VIDEO = joinPath(OUT, "<feature>_walkthrough.mp4");

declare global {
  interface Window {
    __demo: {
      card(title: string, subtitle: string): void;
      hideCard(): void;
      caption(text: string): void;
      ring(target: Element): void;
      clearRings(): void;
    };
  }
}

// Headless video has no cursor, so every cue the viewer sees is drawn here.
// Injected per document via addInitScript, so it survives navigation.
const OVERLAY_JS = `
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
      \`left:\${left}px;top:\${top}px;width:\${right - left}px;height:\${bottom - top}px;\`;
    document.documentElement.appendChild(el);
  },
  clearRings() {
    document.querySelectorAll(".__demo_ring").forEach((el) => el.remove());
  },
};
`;

async function card(page: Page, title: string, subtitle = "", holdMs = 3500) {
  await page.evaluate(([t, s]) => window.__demo.card(t, s), [title, subtitle]);
  await page.waitForTimeout(holdMs);
  await page.evaluate(() => window.__demo.hideCard());
}

async function caption(page: Page, text: string, holdMs = 3000) {
  await page.evaluate((t) => window.__demo.caption(t), text);
  await page.waitForTimeout(holdMs);
}

/** Ring the first visible match; a hidden duplicate would draw an empty box. */
async function ring(locator: Locator, holdMs = 1500) {
  const target = locator.filter({ visible: true }).first();
  await target.waitFor({ state: "visible" });
  await target.evaluate((el) => window.__demo.ring(el));
  await locator.page().waitForTimeout(holdMs);
}

async function goto(page: Page, path: string) {
  await page.goto(BASE_URL + path);
  await page.waitForLoadState("networkidle");
}

/**
 * Sign in off camera and save the session; undefined for an app with no sign-in.
 * Pass `indexedDB: true` to storageState: some apps keep the session there.
 */
async function signIn(_browser: Browser, _persona: string): Promise<string | undefined> {
  return undefined;
}

async function recordClip(
  browser: Browser,
  name: string,
  state: string | undefined,
  scenes: (page: Page) => Promise<void>,
): Promise<string> {
  const context = await browser.newContext({
    viewport: SIZE,
    recordVideo: { dir: joinPath(OUT, "clips"), size: SIZE },
    storageState: state,
  });
  await context.addInitScript(OVERLAY_JS);
  const page = await context.newPage();
  await scenes(page);
  await page.evaluate(() => window.__demo.caption(""));
  await context.close();
  const clip = joinPath(OUT, "clips", `${name}.webm`);
  const video = page.video();
  if (!video) throw new Error("context was created without recordVideo");
  await video.saveAs(clip);
  await video.delete();
  return clip;
}

function join(clips: string[], target: string) {
  const inputs = clips.flatMap((clip) => ["-i", clip]);
  const streams = clips.map((_, i) => `[${i}:v]`).join("");
  execFileSync(
    "ffmpeg",
    ["-y", "-loglevel", "error", ...inputs,
      "-filter_complex", `${streams}concat=n=${clips.length}:v=1:a=0[v]`,
      "-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p",
      "-movflags", "+faststart", target],
    { stdio: "inherit" },
  );
}

async function scenes(page: Page) {
  await card(page, "<Feature name>", "<one line: what the viewer is about to see>");
  await goto(page, "/");
  await caption(page, "<Step 1 of the user experience, in the product's words>");
  await ring(page.getByRole("heading").first());
  await page.evaluate(() => window.__demo.clearRings());
  await card(page, "What's next", "<the next outcome, in the product's words>");
}

rmSync(joinPath(OUT, "clips"), { recursive: true, force: true });
mkdirSync(AUTH, { recursive: true });
const browser = await chromium.launch();
const clips = [await recordClip(browser, "main", await signIn(browser, "main"), scenes)];
await browser.close();
join(clips, VIDEO);
console.log(VIDEO);
