import { getDomain } from "tldts";
import { hash } from "../../intel/schema.js";
import type { Indicator } from "../../shared/schemas.js";

export function normalizeIndicator(indicator: Indicator): string {
  const value = indicator.value.trim();
  switch (indicator.type) {
    case "domain":
      return new URL(`https://${value}`).hostname
        .toLowerCase()
        .replace(/\.$/, "");
    case "iban":
      return value.replace(/\s/g, "").toUpperCase();
    case "phone":
    case "shortCode":
      return value.replace(/[^\d]/g, "").replace(/^00/, "");
    case "cryptoAddress":
      return /^(?:0x|bc1|tb1|bcrt1|ltc1|lnbc|lntb)/i.test(value)
        ? value.toLowerCase()
        : value;
    case "urlPattern": {
      const url = new URL(value);
      url.search = "";
      url.hash = "";
      return url.href;
    }
  }
}
export function indicatorKey(indicator: Indicator): string {
  const value = normalizeIndicator(indicator);
  return `indicator#${indicator.type}#${hash(indicator.type === "urlPattern" ? new URL(value).hostname : value)}`;
}

export function extractIndicators(
  payload: string,
  urls: string[] = [],
): Indicator[] {
  const indicators: Indicator[] = [];
  const links = new Set([
    ...urls,
    ...(payload.match(/https?:\/\/[^\s<>"']+/gi) ?? []),
  ]);
  for (const link of links) {
    try {
      const url = new URL(link);
      const domain = getDomain(url.hostname, { allowPrivateDomains: true });
      let hostname = url.hostname;
      indicators.push({ type: "urlPattern", value: url.href });
      while (
        hostname &&
        domain &&
        (hostname === domain || hostname.endsWith(`.${domain}`))
      ) {
        indicators.push({ type: "domain", value: hostname });
        if (hostname === domain) break;
        hostname = hostname.slice(hostname.indexOf(".") + 1);
      }
    } catch {
      /* Invalid URLs cannot match a domain indicator. */
    }
  }
  for (const value of payload.match(/\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/gi) ?? [])
    indicators.push({ type: "iban", value });
  const phone = payload.match(
    /^(?:tel|sms|smsto|mms|mmsto):\/*([+\d(). -]+)/i,
  )?.[1];
  if (phone) {
    indicators.push({ type: "phone", value: phone });
    if (phone.replace(/\D/g, "").length <= 9)
      indicators.push({ type: "shortCode", value: phone });
  }
  for (const value of payload.match(
    /\b0[xX][a-fA-F0-9]{40}\b|\b(?:bc1[a-z0-9]{25,62}|[13][a-km-zA-HJ-NP-Z1-9]{25,34})\b/g,
  ) ?? [])
    indicators.push({ type: "cryptoAddress", value });
  const cryptoTarget = payload.match(
    /^(?:bitcoin|ethereum|solana|litecoin|tron|lightning):(?:\/\/)?([^?@/\s]+)/i,
  )?.[1];
  if (cryptoTarget && /^[A-Za-z0-9]{20,512}$/.test(cryptoTarget))
    indicators.push({ type: "cryptoAddress", value: cryptoTarget });
  if (/^T[1-9A-HJ-NP-Za-km-z]{33}$/.test(payload))
    indicators.push({ type: "cryptoAddress", value: payload });
  return [
    ...new Map(
      indicators.map((indicator) => [
        `${indicator.type}:${normalizeIndicator(indicator)}`,
        indicator,
      ]),
    ).values(),
  ].slice(0, 80);
}

export function matchesIndicator(
  candidate: Indicator,
  known: Indicator,
): boolean {
  if (candidate.type !== known.type) return false;
  const expected = normalizeIndicator(known);
  const actual = normalizeIndicator(candidate);
  if (known.type !== "urlPattern") return actual === expected;
  if (new URL(actual).origin !== new URL(expected).origin) return false;
  const escaped = expected
    .split("*")
    .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
    .join(".*");
  return new RegExp(`^${escaped}$`).test(actual);
}
