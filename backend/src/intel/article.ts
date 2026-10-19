import { load } from "cheerio";
import { safeFetch, type WebFetch } from "../shared/network.js";
import { publicationDate } from "./publication.js";
import { canonicalSource } from "./sources.js";

export interface Article {
  sourceUrl: string;
  publishedAt?: string;
  text: string;
}

export function robotsAllows(text: string, path: string): boolean {
  const groups: {
    agents: string[];
    rules: { allow: boolean; path: string }[];
  }[] = [];
  let group = {
    agents: [] as string[],
    rules: [] as { allow: boolean; path: string }[],
  };
  for (const raw of text.split(/\r?\n/)) {
    const match = raw
      .replace(/#.*/, "")
      .trim()
      .match(/^([^:]+):\s*(.*)$/);
    if (!match) continue;
    const key = match[1]?.trim().toLowerCase();
    const value = match[2]?.trim() ?? "";
    if (key === "user-agent") {
      if (group.rules.length) {
        groups.push(group);
        group = { agents: [], rules: [] };
      }
      group.agents.push(value.toLowerCase());
    } else if (
      ["allow", "disallow"].includes(key ?? "") &&
      group.agents.length &&
      value
    )
      group.rules.push({ allow: key === "allow", path: value });
  }
  groups.push(group);
  const specific = groups.filter((item) =>
    item.agents.some((agent) => agent !== "*" && "safeqr".startsWith(agent)),
  );
  const selected = specific.length
    ? specific
    : groups.filter((item) => item.agents.includes("*"));
  const rules = selected
    .flatMap((item) => item.rules)
    .filter((rule) => {
      const pattern = rule.path
        .split("*")
        .map((part) => part.replace(/[.+?^{}()|[\]\\]/g, "\\$&"))
        .join(".*");
      return new RegExp(`^${pattern}`).test(path);
    })
    .sort(
      (a, b) =>
        b.path.length - a.path.length || Number(b.allow) - Number(a.allow),
    );
  return rules[0]?.allow ?? true;
}

export class ArticleRejected extends Error {
  constructor(
    readonly reason:
      | "unapproved_source"
      | "robots_denied"
      | "not_html"
      | "redirect_limit",
  ) {
    super(reason);
  }
}

async function robotsAllowed(
  url: URL,
  fetchPage: WebFetch,
  signal: AbortSignal,
): Promise<boolean> {
  let robotsUrl = new URL("/robots.txt", url);
  for (let hop = 0; hop < 3; hop++) {
    const response = await fetchPage(robotsUrl.href, {
      signal,
      maxBytes: 64_000,
    });
    if (response.status === 404) return true;
    if (response.status === 200)
      return robotsAllows(response.body.toString("utf8"), url.pathname);
    if (
      ![301, 302, 303, 307, 308].includes(response.status) ||
      !response.headers.location
    )
      return false;
    const next = new URL(response.headers.location, robotsUrl);
    if (next.origin !== url.origin) return false;
    robotsUrl = next;
  }
  return false;
}

export async function fetchArticle(
  input: string,
  fetchPage: WebFetch = safeFetch,
): Promise<Article> {
  let current = canonicalSource(input);
  const signal = AbortSignal.timeout(12_000);
  for (let hop = 0; current && hop < 3; hop++) {
    const url = new URL(current);
    if (!(await robotsAllowed(url, fetchPage, signal)))
      throw new ArticleRejected("robots_denied");
    const response = await fetchPage(current, { signal, maxBytes: 1_000_000 });
    if (
      [301, 302, 303, 307, 308].includes(response.status) &&
      response.headers.location
    ) {
      current = canonicalSource(
        new URL(response.headers.location, current).href,
      );
      continue;
    }
    if (
      response.status !== 200 ||
      !response.headers["content-type"]?.includes("html")
    )
      throw new ArticleRejected("not_html");
    const $ = load(response.body.toString("utf8"));
    const publishedAt = publicationDate($, "");
    $(
      "script,style,nav,footer,header,form,aside,.comments,[itemprop=author]",
    ).remove();
    $("p,div,br,h1,h2,h3,li").append("\n");
    const area = $("main,article,[role=main],#content.documentDetail").first();
    const text = (area.length ? area : $("body"))
      .text()
      .replace(/[^\S\n]+/g, " ")
      .slice(0, 16_000);
    return {
      sourceUrl: current,
      text,
      publishedAt: publishedAt ?? publicationDate($, text),
    };
  }
  throw new ArticleRejected(current ? "redirect_limit" : "unapproved_source");
}
