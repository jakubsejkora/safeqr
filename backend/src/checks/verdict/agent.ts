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
import type { SocialReport } from "../social/agent.js";
import { socialFindings } from "../social/findings.js";
import {
  concealedRedirects,
  effectiveDevice,
  establishedDestination,
} from "./calibration.js";
import { consequence, type Limitation, limitationText, say } from "./copy.js";
import { VERDICT_PROMPT } from "./prompt.v3.js";

export interface Evidence {
  link?: LinkReport;
  scene?: SceneReport;
  intel: Case[];
  limitations: Limitation[];
  downloads?: boolean;
  destinationUnavailable?: boolean;
  social?: SocialReport;
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
  let score = effectiveDevice(request, evidence.link).score;
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
  const requested = evidence.link?.asksFor ?? [];
  const requestRisk =
    (evidence.link?.domainAgeDays !== undefined &&
      evidence.link.domainAgeDays < 365) ||
    evidence.link?.finalUrl.startsWith("http:") ||
    Boolean(evidence.scene?.tamperingSigns?.length) ||
    evidence.scene?.matchesContent === false ||
    evidence.intel.length > 0 ||
    concealedRedirects(evidence.link);
  if (requested.length) {
    const sensitive = requested.some((item) =>
      [
        "password",
        "card",
        "bankLogin",
        "otp",
        "phone",
        "personalData",
        "payment",
      ].includes(item),
    );
    const names = {
      password: ["heslo", "a password"],
      card: ["údaje z karty", "card details"],
      bankLogin: ["přihlášení k bance", "bank sign-in"],
      otp: ["ověřovací kód", "a verification code"],
      phone: ["telefonní číslo", "a phone number"],
      personalData: ["osobní údaje", "personal details"],
      payment: ["platbu", "a payment"],
      appInstall: ["instalaci aplikace", "an app installation"],
      permission: ["udělení oprávnění", "permission"],
    } as const;
    const details = requested
      .map((item) => names[item][locale === "cs" ? 0 : 1])
      .join(", ");
    add(
      sensitive && requestRisk ? "sensitive-request" : "page-request",
      sensitive && requestRisk ? 40 : 0,
      "sandbox",
      sensitive && requestRisk
        ? "Údaje žádá web s varovnými znaky"
        : "Co po vás web žádá",
      sensitive && requestRisk
        ? "The request comes with warning signs"
        : "What the website asks for",
      `Web žádá: ${details}.${sensitive && requestRisk ? " Před zadáním si ověřte provozovatele." : " Samotná žádost není známkou podvodu."}`,
      `The website asks for ${details}.${sensitive && requestRisk ? " Check the operator before entering anything." : " The request alone is not a sign of fraud."}`,
    );
  }
  if (
    evidence.link?.asksFor?.includes("card") &&
    concealedRedirects(evidence.link)
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
      "Web nabízí program nebo archiv",
      "The website offers a program or archive",
      "Stažený soubor může spustit program. Neotevřeli jsme jej ani nespustili.",
      "The downloaded file may run a program. We did not open or run it.",
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
  if (evidence.destinationUnavailable)
    add(
      "destination-unavailable",
      30,
      "sandbox",
      "Cílový web se nepodařilo otevřít",
      "The destination could not be opened",
      "Nemohli jsme zjistit, co po vás cílová stránka žádá. Zkuste kontrolu později.",
      "We could not see what the destination asks for. Try the check again later.",
    );
  if (evidence.social) {
    const social = socialFindings(evidence.social, locale);
    score = Math.max(score, social.score);
    findings.push(...social.findings);
  }
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
        device: effectiveDevice(request, evidence.link),
        establishedDestination: establishedDestination(evidence.link),
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
      ...(evidence.link || evidence.social ? ["sandbox"] : []),
      ...(evidence.scene ? ["scene"] : []),
      ...(evidence.intel.length ? ["intel"] : []),
    ]);
    const additions = draft.findings
      .filter((finding) => supported.has(finding.source))
      // Login walls and ordinary profile redirects add no risk without independent evidence.
      .filter(
        (finding) =>
          !evidence.social ||
          baseline.score >= 30 ||
          finding.severity === "info",
      )
      .map((finding, index) => ({
        ...finding,
        id: `ai-${index}`,
        title: redact(finding.title),
        detail: redact(finding.detail),
      }));
    // A numerical increase must have an accompanying explanation, even on model fallback.
    const explainedScore = additions.some(
      (finding) => finding.severity !== "info",
    )
      ? draft.score
      : draft.score < 30
        ? draft.score
        : baseline.score;
    return finalize(
      {
        ...baseline,
        score: Math.max(baseline.score, explainedScore),
        findings: [...baseline.findings, ...additions],
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
