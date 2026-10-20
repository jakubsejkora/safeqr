import { load } from "cheerio";
import type { LinkReport } from "../../shared/schemas.js";

const riskyExtension =
  /\.(?:apk|ipa|mobileconfig|exe|msi|dmg|pkg|bat|cmd|scr|js|vbs|jar|ps1|zip|rar|7z|tar|gz|tgz|bz2|xz|cab|iso)$/i;

export function riskyDownload(
  url: string,
  filename = "",
  contentType = "",
): boolean {
  let path = "";
  try {
    path = decodeURIComponent(new URL(url).pathname);
  } catch {
    path = url.split(/[?#]/)[0] ?? "";
  }
  return (
    riskyExtension.test(filename.trim()) ||
    riskyExtension.test(path) ||
    /^(?:application\/(?:vnd\.android\.package-archive|x-msdownload|x-msi|x-apple-diskimage|zip|x-7z-compressed|x-rar-compressed|x-tar|gzip))(?:;|$)/i.test(
      contentType,
    )
  );
}

/** Classifies visible controls captured by the browser, never surrounding prose. */
export function inspectControls(html: string, baseUrl: string) {
  const $ = load(html);
  const asks = new Set<NonNullable<LinkReport["asksFor"]>[number]>();
  let downloads = false;
  const visible = (element: Parameters<typeof $>[0]) =>
    $(element)
      .parents()
      .addBack()
      .toArray()
      .every((node) => {
        const item = $(node);
        return (
          !item.is("[hidden], [inert], [aria-hidden=true], [disabled]") &&
          !/display\s*:\s*none|visibility\s*:\s*hidden/i.test(
            item.attr("style") ?? "",
          )
        );
      });
  $("input, select, textarea").each((_, element) => {
    const field = $(element);
    if (
      !visible(element) ||
      /^(hidden|submit|button|reset|image)$/i.test(field.attr("type") ?? "")
    )
      return;
    const id = field.attr("id");
    const labels = $("label")
      .filter((_, label) => Boolean(id) && $(label).attr("for") === id)
      .text();
    const hints = [
      ...[
        "type",
        "autocomplete",
        "name",
        "id",
        "placeholder",
        "aria-label",
        "data-safeqr-label",
      ].map((name) => field.attr(name) ?? ""),
      labels,
      field.closest("label").text(),
    ]
      .join(" ")
      .toLowerCase();
    if (/password|heslo/.test(hints)) asks.add("password");
    if (
      /cc-(?:number|name|exp|csc)|credit.?card|card.?number|cardholder|číslo karty|držitel karty|\bcvv\b|\bcvc\b/.test(
        hints,
      )
    )
      asks.add("card");
    if (/bank.?login|bankid|bankovní identit/.test(hints))
      asks.add("bankLogin");
    if (/\btel\b|phone|telefon/.test(hints)) asks.add("phone");
    if (
      /one-time-code|\botp\b|sms.{0,12}kód|verification code|ověřovací kód/.test(
        hints,
      )
    )
      asks.add("otp");
    if (
      /e-?mail|street-address|postal-code|address-line|given-name|family-name|full.?name|home address|bydliště|datum narození|\bbday\b/.test(
        hints,
      )
    )
      asks.add("personalData");
  });
  $("iframe").each((_, element) => {
    if (!visible(element)) return;
    const frame = $(element);
    let url: URL;
    try {
      url = new URL(frame.attr("src") ?? "", baseUrl);
    } catch {
      return;
    }
    const host = url.hostname;
    const paymentHost =
      /(^|\.)(stripe\.com|adyen\.com|braintreegateway\.com|paypal\.com|gopay\.com|gopay\.cz|comgate\.cz|gpwebpay\.com)$/.test(
        host,
      );
    const cardFrame = /\bcard\b|credit.?card|cc-number|číslo karty/i.test(
      `${frame.attr("title") ?? ""} ${frame.attr("name") ?? ""} ${url.pathname}`,
    );
    if (paymentHost || cardFrame) asks.add("payment");
    if (cardFrame) asks.add("card");
  });
  $("button, [role=button], input[type=submit]").each((_, element) => {
    if (!visible(element)) return;
    const button = $(element);
    const label =
      `${button.text()} ${button.attr("aria-label") ?? ""} ${button.attr("value") ?? ""}`.trim();
    if (
      /\b(?:apple pay|google pay|paypal|pay now|pay parking|zaplatit|zaplaťte)\b/i.test(
        label,
      )
    )
      asks.add("payment");
    if (/^(?:install|instalovat|stáhnout aplikaci)$/i.test(label))
      asks.add("appInstall");
    if (
      /^(?:allow notifications|povolit oznámení|povolit přístup|grant permission)$/i.test(
        label,
      )
    )
      asks.add("permission");
  });
  $("a[href]").each((_, element) => {
    if (!visible(element)) return;
    const link = $(element);
    try {
      downloads ||= riskyDownload(
        new URL(link.attr("href") ?? "", baseUrl).href,
        link.attr("download"),
      );
    } catch {
      // Invalid links cannot be followed by this check.
    }
  });
  if (asks.has("card")) asks.add("payment");
  return { asksFor: [...asks], downloads };
}
