# Safe QR backend

TypeScript API and asynchronous deep checks for `../spec/openapi.yaml`, deployed with CDK to AWS eu-central-1. Lambda uses stable Node.js 24; local tools use Node 26 and the pnpm version pinned in `package.json`.

From `backend/`:

```sh
pnpm install --frozen-lockfile
pnpm typecheck && pnpm lint && pnpm test && pnpm synth
```

Tests and synthesis need no AWS credentials. Tests cover request validation, shared QR fixtures, risk floors, failed inspections, concurrency, privacy filters, source collection and infrastructure.

Copy `.env.example` to `.env`, authenticate with `aws sso login --profile safeqr`, then run:

```sh
pnpm run deploy
pnpm smoke https://safeqr-training.jakub-f9d.workers.dev/start --cs
pnpm smoke https://example.com/
pnpm smoke https://safeqr-training.jakub-f9d.workers.dev/start --scene test/fixtures/parking-machine.jpg
```

Set `API_URL`, `CHECKS_TABLE`, `INTEL_TABLE` and `MEDIA_BUCKET` from `deployment.json`. Deployment runs validation first. The live API is `https://xj5yhhdhb1.execute-api.eu-central-1.amazonaws.com`. A first deployment needs CDK bootstrap. For `api.safeqr.cz`, pass `-c apiCertificateArn=ARN` with a Frankfurt ACM certificate and create a CNAME to the `ApiDomainTarget` output.

`pnpm seed --dry-run` validates curated cases; `pnpm seed` imports them. `pnpm collect --dry-run` validates collector inputs. `pnpm collect` and the daily 06:00 Prague schedule share a daily guard. Store the Apify token as a plain string in Secrets Manager `safeqr/apify-token`; an optional local `APIFY_TOKEN` overrides it. Collection uses public sources, bounded actor charges and a daily spending preflight. Temporary Apify stores and logs are deleted before publication.

Instagram checks send only the public username to `apify/instagram-profile-scraper` (build `0.0.649`, verified 20 October 2026): one profile, 25 seconds, USD 0.01/run, at most 20 lookups per Prague day. The collector reserves at most USD 0.76/day; the combined planned cap stays below USD 1/day, with an account-spend preflight. Only the needed profile fields are retrieved; photos, posts and follower lists are neither fetched nor retained by Safe QR. Redacted bios stay in memory as untrusted model context and never appear in the API. Temporary Apify stores are purged after success or failure; failed cleanup makes the lookup unavailable. Up to 20 destinations and two link pages are inspected with pinned safe fetch; destination services are not opened. The existing `intel` progress slot displays the localized Apify label only for applicable checks, without a contract change.

Apify processing is **not EU-only**: its [DPA](https://docs.apify.com/legal/data-processing-addendum#7-international-data-transfers) permits processing in the US and other countries where its subprocessors operate (checked 20 October 2026); AWS resources remain in eu-central-1; Bedrock uses EU inference profiles.

Consent disclosure (CS): „Při kontrole instagramového profilu posíláme službě Apify pouze jeho veřejné uživatelské jméno, aby zjistila veřejné údaje a odkazy; tato služba může údaje zpracovávat i mimo EU.“

Consent disclosure (EN): “To check an Instagram profile, we send Apify only its public username to retrieve public details and links; Apify may process this data outside the EU.”

The link tracer and browser HTTP requests use DNS validation and IP pinning. Browser HTTP redirects become fresh routed navigations; subresource redirects are blocked. The browser blocks form submissions, non-GET requests, downloads and WebSockets, with bounded HTTP traffic and one vetted interstitial click. Visible form controls determine what a page requests; ordinary sign-in and payment requests carry no penalty without another risk signal. Only programs and archives trigger download warnings. Resolved shortener and HTTPS-upgrade warnings stop counting; device floors remain binding. Failed checks add limitations, not risk points, except when the destination cannot be opened at all. Bedrock failures produce explained deterministic verdicts; AI cannot lower device or proven evidence floors. Limits are 30 checks/minute, 500/day, three model attempts/check and 60 model attempts/fixed minute. Lambda functions share the account's concurrency pool.

Photos lose their metadata, pass through private encrypted S3 and are deleted after analysis, including failures. A one-day lifecycle rule provides backup cleanup; physical deletion can lag. Checks become inaccessible after 24 hours and discard original payloads on completion or handled failure. Private screenshot links last 15 minutes. Treat check IDs and screenshot URLs as bearer credentials. Logs contain operation names and aggregate metrics, not scan payloads.

Launch flags: HTTP routing does not contain WebRTC traffic; a local Chromium test sent STUN packets outside the router. Network-level egress isolation needs separate work. The iOS consent/privacy copy still promises photos are never stored, which conflicts with the temporary S3 handoff described above. The website and shared spec were corrected concurrently during this review. No public API fields changed in the backend.
