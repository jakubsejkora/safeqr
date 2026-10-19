import { parseCases } from "../../worker/cases";

const feed = document.querySelector<HTMLElement>("[data-case-feed]");
if (feed) {
  const locale = feed.dataset.locale === "en" ? "en" : "cs";
  fetch(`/api/cases?locale=${locale}`, { signal: AbortSignal.timeout(6000) })
    .then(async (response) => {
      if (!response.ok) return;
      const data: unknown = await response.json();
      if (typeof data !== "object" || !data || !("source" in data) || data.source !== "live")
        return;
      const cases = parseCases(data);
      if (!cases) return;
      const list = feed.querySelector("[data-case-list]");
      const status = feed.querySelector("[data-feed-status]");
      if (!list || !status) return;
      const cards = cases.map((item) => {
        const article = document.createElement("article");
        article.className = "case-card";
        const meta = document.createElement("div");
        meta.className = "case-meta";
        const time = document.createElement("time");
        time.dateTime = item.publishedAt;
        time.textContent = new Intl.DateTimeFormat(locale === "cs" ? "cs-CZ" : "en-GB", {
          dateStyle: "medium",
        }).format(new Date(item.publishedAt));
        meta.append(time);
        const heading = document.createElement("h3");
        const link = document.createElement("a");
        link.href = item.sourceUrl;
        link.rel = "noreferrer";
        link.textContent = item.title;
        heading.append(link);
        const summary = document.createElement("p");
        summary.textContent = item.summary;
        const source = document.createElement("span");
        source.className = "case-source";
        source.textContent = new URL(item.sourceUrl).hostname;
        article.append(meta, heading, summary, source);
        return article;
      });
      list.replaceChildren(...cards);
      status.textContent =
        locale === "cs"
          ? cards.length
            ? "Aktuální případy ze zdrojového přehledu · obnovováno po 10 minutách"
            : "Zdrojový přehled nyní neobsahuje žádné případy."
          : cards.length
            ? "Latest cases from the source feed · refreshed every 10 minutes"
            : "The source feed currently contains no cases.";
    })
    .catch(() => {
      /* The server-rendered verified selection remains readable offline. */
    });
}
