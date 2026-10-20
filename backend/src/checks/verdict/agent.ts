import { z } from "zod";
import { MODELS } from "../../shared/config.js";
import type { Model } from "../../shared/model.js";
import { describePayload, redact } from "../../shared/privacy.js";
import {
  type Case,
  type Finding,
  findingSchema,
  type LinkReport,
  type SceneReport,
  scoreSchema,
  type Verdict,
  verdictSchema,
} from "../../shared/schemas.js";
import type { StoredRequest } from "../../shared/storage.js";
import { consequence, type Limitation, limitationText, say } from "./copy.js";
import { VERDICT_PROMPT } from "./prompt.v1.js";

export interface Evidence {
  link?: LinkReport;
  scene?: SceneReport;
  intel: Case[];
  limitations: Limitation[];
  downloads?: boolean;
}
const draftSchema = z.object({
  score: scoreSchema,
  findings: z
    .array(
      findingSchema.extend({
        title: z.string().max(90),
        detail: z.string().max(220),
      }),
    )
    .max(3),
  consequences: z.array(z.string().max(180)).max(2),
  limitations: z.array(z.string().max(180)).max(2),
});

export function deterministicVerdict(
  request: StoredRequest,
  evidence: Evidence,
  models: string[] = [],
): Verdict {
  const locale = request.locale;
  let score = Math.max(request.device.floor, request.device.score);
  const findings: Finding[] = [];
  const add = (
    id: string,
    risk: number,
    source: Finding["source"],
    cs: string,
    en: string,
    detailCs: string,
    detailEn: string,
  ) => {
    score = Math.max(score, risk);
    findings.push({
      id,
      severity: risk >= 70 ? "danger" : risk >= 30 ? "warning" : "info",
      source,
      title: say(locale, cs, en),
      detail: say(locale, detailCs, detailEn),
    });
  };
  if (score >= 30)
    add(
      "device-floor",
      score,
      "device",
      "Telefon našel varovné znaky",
      "Your phone found warning signs",
      "Varování z kontroly v telefonu zůstávají v platnosti.",
      "Warnings from the check on your phone still apply.",
    );
  if (evidence.intel.length)
    add(
      "known-scam",
      80,
      "intel",
      "Shoda se známým podvodem",
      "Match with a known scam",
      "Kód obsahuje údaj, který veřejný zdroj spojuje s podvodem.",
      "The code contains a detail that a public source links to a scam.",
    );
  if (evidence.link?.finalUrl.startsWith("http:"))
    add(
      "unencrypted",
      40,
      "sandbox",
      "Web nemá šifrované spojení",
      "The website connection is not encrypted",
      "Na této stránce nezadávejte hesla ani platební údaje.",
      "Do not enter passwords or payment details on this page.",
    );
  if (
    evidence.link?.asksFor?.some((item) =>
      ["password", "card", "bankLogin", "otp"].includes(item),
    )
  )
    add(
      "sensitive-request",
      40,
      "sandbox",
      "Web žádá citlivé údaje",
      "The website asks for sensitive details",
      "Než něco zadáte, ověřte si provozovatele jinou cestou.",
      "Check the operator another way before entering anything.",
    );
  const hops = evidence.link?.hops ?? [];
  if (
    evidence.link?.asksFor?.includes("card") &&
    new Set(hops.map((hop) => hop.url)).size >= 4 &&
    hops.some((hop) => hop.status && hop.status >= 300 && hop.status < 400) &&
    hops.some((hop) => hop.via === "meta") &&
    hops.some((hop) => hop.via === "javascript")
  )
    add(
      "concealed-card-form",
      75,
      "sandbox",
      "Odkaz skrývá cestu k údajům z karty",
      "The link hides the route to a card form",
      "Než se ukázal formulář pro kartu, odkaz vás několikrát přesměroval různými způsoby. Kartu nezadávejte, dokud si provozovatele neověříte jinou cestou.",
      "Several kinds of redirection led to a card form. Do not enter your card until you have checked the operator another way.",
    );
  if (
    evidence.scene?.tamperingSigns?.length &&
    evidence.link?.asksFor?.includes("card")
  )
    add(
      "covered-payment-code",
      80,
      "scene",
      "Přelepený kód vede k platbě kartou",
      "A covered code leads to a card payment",
      "Kód může překrývat původní značku a web žádá kartu. Platbu si ověřte přímo u provozovatele.",
      "The code may cover the original marking and the website asks for a card. Check the payment directly with the operator.",
    );
  if (
    evidence.link?.domainAgeDays !== undefined &&
    evidence.link.domainAgeDays < 30
  )
    add(
      "new-domain",
      45,
      "sandbox",
      "Webová adresa je nová",
      "The website address is new",
      "Nová adresa sama o sobě neznamená podvod. Buďte ale opatrní.",
      "A new address alone does not mean fraud. Take extra care.",
    );
  if (evidence.scene?.tamperingSigns?.length)
    add(
      "scene-tampering",
      60,
      "scene",
      "Kód může být přelepený",
      "The code may have been covered over",
      evidence.scene.summary,
      evidence.scene.summary,
    );
  if (evidence.scene?.matchesContent === false)
    add(
      "scene-mismatch",
      50,
      "scene",
      "Kód neodpovídá místu",
      "The code does not fit its location",
      evidence.scene.summary,
      evidence.scene.summary,
    );
  if (evidence.downloads)
    add(
      "download",
      40,
      "sandbox",
      "Web nabízí stažení souboru",
      "The website offers a download",
      "Soubor jsme neotevřeli ani nespustili.",
      "We did not open or run the file.",
    );
  if (evidence.limitations.includes("blocked"))
    add(
      "blocked-destination",
      70,
      "sandbox",
      "Tento odkaz neotevřeme",
      "We cannot safely open this link",
      "Cíl odkazu není běžná veřejná webová stránka.",
      "The destination is not an ordinary public website.",
    );
  if (
    evidence.limitations.some((key) =>
      [
        "model",
        "sandbox",
        "redirects",
        "intel",
        "scene",
        "browserModel",
      ].includes(key),
    )
  )
    score = Math.max(score, 30);
  return finalize(
    {
      score,
      level: "safe",
      headline: "",
      findings,
      consequences: [consequence(locale, request.kind)],
      limitations: [
        ...new Set([
          ...evidence.limitations,
          "noGuarantee" as const,
          "readOnly" as const,
        ]),
      ].map((key) => limitationText(locale, key)),
      models,
      link: evidence.link,
      scene: evidence.scene,
      intel: evidence.intel,
    },
    request,
  );
}

function finalize(verdict: Verdict, request: StoredRequest): Verdict {
  const score = Math.max(verdict.score, request.device.floor);
  const level = score < 30 ? "safe" : score < 70 ? "caution" : "danger";
  const headline =
    level === "safe"
      ? say(request.locale, "Vypadá bezpečně.", "Looks safe.")
      : level === "caution"
        ? say(request.locale, "Buďte opatrní.", "Be careful.")
        : say(request.locale, "Nebezpečné.", "Dangerous.");
  return verdictSchema.parse({ ...verdict, score, level, headline });
}

export async function createVerdict(
  request: StoredRequest,
  evidence: Evidence,
  model: Model,
): Promise<Verdict> {
  const baseline = deterministicVerdict(request, evidence);
  try {
    const draft = await model.ask({
      model: MODELS.sonnet,
      system: VERDICT_PROMPT,
      schema: draftSchema,
      maxTokens: 850,
      data: {
        locale: request.locale,
        kind: request.kind,
        payload: describePayload(request.kind, request.payload),
        device: request.device,
        existingFindings: baseline.findings,
        evidence: redact(
          JSON.stringify({
            ...evidence,
            link: evidence.link
              ? { ...evidence.link, screenshotUrl: undefined }
              : undefined,
          }),
        ),
      },
    });
    const supported = new Set([
      "ai",
      "device",
      ...(evidence.link ? ["sandbox"] : []),
      ...(evidence.scene ? ["scene"] : []),
      ...(evidence.intel.length ? ["intel"] : []),
    ]);
    return finalize(
      {
        ...baseline,
        score: Math.max(baseline.score, draft.score),
        findings: [
          ...baseline.findings,
          ...draft.findings
            .filter((finding) => supported.has(finding.source))
            .map((finding, index) => ({
              ...finding,
              id: `ai-${index}`,
              title: redact(finding.title),
              detail: redact(finding.detail),
            })),
        ],
        consequences: [
          ...new Set([
            ...baseline.consequences,
            ...draft.consequences.map(redact),
          ]),
        ],
        limitations: [
          ...new Set([
            ...baseline.limitations,
            ...draft.limitations.map(redact),
          ]),
        ],
        models: [...model.used],
      },
      request,
    );
  } catch {
    return deterministicVerdict(
      request,
      { ...evidence, limitations: [...evidence.limitations, "model"] },
      [...model.used],
    );
  }
}
