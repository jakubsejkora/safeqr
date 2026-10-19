import { getDomain } from "tldts";
import { safeFetch, type WebFetch } from "../../shared/network.js";

/** Reads registration events without retaining RDAP contact records. */
export async function domainAge(
  input: string,
  fetchPage: WebFetch = safeFetch,
): Promise<number | undefined> {
  const hostname = new URL(input).hostname;
  const domain = getDomain(hostname, {
    allowPrivateDomains: false,
  });
  if (!domain) return undefined;
  // A hosting provider's age says nothing about a customer's newly created site.
  if (getDomain(hostname, { allowPrivateDomains: true }) !== domain)
    return undefined;
  const signal = AbortSignal.timeout(3000);
  try {
    let url = `https://rdap.org/domain/${encodeURIComponent(domain)}`;
    for (let hop = 0; hop < 4; hop++) {
      const response = await fetchPage(url, { signal, maxBytes: 256_000 });
      if (
        [301, 302, 303, 307, 308].includes(response.status) &&
        response.headers.location
      ) {
        url = new URL(response.headers.location, url).href;
        continue;
      }
      if (response.status !== 200) return undefined;
      const data: unknown = JSON.parse(response.body.toString("utf8"));
      if (
        !data ||
        typeof data !== "object" ||
        !("events" in data) ||
        !Array.isArray(data.events)
      )
        return undefined;
      const event = data.events.find(
        (entry: unknown) =>
          entry &&
          typeof entry === "object" &&
          "eventAction" in entry &&
          entry.eventAction === "registration",
      );
      if (!event || typeof event.eventDate !== "string") return undefined;
      const date = Date.parse(event.eventDate);
      return Number.isFinite(date) && date <= Date.now()
        ? Math.floor((Date.now() - date) / 86_400_000)
        : undefined;
    }
  } catch {
    return undefined;
  }
  return undefined;
}
