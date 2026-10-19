import type { CodeKind, Locale, Step } from "../../shared/schemas.js";

export const limitations = {
  redirects: [
    "Odkaz se nepodařilo sledovat až do konce.",
    "We could not follow the link all the way.",
  ],
  blocked: [
    "Odkaz vede na místo, které z bezpečnostních důvodů neotevřeme.",
    "The link points somewhere we cannot safely open.",
  ],
  sandbox: [
    "Web se nepodařilo prohlédnout v odděleném prohlížeči.",
    "We could not inspect the website in the separate browser.",
  ],
  restricted: [
    "Některé části webu byly zablokované. Další kroky mohou vypadat jinak.",
    "Some parts of the website were blocked. Later steps may look different.",
  ],
  browserModel: [
    "Automatické posouzení stránky nebylo dostupné.",
    "The automatic page assessment was unavailable.",
  ],
  scene: [
    "Fotografii okolí kódu se nepodařilo posoudit.",
    "We could not assess the photo around the code.",
  ],
  photoDeletion: [
    "Okamžité smazání fotografie se nepodařilo potvrdit. Záložní pravidlo ji zařadí ke smazání po jednom dni.",
    "We could not confirm immediate photo deletion. A backup rule schedules deletion after one day.",
  ],
  intel: [
    "Známé podvody se nepodařilo porovnat.",
    "We could not compare the code with known scams.",
  ],
  domain: [
    "Stáří webové adresy se nepodařilo zjistit.",
    "We could not find out how old the website address is.",
  ],
  model: [
    "Podrobné posouzení nebylo dostupné. Výsledek vychází ze zjištěných varovných znaků.",
    "The detailed assessment was unavailable. This result uses the warning signs we could check.",
  ],
  noGuarantee: [
    "Ani tato kontrola nemůže zaručit bezpečnost.",
    "This check cannot guarantee safety.",
  ],
  readOnly: [
    "Nic jsme nevyplnili, nezaplatili ani neodeslali.",
    "We did not fill in, pay or send anything.",
  ],
} as const;
export type Limitation = keyof typeof limitations;
export const say = (locale: Locale, cs: string, en: string): string =>
  locale === "cs" ? cs : en;
export const limitationText = (locale: Locale, key: Limitation): string =>
  limitations[key][locale === "cs" ? 0 : 1];

const consequences: Record<CodeKind, readonly [string, string]> = {
  link: [
    "Otevře se webová stránka. Ta může chtít údaje nebo platbu.",
    "A website will open. It may ask for details or payment.",
  ],
  payment: [
    "Bankovní aplikace může připravit platbu. Před potvrzením ověřte příjemce a částku.",
    "Your banking app may prepare a payment. Check the recipient and amount before confirming.",
  ],
  crypto: [
    "Peněženka může připravit převod. Po odeslání jej obvykle nelze vrátit.",
    "Your wallet may prepare a transfer. Once sent, it usually cannot be reversed.",
  ],
  sms: [
    "Otevře se připravená SMS. Její odeslání může stát peníze nebo zapnout předplatné.",
    "A prepared text message will open. Sending it may cost money or start a subscription.",
  ],
  phone: [
    "Telefon nabídne hovor. Volání na některá čísla může být drahé.",
    "Your phone will offer to make a call. Some numbers can be expensive to call.",
  ],
  email: [
    "Otevře se návrh e-mailu. Odešle se až po vašem potvrzení.",
    "An email draft will open. It is sent only when you confirm.",
  ],
  wifi: [
    "Telefon nabídne připojení k Wi-Fi. Provozovatel sítě může vidět část vašeho provozu.",
    "Your phone will offer to join Wi-Fi. The network owner may see some of your traffic.",
  ],
  contact: [
    "Telefon nabídne uložení kontaktu.",
    "Your phone will offer to save a contact.",
  ],
  event: [
    "Kalendář nabídne přidání události.",
    "Your calendar will offer to add an event.",
  ],
  location: [
    "V mapě se může otevřít uvedené místo.",
    "The location may open in a map.",
  ],
  messaging: [
    "Otevře se aplikace pro zprávy. Odeslání vyžaduje vaše rozhodnutí.",
    "A messaging app will open. Sending requires your decision.",
  ],
  login: [
    "Jiná aplikace může požádat o přihlášení nebo přístup k účtu.",
    "Another app may request sign-in or access to an account.",
  ],
  eSIM: [
    "Telefon může nabídnout přidání mobilního tarifu. Ověřte jeho poskytovatele.",
    "Your phone may offer to add a mobile plan. Check who provides it.",
  ],
  appLink: [
    "Otevře se jiná aplikace, která může nabídnout další krok.",
    "Another app will open and may offer a further action.",
  ],
  text: [
    "Zobrazí se text kódu. Samotné zobrazení nic neodesílá.",
    "The code's text will be shown. Showing it does not send anything.",
  ],
};
export const consequence = (locale: Locale, kind: CodeKind): string =>
  consequences[kind][locale === "cs" ? 0 : 1];

const stepLabels: Record<Step["id"], readonly [string, string]> = {
  redirects: ["Sledujeme, kam odkaz vede", "Following where the link goes"],
  sandbox: [
    "Prohlížíme web v odděleném prohlížeči",
    "Inspecting the website in a separate browser",
  ],
  scene: ["Prohlížíme okolí kódu", "Looking at the code's surroundings"],
  intel: ["Porovnáváme se známými podvody", "Comparing with known scams"],
  verdict: ["Připravujeme srozumitelný výsledek", "Preparing a clear result"],
};
export function progress(
  locale: Locale,
  id: Step["id"],
  status: Step["status"],
): Step {
  const prefix =
    status === "done"
      ? say(locale, "Hotovo: ", "Done: ")
      : status === "failed"
        ? say(locale, "Nedostupné: ", "Unavailable: ")
        : status === "skipped"
          ? say(locale, "Není potřeba: ", "Not needed: ")
          : "";
  return {
    id,
    status,
    label: prefix + stepLabels[id][locale === "cs" ? 0 : 1],
  };
}
