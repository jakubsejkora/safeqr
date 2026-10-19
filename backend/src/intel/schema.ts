import { createHash } from "node:crypto";
import { z } from "zod";
import type { Case, CodeKind, Indicator, Locale } from "../shared/schemas.js";

const sourceUrl = z
  .url()
  .max(2048)
  .regex(/^https?:\/\//);
const confidence = z.enum(["high", "medium", "low"]);
export const researchIndicatorSchema = z
  .object({
    type: z.enum([
      "domain",
      "url_pattern",
      "iban",
      "iban_pattern",
      "bank_account",
      "bank_account_pattern",
      "bank_code",
      "phone",
      "short_code",
      "crypto_address",
    ]),
    value: z.string().min(1).max(512),
    network: z.string().max(40).optional(),
    sourceUrl,
    evidence: z.string().min(1).max(240),
    confidence,
  })
  .strict();
export const researchCaseSchema = z
  .object({
    schemaVersion: z.literal("1.0"),
    id: z.string().regex(/^sqr_[a-f0-9]{64}$/),
    recordKind: z.enum([
      "observed_case",
      "reported_case",
      "general_warning",
      "simulation",
    ]),
    scamType: z.enum([
      "credential_phishing",
      "payment_redirection",
      "premium_sms",
      "account_linking",
      "malware_delivery",
      "fraudulent_subscription",
      "other",
      "unknown",
    ]),
    lure: z.string().max(240),
    channel: z.enum([
      "physical_sticker",
      "newspaper_ad",
      "postal_letter",
      "email_body",
      "email_attachment",
      "sms_mms",
      "messaging_app",
      "social_post",
      "website",
      "other",
      "unknown",
    ]),
    payloadType: z.enum([
      "url",
      "spd_payment",
      "sms",
      "tel",
      "wifi",
      "contact",
      "crypto",
      "login_code",
      "other",
      "unknown",
    ]),
    indicators: z.array(researchIndicatorSchema).max(40),
    location: z
      .object({
        countryCode: z
          .string()
          .regex(/^[A-Z]{2}$/)
          .nullable(),
        region: z.string().max(100).nullable(),
        city: z.string().max(100).nullable(),
      })
      .strict(),
    firstSeen: z.iso.date().nullable(),
    firstSeenSourceUrl: sourceUrl.nullable(),
    sourceUrl,
    sourcePublishedDate: z.iso.date().nullable(),
    summaryCs: z.string().min(1).max(400),
    summaryEn: z.string().min(1).max(400),
    confidence,
    evidenceNote: z.string().max(400),
  })
  .strict();
export type ResearchCase = z.infer<typeof researchCaseSchema>;
export interface IntelCase {
  record: ResearchCase;
  title: { cs: string; en: string };
}
export const hash = (text: string): string =>
  createHash("sha256").update(text).digest("hex");
export const caseId = (source: string): string =>
  `sqr_${hash(`${source}\nprimary`)}`;

export function validateCase(value: unknown): ResearchCase {
  const record = researchCaseSchema.parse(value);
  if ((record.firstSeen === null) !== (record.firstSeenSourceUrl === null))
    throw new Error("Inconsistent incident date");
  if (
    ["general_warning", "simulation"].includes(record.recordKind) &&
    (record.firstSeen || record.indicators.length)
  )
    throw new Error("Warnings cannot be indicators");
  if (
    record.indicators.some(
      (indicator) => indicator.type !== "crypto_address" && indicator.network,
    )
  )
    throw new Error("Unexpected network");
  if (
    new Set(
      record.indicators.map(
        (indicator) => `${indicator.type}:${indicator.value}`,
      ),
    ).size !== record.indicators.length
  )
    throw new Error("Duplicate indicators");
  return record;
}

const indicatorTypes: Partial<
  Record<ResearchCase["indicators"][number]["type"], Indicator["type"]>
> = {
  domain: "domain",
  url_pattern: "urlPattern",
  iban: "iban",
  phone: "phone",
  short_code: "shortCode",
  crypto_address: "cryptoAddress",
};
export function matchingIndicators(record: ResearchCase): Indicator[] {
  if (
    record.confidence !== "high" ||
    !["reported_case", "observed_case"].includes(record.recordKind)
  )
    return [];
  return record.indicators.flatMap((indicator) => {
    const type = indicatorTypes[indicator.type];
    return type && indicator.confidence === "high"
      ? [{ type, value: indicator.value }]
      : [];
  });
}
const payloadKinds: Partial<Record<ResearchCase["payloadType"], CodeKind>> = {
  url: "link",
  spd_payment: "payment",
  sms: "sms",
  tel: "phone",
  wifi: "wifi",
  contact: "contact",
  crypto: "crypto",
  login_code: "login",
};
export function publicCase(item: IntelCase, locale: Locale): Case {
  const record = item.record;
  if (!record.sourcePublishedDate)
    throw new Error("Publication date required for feed");
  return {
    id: record.id,
    title: item.title[locale],
    summary: locale === "cs" ? record.summaryCs : record.summaryEn,
    sourceUrl: record.sourceUrl,
    publishedAt: record.sourcePublishedDate,
    scamType: record.scamType,
    channel: record.channel,
    payloadKind: payloadKinds[record.payloadType],
    region: [
      record.location.city,
      record.location.region,
      record.location.countryCode,
    ]
      .filter(Boolean)
      .join(", "),
    indicators: matchingIndicators(record),
  };
}
