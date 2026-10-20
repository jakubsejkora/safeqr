import type { LinkReport } from "../../shared/schemas.js";
import type { StoredRequest } from "../../shared/storage.js";

export function effectiveDevice(request: StoredRequest, link?: LinkReport) {
  const findingIds = request.device.findingIds.filter(
    (id) =>
      !(id === "link.shortener" && link) &&
      !(id === "link.http" && link?.finalUrl.startsWith("https:")),
  );
  return {
    floor: request.device.floor,
    score: Math.max(
      request.device.floor,
      findingIds.length ? request.device.score : 0,
    ),
    findingIds,
  };
}

export function concealedRedirects(link?: LinkReport): boolean {
  const hops = link?.hops ?? [];
  return (
    new Set(hops.map((hop) => hop.url)).size >= 4 &&
    hops.some((hop) => hop.status && hop.status >= 300 && hop.status < 400) &&
    hops.some((hop) => hop.via === "meta") &&
    hops.some((hop) => hop.via === "javascript")
  );
}

/** Only a known registration age counts: a fake sticker can print a scammer's own domain. */
export function establishedDestination(link?: LinkReport): boolean {
  return (link?.domainAgeDays ?? 0) >= 365;
}
