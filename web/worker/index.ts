import { getCases } from "./cases.ts";
import { secure } from "./security.ts";

interface Env {
  ASSETS: Fetcher;
  BACKEND_BASE_URL?: string;
}
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (url.hostname === "www.bezpecneqr.cz") {
      url.protocol = "https:";
      url.hostname = "bezpecneqr.cz";
      url.port = "";
      return secure(Response.redirect(url.toString(), 308));
    }
    if (!["GET", "HEAD"].includes(request.method))
      return secure(
        new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } }),
      );
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
      const response = await env.ASSETS.fetch(request);
      if (response.status === 404 && url.pathname.startsWith("/en/")) {
        const fallback = new URL("/en/404/", url);
        const localized = await env.ASSETS.fetch(new Request(fallback, request));
        return secure(new Response(localized.body, { status: 404, headers: localized.headers }));
      }
      if (url.pathname === "/404" || url.pathname === "/en/404/")
        return secure(new Response(response.body, { status: 404, headers: response.headers }));
      return secure(response);
    } catch {
      return secure(
        new Response(
          url.pathname.startsWith("/en/") ? "Temporarily unavailable" : "Dočasně nedostupné",
          { status: 503 },
        ),
      );
    }
  },
} satisfies ExportedHandler<Env>;
