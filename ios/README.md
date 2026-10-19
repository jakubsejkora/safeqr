# Safe QR for iPhone

Native SwiftUI app, iOS 26+, Czech and English. Uses the local `SafeQRKit` engine, Apple frameworks and the cloud contract in `../spec/openapi.yaml`. No external app dependencies. Built with [Xcode 27.1](https://developer.apple.com/news/releases/?id=10152026a), Swift 6 and complete concurrency checking.

Open `SafeQR.xcodeproj`, select **SafeQR** and run on an iPhone 17 Pro Simulator or a signed iPhone. Team: `T6C4HUSL99`; bundle: `cz.safeqr.app`. Set `SAFEQR_API_BASE_URL` to override `https://api.safeqr.cz` (HTTPS required).

From the repository root:

```sh
xcodebuild -project ios/SafeQR.xcodeproj -scheme SafeQR -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
xcodebuild -project ios/SafeQR.xcodeproj -scheme SafeQR -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

Tests cover API decoding and risk-floor merging, consent and sensitive-code exclusions, cloud failure, local history, action URL encoding, guide resources and reading two QR codes from one image. The Simulator uses Vision's first supported barcode revision on CPU because newer revisions fail there; real devices use the current revision, including Micro QR. Actual multi-camera capture, torch and Wi-Fi joining need a physical iPhone check. Wide-to-ultra-wide bounds are approximate because of lens separation and distortion.

Debug builds offer sample codes and an explicit **Demo deep checks** setting. `--screen onboarding|scan|link|payment|wifi|premiumSMS|help|guide|settings` selects a screen for review; samples go through the real engine. Demo evidence never runs in Release. SwiftUI previews inject the preview client and in-memory history. Regenerate all icon variants from the repository root with `swift ios/scripts/render-icon.swift`.

Deep checks require consent and time out after 45 seconds. An unavailable backend leaves the offline result intact. Private codes (Wi-Fi, authentication, eSIM, contacts, events and communications) stay on device. History is off initially, stores only type/date/score, uses file protection and is excluded from backups. Guide data lives in bilingual JSON and uses only verified research instructions and scoped bank contacts reviewed on 19 October 2026. Backend retention and in-memory photo handling follow the API contract and need deployed integration verification.

No engine or API contract changes are required.
