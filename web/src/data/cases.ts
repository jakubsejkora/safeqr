import type { Locale } from "../lib/locale.ts";
export interface Case {
  id: string;
  title: string;
  summary: string;
  sourceUrl: string;
  publishedAt: string;
  region?: string;
}
const records = [
  {
    id: "premium-sms-2026",
    publishedAt: "2026-09-28",
    region: "CZ",
    sourceUrl:
      "https://tn.nova.cz/zpravodajstvi/clanek/657902-nenapadny-podvod-v-telefonu-cesi-tydne-prichazeji-o-penize-za-falesne-predplatne",
    cs: [
      "Nenápadné předplatné za 99 Kč týdně",
      "Reportáž s Jankem Rubešem popisuje nechtěné předplatné. Falešné QR kódy jsou jednou z cest k jeho sjednání. Samotné načtení kódu platbu nepotvrzuje.",
    ],
    en: [
      "An unnoticed CZK 99 weekly subscription",
      "An interview with Janek Rubeš describes unwanted subscriptions. Fake QR codes are one route into the scheme. Scanning alone does not authorize a payment.",
    ],
  },
  {
    id: "bratislava-fines-2026",
    publishedAt: "2026-04-07",
    region: "SK",
    sourceUrl:
      "https://msp.bratislava.sk/novinka/130491/zachranili-sme-zivot-a-postarali-sa-o-stratene-dieta-zasahy-hliadok-303-542026",
    cs: [
      "Falešná pokuta za stěračem",
      "Bratislavská městská policie varovala před lístky vyžadujícími platbu přes QR kód. Pravý kód na oznámení slouží k informacím o dalším postupu.",
    ],
    en: [
      "A fake fine on the windscreen",
      "Bratislava municipal police warned about notices demanding payment through QR codes. Genuine notice codes provide information about the procedure.",
    ],
  },
  {
    id: "tax-refund-2025",
    publishedAt: "2025-10-30",
    region: "CZ",
    sourceUrl:
      "https://financnisprava.gov.cz/cs/financni-sprava/media-a-verejnost/tiskove-zpravy-gfr/tiskove-zpravy-2025/dalsi-intenzivni-vlna-podvodnych-emailu-a-sms",
    cs: [
      "Vrácení daně jako návnada",
      "Podvodný e-mail sliboval daňový přeplatek. QR kód vedl na falešný web, který chtěl přihlašovací údaje.",
    ],
    en: [
      "A tax refund as bait",
      "A fraudulent email promised a tax refund. Its QR code led to a fake website asking for login details.",
    ],
  },
  {
    id: "bratislava-parking-2025",
    publishedAt: "2025-05-06",
    region: "SK",
    sourceUrl:
      "https://msp.bratislava.sk/novinka/107621/boli-sme-sucastou-bratislavskych-mestskych-dni-a-riesili-falosne-nalepky-zasahy-hliadok-284-452025",
    cs: [
      "Přelepené parkovací terminály",
      "Městská policie popsala podvodné přelepky QR kódů. Posílaly řidiče na falešné stránky a k platbám na jiné účty.",
    ],
    en: [
      "Stickers over parking codes",
      "Municipal police reported fraudulent QR stickers on parking terminals. They directed drivers to fake pages and payments to other accounts.",
    ],
  },
  {
    id: "prague-parking-2024",
    publishedAt: "2024-11-26",
    region: "CZ",
    sourceUrl: "https://praha10.cz/varovani-pred-falesnymi-qr-kody-na-parkovacich-automatech/",
    cs: [
      "Falešné samolepky na automatech v Praze",
      "Padělané samolepky EasyPark vedly na falešné platební stránky. Technici nalezené samolepky odstraňovali.",
    ],
    en: [
      "Fake stickers on Prague parking meters",
      "Counterfeit EasyPark stickers led to fake payment websites. Technicians removed the stickers they found.",
    ],
  },
];
export function seedCases(locale: Locale): Case[] {
  return records.map(({ cs, en, ...record }) => {
    const copy = locale === "cs" ? cs : en;
    return { ...record, title: copy[0] ?? "", summary: copy[1] ?? "" };
  });
}
