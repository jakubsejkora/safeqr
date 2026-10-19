import { getCases } from "./cases.ts";
import { secure } from "./security.ts";

interface Env {
  ASSETS: Fetcher;
  BACKEND_BASE_URL?: string;
}
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (!["GET", "HEAD"].includes(request.method))
      return secure(
        new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } }),
      );
    const url = new URL(request.url);
    if (url.pathname === "/api/cases") {
      const locale = url.searchParams.get("locale") ?? "cs";
      if (!["cs", "en"].includes(locale))
        return secure(Response.json({ error: "Unsupported locale" }, { status: 400 }));
      const key = new Request(`${url.origin}/api/cases?locale=${locale}`);
      const cache = caches.default;
      let response = await cache.match(key);
      if (!response) {
        response = await getCases(locale === "en" ? "en" : "cs", env.BACKEND_BASE_URL);
        ctx.waitUntil(cache.put(key, response.clone()));
      }
      return secure(request.method === "HEAD" ? new Response(null, response) : response);
    }
    try {
      return secure(await env.ASSETS.fetch(request));
    } catch {
      return secure(new Response("Temporarily unavailable", { status: 503 }));
    }
  },
} satisfies ExportedHandler<Env>;
