import { secure } from "../worker/security.ts";
import { bioPage, bioStyle } from "./bio.ts";

const style = `:root{color-scheme:light dark;font:18px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f5f6f8;color:#182525}*{box-sizing:border-box}body{margin:0}.notice{position:sticky;top:0;z-index:1;background:#f7e6ab;color:#493400;padding:16px;text-align:center;font-weight:650}main{max-width:580px;margin:56px auto;padding:28px}h1{font-size:40px;line-height:1.1;letter-spacing:-1.5px}label{display:block;margin:20px 0 5px}input{font:inherit;width:100%;padding:14px;border:1px solid #6b7777;border-radius:8px;background:transparent;color:inherit}button,a{font:inherit}button{width:100%;margin-top:24px;padding:15px;background:#175b48;color:white;border:0;border-radius:10px;cursor:pointer}a{color:inherit}small{display:block}output{display:block;margin-top:20px;font-weight:650}input:focus-visible,button:focus-visible,a:focus-visible{outline:3px solid #a26a00;outline-offset:4px}@media(prefers-color-scheme:dark){:root{background:#152321;color:#edf5f2}}`;
const script = `const form=document.querySelector('form');form?.addEventListener('submit',event=>event.preventDefault());document.querySelector('button')?.addEventListener('click',()=>{form?.reset();document.querySelector('output').textContent='Training complete. Nothing was sent or paid. / Hotovo. Nic se neodeslalo ani nezaplatilo.';});`;
function page(title: string, content: string, head = ""): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>${title} · Safe QR training</title><link rel="stylesheet" href="/style.css">${head}</head><body><aside class="notice">Safe QR training page · Cvičná stránka<br><small>No real payments. Do not enter real details. / Nezadávejte skutečné údaje.</small></aside><main>${content}</main></body></html>`;
}
export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (!["GET", "HEAD"].includes(request.method))
      return secure(
        new Response("This training page accepts no data.", {
          status: 405,
          headers: { Allow: "GET, HEAD" },
        }),
        true,
      );
    let body: string | null;
    let status = 200;
    let type = "text/html; charset=utf-8";
    const headers = new Headers({ "Cache-Control": "no-store" });
    switch (url.pathname) {
      case "/bio":
      case "/bio/":
        body = bioPage;
        break;
      case "/bio.css":
        type = "text/css; charset=utf-8";
        body = bioStyle;
        break;
      case "/":
      case "/start":
        status = 302;
        headers.set("Location", "/step-2");
        body = page(
          "Training redirect",
          '<h1>Training redirect</h1><a href="/step-2">Continue / Pokračovat</a>',
        );
        break;
      case "/step-2":
        body = page(
          "Checking your parking zone",
          '<h1>Checking your parking zone…</h1><p>Training redirect 2 of 3.</p><a href="/step-3">Continue / Pokračovat</a>',
          '<meta http-equiv="refresh" content="1;url=/step-3">',
        );
        break;
      case "/step-3":
        body = page(
          "Opening payment",
          '<h1>Opening payment…</h1><p>Training redirect 3 of 3.</p><a href="/pay">Continue / Pokračovat</a><script src="/redirect.js"></script>',
        );
        break;
      case "/redirect.js":
        type = "text/javascript; charset=utf-8";
        body = 'window.location.replace("/pay");';
        break;
      case "/form.js":
        type = "text/javascript; charset=utf-8";
        body = script;
        break;
      case "/style.css":
        type = "text/css; charset=utf-8";
        body = style;
        break;
      case "/pay":
        body = page(
          "Pay for parking",
          `<p>DEMO PARKING · ZONE A</p><h1>Pay for parking<br>Zaplatit parkování</h1><p>1 hour / 1 hodina · 40 Kč</p><p>This is a demonstration of a suspicious payment page reached through several redirects.</p><form autocomplete="off"><label for="card">Card number / Číslo karty</label><input id="card" inputmode="numeric" maxlength="19" placeholder="0000 0000 0000 0000"><label for="expiry">Expiry / Platnost</label><input id="expiry" maxlength="5" placeholder="MM/YY"><label for="security">Security code / Bezpečnostní kód</label><input id="security" inputmode="numeric" maxlength="4" placeholder="000"><button type="button">Finish training / Dokončit ukázku</button><output aria-live="polite"></output></form><p><small>The form has no payment service. It sends and stores nothing. / Formulář nic neodesílá ani neukládá.</small></p><script src="/form.js"></script>`,
        );
        break;
      case "/robots.txt":
        type = "text/plain";
        body = "User-agent: *\nDisallow: /";
        break;
      default:
        status = 404;
        body = page("Not found", '<h1>Page not found</h1><a href="/start">Start training</a>');
    }
    headers.set("Content-Type", type);
    if (request.method === "HEAD") body = null;
    return secure(new Response(body, { status, headers }), true);
  },
} satisfies ExportedHandler;
