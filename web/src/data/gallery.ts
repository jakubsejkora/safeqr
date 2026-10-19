import type { Locale } from "../lib/locale.ts";
export const DEMO_ORIGIN = "https://safeqr-training.jakub-f9d.workers.dev";
export const EXAMPLE_IBAN = "CZ6508000000192000145399";
export type Category = "links" | "payments" | "phone" | "access" | "combinations";
interface Copy {
  title: string;
  context?: string;
}
export interface GalleryEntry {
  id: string;
  category: Category;
  payload: string;
  cs: Copy;
  en: Copy;
  secondPayload?: string;
  arrangement?: "nested" | "sticker" | "side";
}
export const gallery: GalleryEntry[] = [
  {
    id: "normal-link",
    category: "links",
    payload: "https://example.com",
    cs: {
      title: "Obyčejný odkaz",
    },
    en: {
      title: "An ordinary link",
    },
  },
  {
    id: "redirect-chain",
    category: "links",
    payload: `${DEMO_ORIGIN}/start`,
    cs: {
      title: "Odkaz s několika zastávkami",
      context:
        "Cvičný web přesměruje návštěvníka na platební formulář. Samotná adresa to neprozradí; k odhalení je potřeba cloudová kontrola.",
    },
    en: {
      title: "A link with several stops",
      context:
        "The training website redirects to a payment form. The address alone does not reveal this; a cloud check is needed.",
    },
  },
  {
    id: "lookalike",
    category: "links",
    payload: "https://xn--pple-43d.test",
    cs: {
      title: "Písmeno, které vypadá jinak",
    },
    en: {
      title: "A lookalike letter",
    },
  },
  {
    id: "user-host",
    category: "links",
    payload: "https://bank.example@example.com",
    cs: {
      title: "Banka před zavináčem",
    },
    en: {
      title: "The bank before the @",
    },
  },
  {
    id: "http",
    category: "links",
    payload: "http://example.com",
    cs: {
      title: "Nešifrovaný odkaz",
    },
    en: {
      title: "An unencrypted link",
    },
  },
  {
    id: "javascript",
    category: "links",
    payload: "javascript:void(0)",
    cs: {
      title: "Kód místo webové adresy",
    },
    en: {
      title: "Code instead of a web address",
    },
  },
  {
    id: "data-uri",
    category: "links",
    payload: "data:text/plain,SAFE%20QR%20TRAINING",
    cs: {
      title: "Stránka schovaná v kódu",
    },
    en: {
      title: "A page inside the code",
    },
  },
  {
    id: "qr-platba",
    category: "payments",
    payload: "SPD*1.0*ACC:CZ6508000000192000145399*AM:1.00*CC:CZK*MSG:SAFE QR DEMO - NEPLATIT",
    cs: {
      title: "QR Platba: zkontrolujte příjemce",
    },
    en: {
      title: "QR Platba: check the recipient",
    },
  },
  {
    id: "payment-link",
    category: "combinations",
    payload:
      "SPD*1.0*ACC:CZ6508000000192000145399*AM:1.00*CC:CZK*MSG:SAFE QR DEMO - NEPLATIT*X-URL:https://example.com",
    cs: {
      title: "Platba s odkazem navíc",
    },
    en: {
      title: "Payment with an extra link",
    },
  },
  {
    id: "swapped-account",
    category: "payments",
    payload:
      "SPD*1.0*ACC:CZ6508000000192000145399*AM:1.00*CC:CZK*MSG:SAFE QR DEMO - NEPLATIT*RN:DEMO PARKING",
    cs: {
      title: "Parkovné na jiný účet",
      context:
        "Cvičný scénář: někdo nahradil účet provozovatele jiným. Ze samotného kódu nelze zjistit, komu má platba patřit.",
    },
    en: {
      title: "Parking with a swapped account",
      context:
        "Training scenario: someone has replaced the operator’s account. The code alone cannot tell who should receive the payment.",
    },
  },
  {
    id: "epc-sepa",
    category: "payments",
    payload: "BCD\n002\n1\nSCT\n\nSAFE QR DEMO\nCZ6508000000192000145399\nEUR1\n\n\nDO NOT PAY",
    cs: {
      title: "Evropská platba SEPA",
    },
    en: {
      title: "A European SEPA payment",
    },
  },
  {
    id: "foreign-iban",
    category: "payments",
    payload:
      "BCD\n002\n1\nSCT\n\nSAFE QR INVALID EXAMPLE\nDE00000000000000000000\nEUR1\n\n\nDO NOT PAY",
    cs: {
      title: "SEPA: zahraniční účet",
    },
    en: {
      title: "SEPA: a foreign account",
    },
  },
  {
    id: "pay-by-square",
    category: "payments",
    payload:
      "0804Q0006GO413BG9LBBE3A19QOLF1IL5KKN3ME7GCNSBO8APJ5VT40EJG2Q3EQKCK9TBFM7B6NNA5VJ5JT2DG0F8KNI8V6M01FCSKMEMAL2B36GTM45VVP2BO000",
    cs: {
      title: "PAY by square",
    },
    en: {
      title: "PAY by square",
    },
  },
  {
    id: "crypto",
    category: "payments",
    payload: "bitcoin:SAFE_QR_INVALID_DEMO_ADDRESS?amount=0.001&label=Donation",
    cs: {
      title: "Dar v kryptoměně",
    },
    en: {
      title: "A crypto donation",
    },
  },
  {
    id: "premium-sms",
    category: "phone",
    payload: "SMSTO:90X00:START",
    cs: {
      title: "SMS, která může spustit předplatné",
      context: "90X00 je záměrně neplatné cvičné číslo. Z této ukázky nelze určit cenu SMS.",
    },
    en: {
      title: "An SMS that can start a subscription",
      context:
        "90X00 is a deliberately invalid training number. This example cannot establish an SMS price.",
    },
  },
  {
    id: "premium-call",
    category: "phone",
    payload: "tel:+420900000",
    cs: {
      title: "Drahý telefonát",
      context: "Číslo je záměrně neúplné. Ukázka neumožňuje určit cenu hovoru.",
    },
    en: {
      title: "A premium-rate call",
      context: "The number is deliberately incomplete. This example cannot establish a call price.",
    },
  },
  {
    id: "call-forwarding",
    category: "phone",
    payload: "tel:**21*+420000000000%23",
    cs: {
      title: "Přesměrování hovorů",
    },
    en: {
      title: "Call forwarding",
    },
  },
  {
    id: "open-wifi",
    category: "access",
    payload: "WIFI:T:nopass;S:SafeQR-TRAINING-NO-NETWORK;;",
    cs: {
      title: "Wi-Fi bez hesla",
    },
    en: {
      title: "Wi-Fi without a password",
    },
  },
  {
    id: "wep-wifi",
    category: "access",
    payload: "WIFI:T:WEP;S:SafeQR-TRAINING-WEP;P:0000000000;;",
    cs: {
      title: "Wi-Fi se slabou ochranou",
    },
    en: {
      title: "Wi-Fi with weak protection",
    },
  },
  {
    id: "bank-contact",
    category: "access",
    payload:
      "BEGIN:VCARD\nVERSION:3.0\nFN:DEMO Bank Security - NOT A REAL BANK\nTEL:+420000000000\nEND:VCARD",
    cs: {
      title: "„Bezpečnostní linka banky“",
    },
    en: {
      title: "“Bank security” contact",
    },
  },
  {
    id: "whatsapp-login",
    category: "access",
    payload:
      "2@SAFE-QR-INVALID-TRAINING,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    cs: {
      title: "Přihlášení do WhatsApp Web",
    },
    en: {
      title: "WhatsApp Web login",
    },
  },
  {
    id: "telegram-login",
    category: "access",
    payload: "tg://login?token=INVALID_SAFE_QR_TRAINING",
    cs: {
      title: "Přihlášení do Telegramu",
    },
    en: {
      title: "Telegram login",
    },
  },
  {
    id: "auth-export",
    category: "access",
    payload: "otpauth-migration://offline?data=EAEYASAAKAA%3D",
    cs: {
      title: "Export ověřovacích klíčů",
    },
    en: {
      title: "Authenticator export",
    },
  },
  {
    id: "esim",
    category: "access",
    payload: "LPA:1$esim.test$INVALID-SAFE-QR-TRAINING",
    cs: {
      title: "Aktivace eSIM",
    },
    en: {
      title: "eSIM activation",
    },
  },
  {
    id: "enterprise-app",
    category: "access",
    payload:
      "itms-services://?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fdemo%2Fno-app.plist",
    cs: {
      title: "Aplikace mimo App Store",
    },
    en: {
      title: "An app outside the App Store",
    },
  },
  {
    id: "profile",
    category: "access",
    payload: "https://example.com/demo/no-profile.mobileconfig",
    cs: {
      title: "Nastavení, které mění telefon",
    },
    en: {
      title: "A profile that changes your phone",
    },
  },
  {
    id: "nested",
    category: "combinations",
    payload: "https://example.com",
    cs: {
      title: "QR kód uvnitř QR kódu",
      context:
        "Velký kód A má uprostřed menší kód B. Oba hodnotíme zvlášť; samotný text kódu neprozradí, kde jsou umístěné.",
    },
    en: {
      title: "A QR code inside a QR code",
      context:
        "The large code A has a smaller code B in its center. Each is assessed separately; their decoded text cannot reveal the arrangement.",
    },
    secondPayload: "https://example.com/B",
    arrangement: "nested",
  },
  {
    id: "sticker",
    category: "combinations",
    payload: "https://example.com/original",
    cs: {
      title: "Samolepka přes původní kód",
      context:
        "Kód B na samolepce překrývá původní kód A. Přelepení lze posoudit z fotky okolí, ne ze samotného textu kódu.",
    },
    en: {
      title: "A sticker over the original",
      context:
        "Code B on a sticker covers the original code A. A scene photo can reveal the sticker; decoded text alone cannot.",
    },
    secondPayload: `${DEMO_ORIGIN}/start`,
    arrangement: "sticker",
  },
  {
    id: "hidden-text",
    category: "combinations",
    payload: "Parkovani zdarma / Free parking\n​https://example.com/demo/payment",
    cs: {
      title: "Text s nenápadným odkazem",
    },
    en: {
      title: "Text with a hidden payload",
    },
  },
  {
    id: "side-by-side",
    category: "combinations",
    payload: "https://example.com/official",
    cs: {
      title: "Dva kódy vedle sebe",
      context:
        "Kód A je vlevo, kód B vpravo. Čtečka může vybrat jiný kód, než na který míříte. Každý proto hodnotíme zvlášť.",
    },
    en: {
      title: "Two codes side by side",
      context:
        "Code A is on the left and code B on the right. A reader may select a different code than intended, so each is assessed separately.",
    },
    secondPayload: `${DEMO_ORIGIN}/start`,
    arrangement: "side",
  },
];
export const categories: Record<Category, Record<Locale, string>> = {
  links: {
    cs: "Odkazy",
    en: "Links",
  },
  payments: {
    cs: "Platby",
    en: "Payments",
  },
  phone: {
    cs: "SMS a volání",
    en: "SMS & calls",
  },
  access: {
    cs: "Přístup a nastavení",
    en: "Access & settings",
  },
  combinations: {
    cs: "Kombinace",
    en: "Combinations",
  },
};
