import type { APIRoute } from "astro";
import { routes } from "../lib/locale";
export const GET: APIRoute = () =>
  new Response(
    `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${Object.values(
      routes,
    )
      .flatMap((route) => Object.values(route))
      .map((path) => `<url><loc>https://safeqr.cz${path}</loc></url>`)
      .join("")}</urlset>`,
    { headers: { "Content-Type": "application/xml" } },
  );
