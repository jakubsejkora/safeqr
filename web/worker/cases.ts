import { type Case, seedCases } from "../src/data/cases.ts";
import type { Locale } from "../src/lib/locale.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
export function parseCases(value: unknown): Case[] | null {
  if (!isRecord(value) || !Array.isArray(value.cases) || value.cases.length > 50) return null;
  const cases: Case[] = [];
  for (const item of value.cases) {
    if (!isRecord(item)) return null;
    const { id, title, summary, sourceUrl, publishedAt } = item;
    if (
      typeof id !== "string" ||
      !id ||
      id.length > 150 ||
      typeof title !== "string" ||
      !title ||
      title.length > 250 ||
      typeof summary !== "string" ||
      !summary ||
      summary.length > 2000 ||
      typeof sourceUrl !== "string" ||
      sourceUrl.length > 2000 ||
      typeof publishedAt !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(publishedAt) ||
      !Number.isFinite(Date.parse(publishedAt))
    )
      return null;
    try {
      const url = new URL(sourceUrl);
      if (url.protocol !== "https:" || url.username || url.password) return null;
    } catch {
      return null;
    }
    cases.push({ id, title, summary, sourceUrl, publishedAt });
  }
  return cases.sort((a, b) => b.publishedAt.localeCompare(a.publishedAt)).slice(0, 5);
}

export async function getCases(
  locale: Locale,
  backend: string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  let cases = seedCases(locale);
  let source = "seed";
  if (backend) {
    try {
      const base = new URL(backend);
      if (base.protocol !== "https:" || base.username || base.password)
        throw new Error("Invalid backend");
      const url = new URL("/v1/cases", base);
      url.searchParams.set("locale", locale);
      url.searchParams.set("limit", "5");
      const upstream = await fetcher(url, {
        signal: AbortSignal.timeout(3500),
        redirect: "error",
        headers: { Accept: "application/json" },
      });
      if (!upstream.ok || !upstream.headers.get("content-type")?.includes("application/json"))
        throw new Error("Invalid response");
      const reader = upstream.body?.getReader();
      if (!reader) throw new Error("Missing body");
      const chunks: Uint8Array[] = [];
      let length = 0;
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) break;
        length += chunk.value.length;
        if (length > 65536) {
          await reader.cancel();
          throw new Error("Response too large");
        }
        chunks.push(chunk.value);
      }
      const bytes = new Uint8Array(length);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.length;
      }
      const parsed = parseCases(JSON.parse(new TextDecoder().decode(bytes)));
      if (!parsed) throw new Error("Invalid cases");
      cases = parsed;
      source = "live";
    } catch {
      // An unavailable feed must not remove the verified public warnings.
    }
  }
  return Response.json(
    { cases, source, ...(source === "seed" ? { reviewedAt: "2026-10-19" } : {}) },
    { headers: { "Cache-Control": "public, max-age=600" } },
  );
}
