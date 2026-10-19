import { z } from "zod";
import { MODELS } from "../shared/config.js";
import type { Model } from "../shared/model.js";
import { redactArticle } from "../shared/privacy.js";
import type { Article } from "./article.js";
import { EXTRACT_PROMPT } from "./prompt.v1.js";
import {
  caseId,
  type IntelCase,
  type ResearchCase,
  researchCaseSchema,
  validateCase,
} from "./schema.js";
import { officialHost } from "./sources.js";

const extractionSchema = z.object({
  isQuishing: z.boolean(),
  privacySafe: z.boolean(),
  titleCs: z.string().max(100),
  titleEn: z.string().max(100),
  case: researchCaseSchema.omit({ id: true }).nullable(),
});
interface FraudCandidate {
  token: string;
  value: string;
  type: ResearchCase["indicators"][number]["type"];
}

export function prepareArticle(article: Article): {
  text: string;
  candidates: FraudCandidate[];
} {
  const candidates: FraudCandidate[] = [];
  let text = article.text;
  const pattern =
    /(?:podvodn[áéýou]+|falešn[áéýou]+|fraudulent|malicious|fake)\s+(?:webov[áéýou]+\s+)?(domén[ayěu]|web|domain|website|iban|účet|account|telefonní číslo|phone number|short code|shortcode|crypto address)\s*[:–-]?\s*[„“"']?((?:https?:\/\/)?[A-Za-z0-9.+:/_-]{4,200})/gi;
  text = text.replace(
    pattern,
    (whole, kind: string, raw: string, offset: number) => {
      const context = article.text.slice(Math.max(0, offset - 80), offset);
      if (
        /\b(?:not|never|není|nebyla|nebyl|nikoli|nikoliv)\s*$/i.test(
          context.trim(),
        )
      )
        return whole;
      const type = /iban|účet|account/i.test(kind)
        ? "iban"
        : /phone|telefon/i.test(kind)
          ? "phone"
          : /short/i.test(kind)
            ? "short_code"
            : /crypto/i.test(kind)
              ? "crypto_address"
              : "domain";
      let value = raw.replace(/[.,;]+$/, "");
      if (type === "domain") {
        try {
          const url = new URL(
            value.includes("://") ? value : `https://${value}`,
          );
          if (!url.hostname.includes(".") || officialHost(url.hostname))
            return whole;
          value = url.hostname;
        } catch {
          return whole;
        }
      }
      if (type === "iban" && !/^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/i.test(value))
        return whole;
      if (
        ["phone", "short_code"].includes(type) &&
        !/^\+?\d{3,15}$/.test(value)
      )
        return whole;
      if (candidates.length >= 12) return whole;
      const token = `[FRAUD_INDICATOR_${candidates.length}]`;
      candidates.push({ token, value, type });
      return whole.replace(raw, token);
    },
  );
  // Narrow the model input to relevant statements instead of forwarding a whole public article.
  const sentences = text.match(/[^.!?\n]+(?:[.!?]|$)/g) ?? [];
  const relevant = sentences.filter((sentence) =>
    /\bqr\b|quishing|FRAUD_INDICATOR|podvod|phish|falešn|fraud|scam|sticker|nálepk/i.test(
      sentence,
    ),
  );
  return { text: redactArticle(relevant.join(" ").slice(0, 8000)), candidates };
}

export async function extractCase(
  article: Article,
  model: Model,
): Promise<IntelCase | undefined> {
  const prepared = prepareArticle(article);
  if (!/\bqr\b|quishing/i.test(prepared.text)) return undefined;
  const output = await model.ask({
    model: MODELS.haiku,
    system: EXTRACT_PROMPT,
    schema: extractionSchema,
    maxTokens: 1700,
    data: {
      sourceUrl: article.sourceUrl,
      publishedAt: article.publishedAt ?? null,
      text: prepared.text,
      indicators: prepared.candidates.map(({ token, type }) => ({
        token,
        type,
      })),
    },
  });
  if (
    !output.isQuishing ||
    !output.privacySafe ||
    !output.case ||
    !article.publishedAt
  )
    return undefined;
  const indicators = output.case.indicators.flatMap((indicator) => {
    const candidate = prepared.candidates.find(
      (item) => item.token === indicator.value && item.type === indicator.type,
    );
    return candidate && indicator.confidence === "high"
      ? [
          {
            ...indicator,
            value: candidate.value,
            sourceUrl: article.sourceUrl,
            evidence: redactArticle(indicator.evidence),
          },
        ]
      : [];
  });
  const firstSeen =
    output.case.firstSeen && prepared.text.includes(output.case.firstSeen)
      ? output.case.firstSeen
      : null;
  const record = validateCase({
    ...output.case,
    id: caseId(article.sourceUrl),
    sourceUrl: article.sourceUrl,
    sourcePublishedDate: article.publishedAt,
    indicators,
    firstSeen,
    firstSeenSourceUrl: firstSeen ? article.sourceUrl : null,
    summaryCs: redactArticle(output.case.summaryCs),
    summaryEn: redactArticle(output.case.summaryEn),
    evidenceNote: redactArticle(output.case.evidenceNote),
    lure: redactArticle(output.case.lure),
  });
  if (record.confidence === "low" || record.recordKind === "simulation")
    return undefined;
  return {
    record,
    title: {
      cs: redactArticle(output.titleCs),
      en: redactArticle(output.titleEn),
    },
  };
}
