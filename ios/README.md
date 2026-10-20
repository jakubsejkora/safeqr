# Safe QR for iPhone

Native SwiftUI app, iOS 26+, Czech and English. Uses the local `SafeQRKit` engine, Apple frameworks and the cloud contract in `../spec/openapi.yaml`. No external app dependencies. Built with [Xcode 27.1](https://developer.apple.com/news/releases/?id=10152026a), Swift 6 and complete concurrency checking.

Open `SafeQR.xcodeproj`, select **SafeQR** and run on an iPhone 17 Pro Simulator or a signed iPhone. Team: `T6C4HUSL99`; bundle: `cz.safeqr.app`. Change `SAFEQR_API_BASE_URL` in `Configurations/API.xcconfig` to switch the endpoint for Debug and Release (HTTPS required). The `$()` between the slashes keeps the URL intact in xcconfig syntax; individual configuration files can override it.

From the repository root:

```sh
xcodebuild -project ios/SafeQR.xcodeproj -scheme SafeQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
xcodebuild -project ios/SafeQR.xcodeproj -scheme SafeQR -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

Tests cover cloud lifecycle and defensive enum decoding, risk-floor merging, consent and sensitive-code exclusions, cloud failure, local history, action URL encoding, guide resources, all 15 sample kinds and the website’s nested and side-by-side QR images. Gallery fixtures come from the public training gallery at `safeqr-web.jakub-f9d.workers.dev/qr/`. The Simulator uses Vision's first supported barcode revision on CPU because newer revisions fail there; real devices use the current revision, including Micro QR. Actual multi-camera capture, torch and Wi-Fi joining need a physical iPhone check. Wide-to-ultra-wide bounds are approximate because of lens separation and distortion.

Debug builds offer 38 bilingual samples in six menu groups and an explicit **Demo deep checks** setting. `--screen` accepts a case from `App/Debug/DebugSample.swift`, or `onboarding|scan|help|guide|settings|scannerIdle|scannerLocked|scannerChecking|scannerDanger`; every sample goes through the real engine. Launch options are parsed once at the app root and injected by `App/Debug/DebugLaunchConfiguration.swift`. `--medium` opens a compact result; `--confirmation` opens its confirmation sheet. Training, HTTP and checking/danger scanner modes accept `--live-check`, with `--live-scene` for the photo; `--journey`, `--sandbox` and `--scene` focus completed evidence. Add `-AppleLanguages '(cs)' -AppleLocale cs_CZ` for Czech or `-AppleLanguages '(en)' -AppleLocale en_US` for English. Release excludes all launch tools, demo clients and preview photos. SwiftUI previews inject the preview client and in-memory history. Regenerate all six themes’ Light, Dark and Tinted icons and Settings previews from the repository root with `swift ios/scripts/render-icon.swift`; the vector renderer reads its palettes from `AppTheme.swift`.

Deep checks require consent and time out after 45 seconds. An unavailable backend or an unsupported risk classification leaves the offline result intact with an explanation. Unknown progress statuses remain visible without being treated as successful checks. Private codes (Wi-Fi, authentication, eSIM, contacts, events and communications) stay on device. History is off initially, stores only type/date/score, uses file protection and is excluded from backups. Guide data lives in bilingual JSON and uses only verified research instructions and scoped bank contacts reviewed on 19 October 2026. Scene photos are screened in full before upload and omitted if a private or unreadable code is found, or the selected code cannot be located. The cache holds at most 20 results for ten minutes and releases photos when preparing the upload. Cloud photos use private encrypted storage in Frankfurt, are deleted after checks, and have a one-day cleanup fallback; deletion can take longer. Results become inaccessible after 24 hours. Bedrock processing may use other AWS regions within the EU.

No engine or API contract changes are required.
