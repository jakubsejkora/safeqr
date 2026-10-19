import { load } from "cheerio";
import { LIMITS } from "../../shared/config.js";
import {
  safeFetch,
  UnsafeUrl,
  type WebFetch,
  webUrl,
} from "../../shared/network.js";
import type { LinkReport } from "../../shared/schemas.js";

export interface TraceResult {
  report?: LinkReport;
  limitation?: "blocked" | "unavailable" | "hopLimit";
}

export async function traceLink(
  input: string,
  fetchPage: WebFetch = safeFetch,
): Promise<TraceResult> {
  const hops: LinkReport["hops"] = [];
  const visited = new Set<string>();
  let current = input;
  let via: "http" | "meta" = "http";
  const signal = AbortSignal.timeout(6500);
  try {
    for (let index = 0; index < LIMITS.hops; index++) {
      const url = webUrl(current).href;
      if (visited.has(url))
        return { report: { finalUrl: url, hops }, limitation: "hopLimit" };
      visited.add(url);
      const response = await fetchPage(url, { signal });
      hops.push({ url, via, status: response.status });
      if (
        [301, 302, 303, 307, 308].includes(response.status) &&
        response.headers.location
      ) {
        current = new URL(response.headers.location, url).href;
        via = "http";
        continue;
      }
      const $ = load(
        response.headers["content-type"]?.includes("html")
          ? response.body.toString("utf8")
          : "",
      );
      const refresh =
        response.headers.refresh ??
        $("meta[http-equiv]")
          .filter(
            (_, element) =>
              $(element).attr("http-equiv")?.toLowerCase() === "refresh",
          )
          .first()
          .attr("content");
      const target = refresh
        ?.match(/(?:^|;)\s*url\s*=\s*['"]?([^'"]+)/i)?.[1]
        ?.trim();
      if (target) {
        current = new URL(target, url).href;
        via = "meta";
        continue;
      }
      return {
        report: {
          finalUrl: url,
          hops,
          ...($("title").text()
            ? { pageTitle: $("title").text().trim().slice(0, 200) }
            : {}),
        },
      };
    }
    return {
      report: { finalUrl: hops.at(-1)?.url ?? webUrl(input).href, hops },
      limitation: "hopLimit",
    };
  } catch (error) {
    return {
      ...(hops.length
        ? { report: { finalUrl: hops.at(-1)?.url ?? input, hops } }
        : {}),
      limitation: error instanceof UnsafeUrl ? "blocked" : "unavailable",
    };
  }
}
