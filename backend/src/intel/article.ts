import { load } from "cheerio";
import { safeFetch, type WebFetch } from "../shared/network.js";
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

export async function fetchArticle(
  input: string,
  fetchPage: WebFetch = safeFetch,
): Promise<Article | undefined> {
  let current = canonicalSource(input);
  const signal = AbortSignal.timeout(6000);
  for (let hop = 0; current && hop < 3; hop++) {
    const url = new URL(current);
    const robots = await fetchPage(`${url.origin}/robots.txt`, {
      signal,
      maxBytes: 64_000,
    });
    if (
      robots.status !== 404 &&
      (robots.status !== 200 ||
        !robotsAllows(robots.body.toString("utf8"), url.pathname))
    )
      return undefined;
    const response = await fetchPage(current, { signal });
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
      return undefined;
    const $ = load(response.body.toString("utf8"));
    const date =
      $("meta[property='article:published_time']").attr("content") ??
      $("time[datetime]").first().attr("datetime");
    $(
      "script,style,nav,footer,header,form,aside,.comments,[itemprop=author]",
    ).remove();
    const area = $("main,article,[role=main]").first();
    return {
      sourceUrl: current,
      text: (area.length ? area : $("body"))
        .text()
        .replace(/\s+/g, " ")
        .slice(0, 16_000),
      publishedAt: date?.match(/^\d{4}-\d{2}-\d{2}/)?.[0],
    };
  }
  return undefined;
}
