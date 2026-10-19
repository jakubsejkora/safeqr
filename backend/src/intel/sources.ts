import actors from "../../data/actors.json" with { type: "json" };
import sources from "../../data/sources.json" with { type: "json" };

export { sources };
export const FACEBOOK_PAGE = "https://www.facebook.com/PolicieCZ/";
export function officialHost(host: string): boolean {
  return (
    sources.some((source) => source.allowedHosts.includes(host)) ||
    [
      "praha10.cz",
      "msp.bratislava.sk",
      "www.spp.sk",
      "paas.sk",
      "parking.praha.eu",
      "vph.zpspraha.cz",
    ].includes(host)
  );
}
export interface ActorJob {
  actor: string;
  build: string;
  input: Record<string, unknown>;
  capUsd: number;
  memory: number;
}

const pageFunction = String.raw`async function pageFunction(context) {
  const { $, request, customData } = context;
  const url = new URL(request.loadedUrl || request.url);
  const source = customData.sources.find(s => s.allowedHosts.includes(url.hostname));
  if (!source || url.protocol !== 'https:') return null;
  $('script, style, nav, footer, header, form, aside, [role="navigation"]').remove();
  const area = $('main, article, [role="main"]').first();
  const root = area.length ? area : $('body');
  if (request.userData.seed) {
    const links = new Set();
    root.find('a[href]').each((_, el) => {
      try {
        const u = new URL($(el).attr('href'), url.href);
        if (u.protocol !== 'https:' || !source.allowedHosts.includes(u.hostname)) return;
        if (!source.pathPrefixes.some(p => u.pathname.startsWith(p))) return;
        if (!/qr|quishing|podvod|phish|fale[sš]/i.test($(el).text() + u.pathname)) return;
        if (/\.(pdf|zip|jpg|png|docx?)$/i.test(u.pathname)) return;
        u.search = ''; u.hash = '';
        links.add(u.href);
      } catch {}
    });
    for (const link of [...links].slice(0, 2)) await context.enqueueRequest({url:link,userData:{seed:false}});
  }
  url.search = ''; url.hash = '';
  return {sourceUrl:url.href,isSeed:Boolean(request.userData.seed),hasQrMention:/\bqr\b|quishing/i.test(root.text())};
}`;

export function actorJobs(): ActorJob[] {
  return [
    {
      actor: actors.cheerio.id,
      build: actors.cheerio.build,
      capUsd: 0.2,
      memory: 1024,
      input: {
        startUrls: sources.map((source) => ({
          url: source.url,
          userData: { seed: true },
        })),
        respectRobotsTxtFile: true,
        linkSelector: "",
        pageFunction,
        proxyConfiguration: { useApifyProxy: false },
        maxPagesPerCrawl: 24,
        maxResultsPerCrawl: 24,
        maxCrawlingDepth: 1,
        maxConcurrency: 1,
        maxRequestRetries: 0,
        pageLoadTimeoutSecs: 12,
        pageFunctionTimeoutSecs: 5,
        debugLog: false,
        customData: { sources },
      },
    },
    {
      actor: actors.google.id,
      build: actors.google.build,
      capUsd: 0.5,
      memory: 1024,
      input: {
        queries:
          '"QR kód" podvod site:policie.gov.cz\n"falešné QR" site:financnisprava.gov.cz\nquishing Czech parking scam\nQR phishing official warning',
        maxPagesPerQuery: 1,
        countryCode: "cz",
        languageCode: "cs",
        saveHtml: false,
        saveHtmlToKeyValueStore: false,
        focusOnPaidAds: false,
        includeIcons: false,
      },
    },
    {
      actor: actors.facebook.id,
      build: actors.facebook.build,
      capUsd: 0.06,
      memory: 1024,
      input: { startUrls: [{ url: FACEBOOK_PAGE }], resultsLimit: 5 },
    },
  ];
}

export function canonicalSource(input: string): string | undefined {
  try {
    const url = new URL(input);
    if (url.protocol !== "https:" || url.username || url.password || url.port)
      return undefined;
    const source = sources.find((item) =>
      item.allowedHosts.includes(url.hostname),
    );
    const additional = ["praha10.cz", "msp.bratislava.sk", "www.spp.sk"];
    if (!source && !additional.includes(url.hostname)) return undefined;
    if (
      source &&
      !source.pathPrefixes.some((prefix) => url.pathname.startsWith(prefix))
    )
      return undefined;
    if (
      /\/profiles?\/|\/users?\/|\/login|\.(pdf|zip|jpg|jpeg|png)$/i.test(
        url.pathname,
      )
    )
      return undefined;
    url.search = "";
    url.hash = "";
    return url.href;
  } catch {
    return undefined;
  }
}
