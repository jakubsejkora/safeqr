import type { Finding, Locale } from "../../shared/schemas.js";
import { say } from "../verdict/copy.js";
import type { SocialReport } from "./agent.js";
import type { LinkCategory } from "./links.js";

const names: Record<LinkCategory, [string, string]> = {
  adult: ["placený obsah pro dospělé", "paid adult content"],
  messaging: ["zprávy", "messaging"],
  payment: ["platby", "payments"],
  forwarder: ["další přesměrování", "another redirect"],
  crypto: ["kryptoměny nebo investice", "crypto or investments"],
  social: ["sociální sítě", "social media"],
  website: ["běžný web", "website"],
};

export function socialFindings(
  report: SocialReport,
  locale: Locale,
): { score: number; findings: Finding[] } {
  const findings: Finding[] = [];
  let score = 0;
  const add = (
    id: string,
    risk: number,
    cs: string,
    en: string,
    csDetail: string,
    enDetail: string,
  ) => {
    score = Math.max(score, risk);
    findings.push({
      id,
      severity: risk >= 30 ? "warning" : "info",
      source: "sandbox",
      title: say(locale, cs, en),
      detail: say(locale, csDetail, enDetail),
    });
  };
  const domains = (category: LinkCategory) =>
    [
      ...new Set(
        report.links
          .filter((link) => link.category === category)
          .map((link) => link.domain),
      ),
    ].join(", ");
  if (report.links.length) {
    const groups = [...new Set(report.links.map((link) => link.category))];
    const description = groups
      .map(
        (category) =>
          `${names[category][locale === "cs" ? 0 : 1]}: ${domains(category)}`,
      )
      .join("; ");
    add(
      "social-destinations",
      0,
      "Kam profil vede",
      "Where the profile leads",
      description,
      description,
    );
  }
  if (report.profile && !report.links.length)
    add(
      "social-profile-checked",
      0,
      "Veřejný profil jsme zkontrolovali",
      "We checked the public profile",
      "Apify ve veřejném profilu nenašlo odkazy na další weby. Obsah za přihlášením se může lišit.",
      "Apify found no links to other websites in the public profile. Content after sign-in may differ.",
    );
  if (domains("adult"))
    add(
      "social-adult",
      40,
      "Profil vede na placený obsah pro dospělé",
      "The profile leads to paid adult content",
      `Odkazy vedou na ${domains("adult")}. Služba může nabídnout placené předplatné. Samotný odkaz není důkaz podvodu.`,
      `Links lead to ${domains("adult")}. The service may offer a paid subscription. The link alone does not prove fraud.`,
    );
  if (domains("crypto"))
    add(
      "social-investment",
      40,
      "Profil vede ke kryptoměnám nebo investicím",
      "The profile leads to crypto or investments",
      `Odkazy vedou na ${domains("crypto")}. Můžete přijít o vložené peníze. Výnosy ani nabídku jsme neověřili.`,
      `Links lead to ${domains("crypto")}. You could lose the money you put in. We have not checked returns or offers.`,
    );
  if (report.unresolvedForwarders.length)
    add(
      "social-forwarder",
      40,
      "Další odkaz skrývá konečný cíl",
      "Another link hides the final destination",
      `Odkaz přes ${report.unresolvedForwarders.join(", ")} vede dál. Konečný cíl jsme neověřili.`,
      `A link through ${report.unresolvedForwarders.join(", ")} leads elsewhere. We have not checked the final destination.`,
    );
  if (domains("messaging") && (domains("adult") || domains("crypto")))
    add(
      "social-private-contact",
      40,
      "Nabídka pokračuje v soukromých zprávách",
      "The offer can continue in private messages",
      `Profil vedle této nabídky uvádí kontakt přes ${domains("messaging")}. Další zprávy ani požadavky na platbu nevidíme.`,
      `Alongside this offer, the profile links to ${domains("messaging")}. We cannot see later messages or payment requests.`,
    );
  if (report.profile?.verified && report.profile.business && domains("website"))
    add(
      "social-business",
      0,
      "Ověřený firemní profil uvádí web",
      "A verified business profile lists a website",
      `Apify uvádí ověřený firemní profil s odkazem na ${domains("website")}. Vlastnictví webu jsme nezávisle neověřili.`,
      `Apify reports a verified business profile linking to ${domains("website")}. Website ownership was not independently checked.`,
    );
  return { score, findings };
}
