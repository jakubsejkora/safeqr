import { CurrencyCode, encode, PaymentOptions } from "bysquare/pay";
import type { Locale } from "../lib/locale.ts";
export const DEMO_ORIGIN = "https://safeqr-training.jakub-f9d.workers.dev";
export const EXAMPLE_IBAN = "CZ6508000000192000145399";
export type Category = "links" | "payments" | "phone" | "access" | "combinations";
interface Copy {
  title: string;
  reason: string;
  action: string;
  limitation: string;
}
export interface GalleryEntry {
  id: string;
  category: Category;
  payload: string;
  score: number;
  cs: Copy;
  en: Copy;
  secondPayload?: string;
  arrangement?: "nested" | "sticker" | "side";
}
const entry = (
  id: string,
  category: Category,
  payload: string,
  score: number,
  cs: [string, string, string, string],
  en: [string, string, string, string],
  extra: Partial<GalleryEntry> = {},
): GalleryEntry => ({
  id,
  category,
  payload,
  score,
  cs: { title: cs[0], reason: cs[1], action: cs[2], limitation: cs[3] },
  en: { title: en[0], reason: en[1], action: en[2], limitation: en[3] },
  ...extra,
});
const spd = `SPD*1.0*ACC:${EXAMPLE_IBAN}*AM:1.00*CC:CZK*MSG:SAFE QR DEMO - NEPLATIT`;
const bankLimit = "Z kódu nelze ověřit majitele účtu. Ukázkový účet z dokumentace ČNB. Neplaťte.";
const bankLimitEn =
  "A code cannot prove account ownership. ČNB documentation example account. Do not pay.";
export const gallery: GalleryEntry[] = [
  entry(
    "normal-link",
    "links",
    "https://example.com",
    8,
    [
      "Obyčejný odkaz",
      "Adresa je čitelná. Spojení používá HTTPS.",
      "Otevře web example.com.",
      "HTTPS samo nepotvrzuje poctivost webu.",
    ],
    [
      "An ordinary link",
      "The address is readable and uses HTTPS.",
      "Opens example.com.",
      "HTTPS alone does not prove a site is honest.",
    ],
  ),
  entry(
    "redirect-chain",
    "links",
    `${DEMO_ORIGIN}/start`,
    65,
    [
      "Odkaz s několika zastávkami",
      "Cvičný odkaz projde třemi přesměrováními až k platebnímu formuláři.",
      "Otevře cvičnou stránku žádající údaje z karty.",
      "Cíl odhalí až hloubková kontrola.",
    ],
    [
      "A link with several stops",
      "The training link follows three redirects to a card form.",
      "Opens a training page asking for card details.",
      "Only a deep check reveals the destination.",
    ],
  ),
  entry(
    "lookalike",
    "links",
    "https://xn--pple-43d.test",
    75,
    [
      "Písmeno, které vypadá jinak",
      "Adresa obsahuje znak podobný běžnému písmenu. Může napodobovat známý web.",
      "Pokusí se otevřít neexistující doménu .test.",
      "Podobnost názvu sama nedokazuje podvod.",
    ],
    [
      "A lookalike letter",
      "The address uses a character that resembles a familiar letter.",
      "Attempts to open a reserved .test domain.",
      "A similar name alone does not prove fraud.",
    ],
  ),
  entry(
    "user-host",
    "links",
    "https://bank.example@example.com",
    80,
    [
      "Banka před zavináčem",
      "Skutečný web je až za @: example.com. Část bank.example je návnada.",
      "Otevře example.com, nikoli bank.example.",
      "Jméno před @ neříká, komu web patří.",
    ],
    [
      "The bank before the @",
      "The actual host follows @: example.com. The bank name is a distraction.",
      "Opens example.com, not bank.example.",
      "Text before @ does not identify the website owner.",
    ],
  ),
  entry(
    "http",
    "links",
    "http://example.com",
    40,
    [
      "Nešifrovaný odkaz",
      "Adresa začíná http://. První spojení není šifrované.",
      "Otevře web bez zaručeného zabezpečení prvního spojení.",
      "Web může později přesměrovat na HTTPS.",
    ],
    [
      "An unencrypted link",
      "The address starts with http://. The first connection is unencrypted.",
      "Opens a site without protecting the first connection.",
      "The site may later redirect to HTTPS.",
    ],
  ),
  entry(
    "javascript",
    "links",
    "javascript:void(0)",
    90,
    [
      "Kód místo webové adresy",
      "Předpona javascript: může spouštět příkazy. Tato ukázka nedělá nic.",
      "Běžný prohlížeč ji může odmítnout.",
      "Záleží na aplikaci, která kód otevře.",
    ],
    [
      "Code instead of a web address",
      "The javascript: prefix can run commands. This example does nothing.",
      "A normal browser may refuse it.",
      "Behavior depends on the app opening it.",
    ],
  ),
  entry(
    "data-uri",
    "links",
    "data:text/plain,SAFE%20QR%20TRAINING",
    70,
    [
      "Stránka schovaná v kódu",
      "Obsah je přímo v QR kódu. Nemá běžnou adresu, kterou lze ověřit.",
      "Zobrazí pouze text SAFE QR TRAINING.",
      "Vlastníka takového obsahu nelze určit.",
    ],
    [
      "A page inside the code",
      "The content is embedded in the QR. There is no normal website address to check.",
      "Displays only SAFE QR TRAINING.",
      "The content has no verifiable website owner.",
    ],
  ),
  entry(
    "qr-platba",
    "payments",
    spd,
    25,
    [
      "QR Platba: zkontrolujte příjemce",
      "Platba 1 Kč na ukázkový účet. Není zde další odkaz.",
      "Vyplní platební příkaz. Odeslání vyžaduje potvrzení v bance.",
      bankLimit,
    ],
    [
      "QR Platba: check the recipient",
      "A CZK 1 payment to the example account. No extra link.",
      "Fills in a transfer. Sending requires confirmation in your bank.",
      bankLimitEn,
    ],
  ),
  entry(
    "payment-link",
    "combinations",
    `${spd}*X-URL:https://example.com`,
    70,
    [
      "Platba s odkazem navíc",
      "Pole X-URL obsahuje webový odkaz vedle platebních údajů.",
      "Podle čtečky nabídne platbu nebo další web.",
      bankLimit,
    ],
    [
      "Payment with an extra link",
      "The X-URL field hides a web link beside payment details.",
      "Depending on the reader, offers a payment or an extra website.",
      bankLimitEn,
    ],
  ),
  entry(
    "swapped-account",
    "payments",
    `${spd}*RN:DEMO PARKING`,
    75,
    [
      "Parkovné na jiný účet",
      "Scénář: účet v QR kódu nesouhlasí s účtem ověřeným u provozovatele.",
      "Připraví platbu na účet z kódu, i když samolepka říká něco jiného.",
      bankLimit,
    ],
    [
      "Parking with a swapped account",
      "Scenario: the QR account differs from the account independently confirmed by the operator.",
      "Prepares a payment to the encoded account, regardless of the sticker.",
      bankLimitEn,
    ],
  ),
  entry(
    "epc-sepa",
    "payments",
    `BCD\n002\n1\nSCT\n\nSAFE QR DEMO\n${EXAMPLE_IBAN}\nEUR1\n\n\nDO NOT PAY`,
    35,
    [
      "Evropská platba SEPA",
      "Platba 1 EUR na český ukázkový účet v evropském formátu EPC.",
      "Připraví eurovou platbu.",
      bankLimit,
    ],
    [
      "A European SEPA payment",
      "EUR 1 to the Czech example account in EPC format.",
      "Prepares a euro transfer.",
      bankLimitEn,
    ],
  ),
  entry(
    "foreign-iban",
    "payments",
    "BCD\n002\n1\nSCT\n\nSAFE QR INVALID EXAMPLE\nDE00000000000000000000\nEUR1\n\n\nDO NOT PAY",
    70,
    [
      "SEPA: zahraniční účet",
      "Předpona DE označuje Německo. Tento záměrně neplatný účet nelze použít k platbě.",
      "Bankovní aplikace by měla neplatný IBAN odmítnout.",
      "Cizí země sama není důkaz podvodu. Kvůli bezpečnosti používáme neplatný IBAN.",
    ],
    [
      "SEPA: a foreign account",
      "DE indicates Germany. This deliberately invalid account cannot receive a payment.",
      "A banking app should reject the invalid IBAN.",
      "A foreign country alone is not fraud. This example uses an invalid IBAN for safety.",
    ],
  ),
  entry(
    "pay-by-square",
    "payments",
    encode({
      payments: [
        {
          type: PaymentOptions.PaymentOrder,
          amount: 1,
          currencyCode: CurrencyCode.EUR,
          beneficiary: { name: "SAFE QR DEMO" },
          bankAccounts: [{ iban: EXAMPLE_IBAN }],
          paymentNote: "DO NOT PAY",
        },
      ],
    }),
    35,
    [
      "PAY by square",
      "Slovenský formát platebního QR kódu. Uvnitř je 1 EUR a ukázkový účet.",
      "Podporovaná aplikace vyplní platbu.",
      bankLimit,
    ],
    [
      "PAY by square",
      "A Slovak payment QR format containing EUR 1 and the example account.",
      "A compatible app fills in a payment.",
      bankLimitEn,
    ],
  ),
  entry(
    "crypto",
    "payments",
    "bitcoin:SAFE_QR_INVALID_DEMO_ADDRESS?amount=0.001&label=Donation",
    75,
    [
      "Dar v kryptoměně",
      "Kryptoměnový převod obvykle nejde vzít zpět. Ukázková adresa je záměrně neplatná.",
      "Peněženka by měla neplatnou adresu odmítnout.",
      "Z kódu nelze ověřit příjemce ani účel daru.",
    ],
    [
      "A crypto donation",
      "Crypto transfers are generally irreversible. This example address is deliberately invalid.",
      "A wallet should reject the invalid address.",
      "A code cannot verify the recipient or the donation purpose.",
    ],
  ),
  entry(
    "premium-sms",
    "phone",
    "SMSTO:90X00:START",
    90,
    [
      "SMS, která může spustit předplatné",
      "START na placené krátké číslo může objednat službu. 90X00 je neplatný příklad, ne skutečné číslo.",
      "Připraví zprávu START. Neodesílejte ji.",
      "Cenu a opakování plateb samotný příkaz neprozradí.",
    ],
    [
      "An SMS that can start a subscription",
      "START to a premium short code may order a service. 90X00 is an invalid example.",
      "Prepares START as a message. Do not send it.",
      "The command alone does not reveal price or recurring charges.",
    ],
  ),
  entry(
    "premium-call",
    "phone",
    "tel:+420900000",
    85,
    [
      "Drahý telefonát",
      "Předpona 900 se používá pro drahé hovory. Číslo je záměrně neúplné.",
      "Pokusí se otevřít telefon s neúplným číslem.",
      "Přesnou cenu nelze určit z této ukázky.",
    ],
    [
      "A premium-rate call",
      "900 is a Czech premium-rate prefix. The number is deliberately incomplete.",
      "Attempts to open the dialer with an incomplete number.",
      "This example cannot establish a call price.",
    ],
  ),
  entry(
    "call-forwarding",
    "phone",
    "tel:**21*+420000000000%23",
    95,
    [
      "Přesměrování hovorů",
      "Příkaz **21* může změnit, kam chodí vaše hovory. Cílové číslo je neplatné.",
      "Může otevřít telefonní příkaz. Nepotvrzujte jej.",
      "Podpora příkazů závisí na telefonu a operátorovi.",
    ],
    [
      "Call forwarding",
      "The **21* command can change where your calls go. The destination number is invalid.",
      "May open a phone command. Do not confirm it.",
      "Command support depends on the phone and carrier.",
    ],
  ),
  entry(
    "open-wifi",
    "access",
    "WIFI:T:nopass;S:SafeQR-TRAINING-NO-NETWORK;;",
    55,
    [
      "Wi-Fi bez hesla",
      "Síť je otevřená. Ukázková síť se zde nevysílá.",
      "Nabídne připojení k uvedené Wi-Fi.",
      "Kód nepotvrzuje, kdo síť provozuje.",
    ],
    [
      "Wi-Fi without a password",
      "This is an open network. No such training network is broadcast here.",
      "Offers to join the named Wi-Fi.",
      "A code cannot prove who operates the network.",
    ],
  ),
  entry(
    "wep-wifi",
    "access",
    "WIFI:T:WEP;S:SafeQR-TRAINING-WEP;P:0000000000;;",
    70,
    [
      "Wi-Fi se slabou ochranou",
      "Zastaralé zabezpečení WEP nestačí k ochraně sítě. Síť je pouze ukázková.",
      "Nabídne připojení k síti s WEP.",
      "Neznáme skutečného provozovatele sítě.",
    ],
    [
      "Wi-Fi with weak protection",
      "Outdated WEP protection is weak. This network is a training example.",
      "Offers to join a WEP network.",
      "The network operator is unknown.",
    ],
  ),
  entry(
    "bank-contact",
    "access",
    "BEGIN:VCARD\nVERSION:3.0\nFN:DEMO Bank Security - NOT A REAL BANK\nTEL:+420000000000\nEND:VCARD",
    75,
    [
      "„Bezpečnostní linka banky“",
      "Název kontaktu si může napsat kdokoli. Ukázkové číslo je neplatné.",
      "Nabídne uložení kontaktu s důvěryhodně znějícím jménem.",
      "Telefon ověřte v oficiální aplikaci banky.",
    ],
    [
      "“Bank security” contact",
      "Anyone can choose a contact name. This example phone number is invalid.",
      "Offers to save a contact with a reassuring name.",
      "Verify numbers in your official banking app.",
    ],
  ),
  entry(
    "whatsapp-login",
    "access",
    "2@SAFE-QR-INVALID-TRAINING,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    85,
    [
      "Přihlášení do WhatsApp Web",
      "Formát žádosti o propojení WhatsApp Web. Reference je neplatná a klíče jsou vyplněné nulami.",
      "WhatsApp má cvičnou žádost odmítnout. Skutečný kód může propojit cizí zařízení.",
      "Není to platný přihlašovací token WhatsApp.",
    ],
    [
      "WhatsApp Web login",
      "A WhatsApp Web device-linking format. The reference is invalid and the key fields are all zeros.",
      "WhatsApp should reject this training request. A real code can link another device.",
      "This is not a valid WhatsApp login token.",
    ],
  ),
  entry(
    "telegram-login",
    "access",
    "tg://login?token=INVALID_SAFE_QR_TRAINING",
    85,
    [
      "Přihlášení do Telegramu",
      "Předpona tg://login označuje přihlašovací žádost. Token je záměrně neplatný.",
      "Může předat žádost Telegramu, který ji má odmítnout.",
      "U skutečného kódu ověřte, čí zařízení připojujete.",
    ],
    [
      "Telegram login",
      "tg://login marks a login request. This token is deliberately invalid.",
      "May hand a request to Telegram, which should reject it.",
      "With a real code, verify whose device you are linking.",
    ],
  ),
  entry(
    "auth-export",
    "access",
    "otpauth-migration://offline?data=EAEYASAAKAA%3D",
    95,
    [
      "Export ověřovacích klíčů",
      "Tento formát může obsahovat klíče pro přihlášení k účtům. Ukázka žádné klíče nemá.",
      "Ověřovací aplikace může zkusit importovat prázdný balíček.",
      "Skutečný export nikdy nesdílejte ani nefotografujte pro cizí lidi.",
    ],
    [
      "Authenticator export",
      "This format can contain account login secrets. The example contains no secrets.",
      "An authenticator may attempt to import an empty package.",
      "Never share a real export with someone else.",
    ],
  ),
  entry(
    "esim",
    "access",
    "LPA:1$esim.test$INVALID-SAFE-QR-TRAINING",
    70,
    [
      "Aktivace eSIM",
      "Kód slouží k přidání mobilního tarifu. Adresa .test ani aktivační kód nefungují.",
      "Může otevřít nastavení mobilního tarifu.",
      "Pravý aktivační kód patří jen vám.",
    ],
    [
      "eSIM activation",
      "This code adds a mobile plan. The .test address and activation code do not work.",
      "May open mobile-plan settings.",
      "A real activation code is private.",
    ],
  ),
  entry(
    "enterprise-app",
    "access",
    "itms-services://?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fdemo%2Fno-app.plist",
    90,
    [
      "Aplikace mimo App Store",
      "Kód žádá instalaci podnikové aplikace. Ukázkový odkaz žádnou aplikaci nenabízí.",
      "Může otevřít instalační dialog.",
      "Bez prověření aplikace neznáme její chování.",
    ],
    [
      "An app outside the App Store",
      "Requests an enterprise app installation. The example does not provide an app.",
      "May open an installation prompt.",
      "Its behavior cannot be known without checking the app.",
    ],
  ),
  entry(
    "profile",
    "access",
    "https://example.com/demo/no-profile.mobileconfig",
    90,
    [
      "Nastavení, které mění telefon",
      "Přípona .mobileconfig může znamenat profil s oprávněním měnit nastavení. Ukázka žádný profil nenabízí.",
      "Otevře ukázkovou adresu. Pravý profil může měnit připojení i důvěru telefonu.",
      "Přípona sama neříká, co je uvnitř.",
    ],
    [
      "A profile that changes your phone",
      "A .mobileconfig file can change device settings. No profile is provided here.",
      "Opens an example URL. A real profile may change connections or trust settings.",
      "The extension alone does not reveal its contents.",
    ],
  ),
  entry(
    "nested",
    "combinations",
    "https://example.com",
    70,
    [
      "QR kód uvnitř QR kódu",
      "Velký kód ukazuje A. Uprostřed je druhý, menší kód B. Zkuste jej přiblížit.",
      "A otevře example.com. B otevře example.com/B.",
      "Čtečka nemusí oba kódy rozpoznat. Velký kód využívá opravu chyb.",
    ],
    [
      "A QR code inside a QR code",
      "The large code gives A. A smaller code B sits in its center. Try zooming in.",
      "A opens example.com. B opens example.com/B.",
      "Some readers may miss one code. The outer code relies on error correction.",
    ],
    { secondPayload: "https://example.com/B", arrangement: "nested" },
  ),
  entry(
    "sticker",
    "combinations",
    "https://example.com/original",
    80,
    [
      "Samolepka přes původní kód",
      "Menší samolepka překrývá původní QR. Fotka okolí může odhalit její okraje.",
      "Viditelný nový kód vede do cvičného platebního scénáře.",
      "Ze samotného dekódovaného textu přelepení nepoznáme.",
    ],
    [
      "A sticker over the original",
      "A smaller sticker covers the original QR. A scene photo may reveal its edges.",
      "The visible new code leads to the training payment flow.",
      "Decoded text alone cannot reveal the sticker.",
    ],
    { secondPayload: `${DEMO_ORIGIN}/start`, arrangement: "sticker" },
  ),
  entry(
    "hidden-text",
    "combinations",
    "Parkovani zdarma / Free parking\n\u200bhttps://example.com/demo/payment",
    65,
    [
      "Text s nenápadným odkazem",
      "Za běžným textem je odkaz a neviditelný znak. Čtečka může vybrat jen část obsahu.",
      "Zobrazí text nebo nabídne otevření example.com.",
      "Záleží na tom, jak aplikace vyhodnotí smíšený obsah.",
    ],
    [
      "Text with a hidden payload",
      "An invisible character and a link follow ordinary text. Readers may select only part of it.",
      "Displays text or offers example.com.",
      "Different readers may handle mixed content differently.",
    ],
  ),
  entry(
    "side-by-side",
    "combinations",
    "https://example.com/official",
    65,
    [
      "Dva kódy vedle sebe",
      "Čtečka může vybrat jiný kód, než na který míříte.",
      "Levý vede na example.com. Pravý na cvičnou platbu.",
      "Před pokračováním zkontrolujte vybraný kód i cílovou adresu.",
    ],
    [
      "Two codes side by side",
      "The reader may select a different code from the one you intended.",
      "Left leads to example.com. Right leads to the training payment.",
      "Check the selected code and destination before continuing.",
    ],
    { secondPayload: `${DEMO_ORIGIN}/start`, arrangement: "side" },
  ),
];
export const categories: Record<Category, Record<Locale, string>> = {
  links: { cs: "Odkazy", en: "Links" },
  payments: { cs: "Platby", en: "Payments" },
  phone: { cs: "SMS a volání", en: "SMS & calls" },
  access: { cs: "Přístup a nastavení", en: "Access & settings" },
  combinations: { cs: "Kombinace", en: "Combinations" },
};
