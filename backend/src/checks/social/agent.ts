import { load } from "cheerio";
import { safeFetch, type WebFetch, webUrl } from "../../shared/network.js";
import type { Limitation } from "../verdict/copy.js";
import {
  classifyLink,
  extractLinkPage,
  instagramUsername,
  isLinkPage,
  type SocialLink,
} from "./links.js";
import { inspectProfile, type PublicProfile } from "./profile.js";

export interface SocialReport {
  profile?: PublicProfile;
  links: SocialLink[];
  unresolvedForwarders: string[];
}
export interface SocialResult {
  report?: SocialReport;
  limitations: Limitation[];
}
export interface SocialInput {
  url: string;
  page?: { url: string; html: string };
}

async function fetchLinkPage(
  url: string,
  fetchPage: WebFetch,
): Promise<{ url: string; html: string }> {
  const signal = AbortSignal.timeout(4500);
  let current = webUrl(url).href;
  for (let hop = 0; hop < 4; hop++) {
    const category = classifyLink(current)?.category;
    if (hop > 0 && category && !["website", "forwarder"].includes(category))
      return { url: current, html: "" };
    const response = await fetchPage(current, { signal, truncate: true });
    if (
      [301, 302, 303, 307, 308].includes(response.status) &&
      response.headers.location
    ) {
      current = webUrl(new URL(response.headers.location, current).href).href;
      continue;
    }
    if (response.status < 200 || response.status >= 300)
      throw new Error("Link page unavailable");
    const html = response.headers["content-type"]?.includes("html")
      ? response.body.toString("utf8")
      : "";
    const $ = load(html);
    const refresh =
      response.headers.refresh ??
      $("meta[http-equiv]")
        .filter(
          (_, node) => $(node).attr("http-equiv")?.toLowerCase() === "refresh",
        )
        .attr("content");
    const next = refresh
      ?.match(/(?:^|;)\s*url\s*=\s*['"]?([^'"]+)/i)?.[1]
      ?.trim();
    if (next) {
      current = webUrl(new URL(next, current).href).href;
      continue;
    }
    return { url: current, html };
  }
  throw new Error("Link page redirect limit");
}

function pageLinks(page: {
  url: string;
  html: string;
}): SocialLink[] | undefined {
  const destination = classifyLink(page.url);
  return destination && !["website", "forwarder"].includes(destination.category)
    ? [destination]
    : extractLinkPage(page.html, page.url);
}

/** Checks one public profile and at most two link pages; never opens their leaf destinations. */
export async function inspectSocial(
  input: SocialInput,
  dependencies: {
    profile?: typeof inspectProfile;
    fetch?: WebFetch;
    progress?: () => Promise<void>;
  } = {},
): Promise<SocialResult> {
  const username = instagramUsername(input.url);
  const initialLinks = input.page
    ? extractLinkPage(input.page.html, input.page.url)
    : undefined;
  if (!username && !isLinkPage(input.url) && !initialLinks)
    return { limitations: [] };
  await dependencies.progress?.();
  const report: SocialReport = { links: [], unresolvedForwarders: [] };
  const limitations: Limitation[] = [];
  if (username) {
    try {
      report.profile = await (dependencies.profile ?? inspectProfile)(username);
      report.links = report.profile.links
        .map(classifyLink)
        .filter((link): link is SocialLink => Boolean(link));
      if (report.profile.private) limitations.push("privateProfile");
    } catch {
      limitations.push("profile");
    }
  } else if (initialLinks) {
    report.links = initialLinks;
  } else {
    try {
      const page = await fetchLinkPage(
        input.url,
        dependencies.fetch ?? safeFetch,
      );
      report.links = pageLinks(page) ?? [];
    } catch {
      limitations.push("socialLinks");
    }
  }
  const queue = report.links.filter(
    (link) =>
      isLinkPage(link.url) ||
      (report.profile &&
        !(report.profile.verified && report.profile.business) &&
        link.category === "website"),
  );
  const visited = new Set([input.url]);
  let fetched = username ? 0 : 1;
  while (queue.length && fetched < 2) {
    const link = queue.shift();
    if (!link || visited.has(link.url)) continue;
    visited.add(link.url);
    fetched++;
    try {
      const page = await fetchLinkPage(
        link.url,
        dependencies.fetch ?? safeFetch,
      );
      const children = pageLinks(page);
      if (!children?.length) {
        if (isLinkPage(link.url)) {
          report.unresolvedForwarders.push(link.domain);
          limitations.push("socialLinks");
        }
        continue;
      }
      report.links = report.links.filter((item) => item.url !== link.url);
      report.links.push(...children);
      queue.push(...children.filter((item) => isLinkPage(item.url)));
    } catch {
      if (isLinkPage(link.url)) report.unresolvedForwarders.push(link.domain);
      limitations.push("socialLinks");
    }
  }
  report.links = [
    ...new Map(report.links.map((link) => [link.url, link])).values(),
  ].slice(0, 20);
  report.unresolvedForwarders = [
    ...new Set([
      ...report.unresolvedForwarders,
      ...report.links
        .filter((link) => link.category === "forwarder")
        .map((link) => link.domain),
    ]),
  ];
  return { report, limitations: [...new Set(limitations)] };
}
