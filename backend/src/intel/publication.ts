import type { CheerioAPI } from "cheerio";
import { z } from "zod";

const months = [
  "ledna|leden|január|januára",
  "února|únor|február|februára",
  "března|březen|marec|marca",
  "dubna|duben|apríl|apríla",
  "května|květen|máj|mája",
  "června|červen|jún|júna",
  "července|červenec|júl|júla",
  "srpna|srpen|august|augusta",
  "září|september|septembra",
  "října|říjen|október|októbra",
  "listopadu|listopad|november|novembra",
  "prosince|prosinec|december|decembra",
];

function date(value: string | undefined): string | undefined {
  if (!value) return undefined;
  let candidate = value.match(/^\s*(\d{4}-\d{2}-\d{2})/)?.[1];
  const local = value.match(/\b(\d{1,2})\.\s*(\d{1,2})\.\s*(20\d{2})\b/);
  if (!candidate && local)
    candidate = `${local[3]}-${local[2]?.padStart(2, "0")}-${local[1]?.padStart(2, "0")}`;
  if (!candidate) {
    for (const [month, names] of months.entries()) {
      const match = value.match(
        new RegExp(`\\b(\\d{1,2})\\.\\s*(?:${names})\\s+(20\\d{2})`, "i"),
      );
      if (match) {
        candidate = `${match[2]}-${String(month + 1).padStart(2, "0")}-${match[1]?.padStart(2, "0")}`;
        break;
      }
    }
  }
  return candidate &&
    z.iso.date().safeParse(candidate).success &&
    candidate <= new Date().toISOString().slice(0, 10)
    ? candidate
    : undefined;
}

function structuredDate(value: unknown, depth = 0): string | undefined {
  if (!value || typeof value !== "object" || depth > 6) return undefined;
  if ("datePublished" in value && typeof value.datePublished === "string")
    return date(value.datePublished);
  for (const child of Object.values(value)) {
    const found = structuredDate(child, depth + 1);
    if (found) return found;
  }
  return undefined;
}

/** Reads publication evidence; never substitutes a modification date or today's date. */
export function publicationDate(
  $: CheerioAPI,
  articleText: string,
): string | undefined {
  for (const selector of [
    "meta[property='article:published_time']",
    "meta[name='datePublished']",
    "[itemprop='datePublished']",
    "time[datetime]",
  ]) {
    const element = $(selector).first();
    const found = date(
      element.attr("content") ?? element.attr("datetime") ?? element.text(),
    );
    if (found) return found;
  }
  for (const element of $("script[type='application/ld+json']").toArray()) {
    try {
      const found = structuredDate(JSON.parse($(element).text()));
      if (found) return found;
    } catch {
      /* Invalid publisher metadata is not evidence. */
    }
  }
  // Page templates can include their own date before the article's metadata.
  for (const element of $("meta[name='date']").toArray().reverse()) {
    const found = date($(element).attr("content"));
    if (found) return found;
  }
  const paragraphs = articleText
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  const datedLine = paragraphs.find((line) =>
    /^\d{1,2}\.\s*(?:\d{1,2}\.|[\p{L}]+)\s*20\d{2}(?:\D|$)/u.test(line),
  );
  return date(datedLine);
}
