import { z } from "zod";

export const localeSchema = z.enum(["cs", "en"]);
export const kindSchema = z.enum([
  "link",
  "payment",
  "crypto",
  "sms",
  "phone",
  "email",
  "wifi",
  "contact",
  "event",
  "location",
  "messaging",
  "login",
  "eSIM",
  "appLink",
  "text",
]);
export const severitySchema = z.enum(["info", "warning", "danger"]);
export const levelSchema = z.enum(["safe", "caution", "danger"]);
export const scoreSchema = z.number().int().min(0).max(100);
export const checkIdSchema = z.string().regex(/^chk_[A-Za-z0-9]{20,}$/);
export const sceneInputSchema = z.object({
  image: z.string().max(2_000_000),
  source: z.enum(["ultraWideCamera", "camera", "photo"]),
  codeBounds: z
    .object({
      x: z.number(),
      y: z.number(),
      width: z.number(),
      height: z.number(),
    })
    .optional(),
});
export const requestSchema = z.object({
  payload: z.string().max(4096),
  kind: kindSchema,
  locale: localeSchema,
  device: z.object({
    score: scoreSchema,
    floor: scoreSchema,
    findingIds: z.array(z.string()),
  }),
  scene: sceneInputSchema.optional(),
});
export const stepSchema = z.object({
  id: z.enum(["redirects", "sandbox", "scene", "intel", "verdict"]),
  status: z.enum(["pending", "running", "done", "skipped", "failed"]),
  label: z.string(),
});
export const findingSchema = z.object({
  id: z.string(),
  severity: severitySchema,
  title: z.string(),
  detail: z.string(),
  source: z.enum(["device", "sandbox", "scene", "intel", "ai"]),
});
export const asksForSchema = z.enum([
  "password",
  "card",
  "bankLogin",
  "phone",
  "otp",
  "personalData",
  "payment",
  "appInstall",
  "permission",
]);
export const linkSchema = z.object({
  finalUrl: z.url(),
  hops: z.array(
    z.object({
      url: z.url(),
      status: z.number().int().optional(),
      via: z.enum(["http", "meta", "javascript"]),
    }),
  ),
  pageTitle: z.string().optional(),
  screenshotUrl: z.url().optional(),
  domainAgeDays: z.number().int().optional(),
  asksFor: z.array(asksForSchema).optional(),
});
export const sceneSchema = z.object({
  setting: z.string().optional(),
  tamperingSigns: z.array(z.string()).optional(),
  matchesContent: z.boolean().optional(),
  summary: z.string(),
});
export const indicatorSchema = z.object({
  type: z.enum([
    "domain",
    "urlPattern",
    "iban",
    "phone",
    "shortCode",
    "cryptoAddress",
  ]),
  value: z.string(),
});
export const caseSchema = z.object({
  id: z.string(),
  title: z.string(),
  summary: z.string(),
  sourceUrl: z.url(),
  publishedAt: z.iso.date(),
  scamType: z.string().optional(),
  channel: z.string().optional(),
  payloadKind: kindSchema.optional(),
  region: z.string().optional(),
  indicators: z.array(indicatorSchema).optional(),
});
export const verdictSchema = z.object({
  score: scoreSchema,
  level: levelSchema,
  headline: z.string(),
  findings: z.array(findingSchema),
  consequences: z.array(z.string()),
  limitations: z.array(z.string()),
  models: z.array(z.string()),
  link: linkSchema.optional(),
  scene: sceneSchema.optional(),
  intel: z.array(caseSchema).optional(),
});
export const checkSchema = z.object({
  id: z.string(),
  status: z.enum(["running", "completed", "failed"]),
  steps: z.array(stepSchema),
  result: verdictSchema.optional(),
});
export const acceptedSchema = z.object({
  id: z.string(),
  status: z.literal("running"),
  pollAfterMs: z.number().int(),
});
export type Locale = z.infer<typeof localeSchema>;
export type CheckRequest = z.infer<typeof requestSchema>;
export type CodeKind = z.infer<typeof kindSchema>;
export type Step = z.infer<typeof stepSchema>;
export type Check = z.infer<typeof checkSchema>;
export type Verdict = z.infer<typeof verdictSchema>;
export type Finding = z.infer<typeof findingSchema>;
export type LinkReport = z.infer<typeof linkSchema>;
export type SceneReport = z.infer<typeof sceneSchema>;
export type Case = z.infer<typeof caseSchema>;
export type Indicator = z.infer<typeof indicatorSchema>;
