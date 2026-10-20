import { load } from "cheerio";
import { getDomain } from "tldts";
import { webUrl } from "../../shared/network.js";

const linkPages = new Set([
  "linktr.ee",
  "beacons.ai",
  "lnk.bio",
  "allmylinks.com",
  "solo.to",
  "bio.link",
  "linkin.bio",
  "tap.bio",
  "campsite.bio",
  "msha.ke",
  "hoo.be",
  "stan.store",
  "bio.site",
  "milkshake.app",
  "carrd.co",
  "heylink.me",
  "litelink.at",
]);
const categories = {
  adult: [
    "onlyfans.com",
    "fansly.com",
    "fanvue.com",
    "justfor.fans",
    "manyvids.com",
    "loyalfans.com",
    "fancentro.com",
    "mym.fans",
  ],
  messaging: [
    "t.me",
    "telegram.me",
    "telegram.org",
    "wa.me",
    "whatsapp.com",
    "signal.me",
    "discord.gg",
  ],
  payment: [
    "paypal.me",
    "paypal.com",
    "revolut.me",
    "buymeacoffee.com",
    "ko-fi.com",
    "patreon.com",
  ],
  forwarder: [
    "bit.ly",
    "tinyurl.com",
    "t.co",
    "t.ly",
    "is.gd",
    "v.gd",
    "cutt.ly",
    "rb.gy",
    "shorturl.at",
    "rebrand.ly",
    "buff.ly",
    "ow.ly",
    "lnkd.in",
    "qrco.de",
    "q.me-qr.com",
  ],
  crypto: [
    "binance.com",
    "coinbase.com",
    "kraken.com",
    "crypto.com",
    "bybit.com",
    "okx.com",
    "etoro.com",
    "trading212.com",
    "xtb.com",
    "robinhood.com",
  ],
  social: [
    "instagram.com",
    "facebook.com",
    "fb.com",
    "tiktok.com",
    "youtube.com",
    "youtu.be",
    "x.com",
    "twitter.com",
    "linkedin.com",
    "snapchat.com",
  ],
} as const;
export type LinkCategory = keyof typeof categories | "website";
export interface SocialLink {
  url: string;
  domain: string;
  category: LinkCategory;
}

function matches(host: string, domain: string): boolean {
  return host === domain || host.endsWith(`.${domain}`);
}

export function isInstagramUrl(input: string): boolean {
  try {
    return matches(webUrl(input).hostname, "instagram.com");
  } catch {
    return false;
  }
}

export function isLinkPage(input: string): boolean {
  try {
    const host = webUrl(input).hostname;
    return [...linkPages].some((domain) => matches(host, domain));
  } catch {
    return false;
  }
}

/** Unwraps only Instagram's explicit public redirect target, without fetching it. */
export function externalUrl(input: string, base?: string): string | undefined {
  try {
    let url = webUrl(base ? new URL(input, base).href : input);
    if (url.hostname === "l.instagram.com" && url.searchParams.get("u"))
      url = webUrl(url.searchParams.get("u") ?? "");
    return url.href;
  } catch {
    return undefined;
  }
}

export function classifyLink(input: string): SocialLink | undefined {
  const normalized = externalUrl(input);
  if (!normalized) return undefined;
  const url = new URL(normalized);
  const domain =
    getDomain(url.hostname, { allowPrivateDomains: true }) ?? url.hostname;
  const category = isLinkPage(normalized)
    ? "forwarder"
    : ((Object.entries(categories).find(([, domains]) =>
        domains.some((entry) => matches(url.hostname, entry)),
      )?.[0] as keyof typeof categories | undefined) ?? "website");
  return { url: normalized, domain, category };
}

export function instagramUsername(input: string): string | undefined {
  try {
    let url = webUrl(input);
    if (!matches(url.hostname, "instagram.com")) return undefined;
    for (let i = 0; i < 2 && url.pathname.startsWith("/accounts/login"); i++) {
      const next = url.searchParams.get("next");
      if (!next) return undefined;
      url = webUrl(new URL(next, "https://www.instagram.com/").href);
      if (!matches(url.hostname, "instagram.com")) return undefined;
    }
    const parts = url.pathname.split("/").filter(Boolean);
    const username = parts[0]?.toLowerCase();
    if (
      parts.length !== 1 ||
      !username ||
      !/^[a-z0-9_](?:[a-z0-9_.]{0,28}[a-z0-9_])?$/.test(username) ||
      [
        "accounts",
        "explore",
        "reels",
        "reel",
        "p",
        "stories",
        "direct",
        "about",
        "developer",
        "legal",
      ].includes(username)
    )
      return undefined;
    return username;
  } catch {
    return undefined;
  }
}

/** Extracts destinations without opening any of them. */
export function extractLinkPage(
  html: string,
  pageUrl: string,
): SocialLink[] | undefined {
  const $ = load(html);
  const next = $("#__NEXT_DATA__").text();
  $("script, style, header, footer").remove();
  const root = $("main").first().length ? $("main").first() : $("body");
  const allLinks = root.find("a[href]").toArray();
  const urls = new Set<string>();
  const ownDomain = classifyLink(pageUrl)?.domain;
  const add = (value: unknown) => {
    if (typeof value !== "string" || urls.size >= 20) return;
    const url = externalUrl(value, pageUrl);
    if (url && classifyLink(url)?.domain !== ownDomain) urls.add(url);
  };
  let visited = 0;
  const walk = (value: unknown, inLinks = false, depth = 0) => {
    if (++visited > 5000 || depth > 20 || urls.size >= 20) return;
    if (Array.isArray(value)) {
      for (const item of value) walk(item, inLinks, depth + 1);
    } else if (value && typeof value === "object") {
      if (
        inLinks &&
        Object.entries(value).some(
          ([key, item]) =>
            ["active", "isActive", "enabled", "visible"].includes(key) &&
            item === false,
        )
      )
        return;
      for (const [key, item] of Object.entries(value)) {
        if (inLinks && ["url", "href"].includes(key)) add(item);
        else
          walk(
            item,
            inLinks || /^(?:links|socialLinks)$/i.test(key),
            depth + 1,
          );
      }
    }
  };
  if (next) {
    try {
      walk(JSON.parse(next));
    } catch {
      /* DOM links remain available when embedded data is incomplete. */
    }
  }
  for (const element of allLinks) add($(element).attr("href"));
  const links = [...urls]
    .map(classifyLink)
    .filter((link): link is SocialLink => Boolean(link));
  const specialistLinks = links.filter(
    (link) => link.category !== "website",
  ).length;
  const structural =
    links.length >= 2 &&
    specialistLinks >= 2 &&
    links.length / Math.max(1, allLinks.length) >= 0.6 &&
    root.text().trim().length < 4000;
  return isLinkPage(pageUrl) || structural ? links : undefined;
}
