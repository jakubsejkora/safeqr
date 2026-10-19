# Safe QR web

Bilingual Astro static site, 30 build-time QR examples, recovery guides, and an A4 demo kit. Cloudflare Workers serves the assets and a validated, ten-minute cached cases proxy. `demo/` is an independent, clearly labeled training redirect chain with a non-submitting card form.

Use Node 22.22+ and pnpm 12.14 (`packageManager` is pinned). Run from `web/`:

```sh
pnpm install
pnpm dev
pnpm gallery:verdicts
pnpm check
pnpm test
pnpm build
pnpm test:qr
pnpm exec playwright install chromium
pnpm test:browser
```

`pnpm preview` runs the built site with the Worker locally. Browser checks default to the deployed site; override `SITE_URL` and `SCREEN_DIR` as needed. They check both color schemes, desktop/mobile/320px layouts, accessibility, filtering, no-JavaScript content, response headers and the training flow. QR verification decodes every generated SVG, both layers of the nested code, and the PAY by square payment. Invalid foreign-account, crypto, phone and login examples cannot authorize real transactions; valid bank formats use only the specified ČNB documentation account.

`pnpm gallery:verdicts` requires Swift 6.2+ on macOS 26 and runs `swift run --package-path ../ios/SafeQRKit safeqr-inspect` for both languages. It writes `src/data/verdicts.json` for all 30 examples, including separate results for the three second codes. Regenerate after engine or payload changes; builds reject snapshots whose payloads differ. The gallery shows these offline results, findings, facts, consequences and limitations. The app adds a cloud check for links. Scene descriptions remain labeled as context: text alone cannot expose a sticker, verify an account owner or follow redirects.

Deploy with `pnpm deploy` and `pnpm deploy:demo`. No routes or custom domains are configured.

- Website: https://safeqr-web.jakub-f9d.workers.dev
- Training: https://safeqr-training.jakub-f9d.workers.dev/start

Set `BACKEND_BASE_URL` in `wrangler.jsonc` to the deployed HTTPS backend origin, then redeploy. `/api/cases?locale=cs|en` calls `GET /v1/cases?locale=…&limit=5`. Its response adds `source: live|seed` and, for fallback, `reviewedAt`. Without a reachable, valid backend, it serves the explicitly labeled research seed. The training hostname is centralized in `src/data/gallery.ts`.

Versions were checked against official documentation and npm on 20 October 2026. TypeScript 6.0.3 is the latest compatible stable version: the current Astro checker requires TypeScript 5 or 6. Sources for public claims and help are linked beside the content; the supplied research was reviewed on 19 October 2026. The live backend is configured. App Store availability and custom-domain DNS remain pending.
