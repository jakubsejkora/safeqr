export function secure(response: Response, demo = false): Response {
  const result = new Response(response.body, response);
  result.headers.set(
    "Content-Security-Policy",
    `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src ${demo ? "'none'" : "'self'"}; font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'`,
  );
  result.headers.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  result.headers.set("Referrer-Policy", "no-referrer");
  result.headers.set(
    "Permissions-Policy",
    "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
  );
  result.headers.set("X-Content-Type-Options", "nosniff");
  result.headers.set("X-Frame-Options", "DENY");
  if (demo) result.headers.set("X-Robots-Tag", "noindex, nofollow");
  return result;
}
