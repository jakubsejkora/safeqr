# SafeQRKit

Offline decoding, explainable risk scores and Czech/English display content for iOS 26 and macOS 26. Swift tools 6.2, Swift 6 concurrency, Foundation and CryptoKit only. No network calls, payload logging or automatic actions.

```swift
import SafeQRKit

let result = CodeInspector(locale: Locale(identifier: "cs_CZ")).inspect(scannedText)
// Present each action's confirmation before handing it to another app.
```

From this directory, run `swift build` and `swift test`. Tests use Swift Testing and the shared `../../spec/fixtures/codes.json` cases: original text, locale, expected kind, level, exact finding IDs and selected display facts. The catalog is copied intact so an inspector's locale works independently of the host app's language.

The score sums contributions from distinct rule IDs, takes at least the highest hard floor, then caps at 100. Below 30 is safe, 30–69 caution, 70–100 danger. A safe result means no known warning, not verified trust. Remote assessments cannot go below the device floor. Inputs above 32 KiB are not parsed; at most 32 distinct embedded items are inspected, with explicit warnings when a limit is reached.

PAY by square is detected from its header; raw LZMA decoding is intentionally unsupported. Wallet ownership, token decimals, Ethereum address checksums and Lightning signatures/expiry are not verified. Unsupported structured features and ambiguous fields suppress handoffs. Bank formats without a universal app link, eSIM activation and device-login approvals offer copy/share only. `containsSecrets` also checks embedded codes and disables `benefitsFromCloudCheck`. The host must still protect raw codes and action data in storage, logs and sharing.

Bank and premium-number resources retain the supplied ČNB/APMS provenance. Other sources: [QR Platba](https://qr-platba.cz/pro-vyvojare/specifikace-formatu/), [QR Faktura](https://www.kdpcr.cz/informace/qr-faktura/popis-formatu), [EPC](https://www.europeanpaymentscouncil.eu/document-library/guidance-documents/quick-response-code-guidelines-enable-data-capture-initiation), [SIX QR-bill](https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/qr-bill.html), [EMVCo](https://www.emvco.com/emv-technologies/qr-codes/), [IBAN registry 103](https://www.swift.com/resource/iban-registry-pdf), [BOLT11](https://github.com/lightning/bolts/blob/master/11-payment-encoding.md). Domain, shortener and currency JSON files include their source URLs and review dates. Domain matches are comparison targets, never a trust allowlist. Validate updates and run the fixture suite before replacing these snapshots.
