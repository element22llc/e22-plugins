// Build-time fix for a Slidev 52.16.0 bug (still present on slidevjs/slidev
// `main`): @slidev/client/logic/slides.ts `getSlidePath()` always prepends
// `import.meta.env.BASE_URL` when building slide-navigation targets:
//
//     return `${import.meta.env.BASE_URL}${path}`
//
// In hash routing (`routerMode: hash`) the router base ALREADY carries
// BASE_URL — main.ts calls `createWebHashHistory(import.meta.env.BASE_URL)` —
// so prepending it again double-counts the base. With our non-root base
// (`/presentation/onboarding/`) clicking "next" pushes
// `/presentation/onboarding/#/presentation/onboarding/2`, which matches no
// route (slides register at `/:no`) and lands on Slidev's in-app NotFound page.
//
// We must use hash routing here: the deck is published to GitHub Pages under a
// sub-path of the docs site, and GitHub Pages serves only the *site-root*
// 404.html as an SPA fallback — never a nested `presentation/onboarding/404.html`
// — so history-mode deep links / refreshes 404. Hash routing keeps every slide
// inside index.html (see slides.md headmatter + README).
//
// Fix: in hash mode emit base-RELATIVE nav targets (`/2`) and let the router
// base supply the prefix; history mode is unchanged. Remove this plugin if/when
// upstream makes getSlidePath hash-aware.
const BUGGY = 'return `${import.meta.env.BASE_URL}${path}`'
const FIXED = "return `${__SLIDEV_HASH_ROUTE__ ? '/' : import.meta.env.BASE_URL}${path}`"

// `vite` is not a direct dependency of this deck (it ships transitively inside
// @slidev/cli), so we export a plain config object rather than importing
// `defineConfig` — importing it would fail to resolve at config-load time.
export default {
  plugins: [
    {
      name: 'slidev-hash-base-nav-fix',
      enforce: 'pre',
      transform(code, id) {
        if (!id.includes('@slidev/client/logic/slides'))
          return
        if (code.includes(FIXED))
          return
        if (!code.includes(BUGGY)) {
          // Upstream changed the line we patch — fail loudly rather than ship a
          // silently-unfixed (broken) hash-routing build.
          throw new Error(
            '[slidev-hash-base-nav-fix] getSlidePath() no longer matches the '
            + 'patched line in @slidev/client/logic/slides.ts. Re-verify hash '
            + 'routing and update or remove presentation/onboarding/vite.config.ts.',
          )
        }
        return { code: code.replace(BUGGY, FIXED), map: null }
      },
    },
  ],
}
