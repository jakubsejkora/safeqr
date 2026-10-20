import type { Locale } from "../lib/locale";
export interface Guide {
  cs: { title: string; steps: string[] };
  en: { title: string; steps: string[] };
  sources: { label: string; enLabel?: string; url: string }[];
}
export const recovery: Guide[] = [
  {
    cs: {
      title: "Poslal/a jsem peníze",
      steps: [
        "Ihned zavolejte své bance. Řekněte, že máte podezření na podvod. Požádejte o zastavení nebo vrácení platby.",
        "Uložte potvrzení platby, účet příjemce, částku a datum. Vrácení peněz bohužel nemusí být možné.",
        "Podvod oznamte policii. Uchovejte zprávy a odkazy jako důkazy.",
      ],
    },
    en: {
      title: "I sent money",
      steps: [
        "Call your bank immediately. Say you suspect fraud. Ask whether the payment can be stopped or recovered.",
        "Keep the payment receipt, recipient account, amount and date. Recovery may not be possible.",
        "Report the fraud to the police. Keep messages and links as evidence.",
      ],
    },
    sources: [
      {
        label: "Air Bank",
        url: "https://www.airbank.cz/novinky/poslali-jste-penize-podvodnikovi/",
      },
    ],
  },
  {
    cs: {
      title: "Zadal/a jsem údaje z karty",
      steps: [
        "Ihned kartu zablokujte v oficiální bankovní aplikaci nebo zavolejte bance.",
        "Zkontrolujte platby. Ty neznámé nahlaste bance a připravte podklady pro reklamaci.",
        "Podvod oznamte policii.",
      ],
    },
    en: {
      title: "I entered card details",
      steps: [
        "Block your card immediately in your official banking app or call your bank.",
        "Check transactions. Report unfamiliar ones to the bank and keep evidence for a dispute.",
        "Report the fraud to the police.",
      ],
    },
    sources: [
      { label: "Air Bank", url: "https://www.airbank.cz/bezpecnost/co-delat-pri-podvodu/" },
    ],
  },
  {
    cs: {
      title: "Zadal/a jsem přihlášení do banky",
      steps: [
        "Ihned volejte banku. Popište, co jste zadali nebo potvrdili. Požádejte o blokaci ohrožených přístupů.",
        "Upozorněte banku i na možné přidání cizího telefonu.",
        "Z bezpečného zařízení změňte hesla. S bankou projděte platby a nastavení.",
      ],
    },
    en: {
      title: "I entered my bank login",
      steps: [
        "Call your bank immediately. Explain what you entered or approved. Ask to block compromised access.",
        "Tell the bank if another device may have been registered.",
        "Change passwords from a safe device. Review payments and security settings with your bank.",
      ],
    },
    sources: [
      {
        label: "ČNB",
        url: "https://www.cnb.cz/cs/dohled-financni-trh/ochrana-spotrebitele/online-podvody-chrante-sve-penize",
      },
      { label: "MONETA", url: "https://www.moneta.cz/bezpecnost/moje-bezpecnost" },
    ],
  },
  {
    cs: {
      title: "Nainstaloval/a jsem cizí aplikaci",
      steps: [
        "Odpojte zařízení od internetu. Vypněte Wi-Fi i mobilní data.",
        "Z jiného bezpečného zařízení kontaktujte banku. Změňte důležitá hesla, začněte bankou a e-mailem.",
        "Před smazáním zařízení se domluvte s policií kvůli důkazům. Potom zajistěte odstranění škodlivé aplikace nebo obnovu systému.",
      ],
    },
    en: {
      title: "I installed an unfamiliar app",
      steps: [
        "Disconnect the device from the internet. Turn off Wi-Fi and mobile data.",
        "Contact your bank from another safe device. Change important passwords, starting with banking and email.",
        "Ask the police about evidence before erasing the device. Then arrange malware removal or a system restore.",
      ],
    },
    sources: [
      { label: "NÚKIB", url: "https://portal.nukib.gov.cz/verejnost-obcan/mam-napadene-zarizeni" },
      { label: "mBank", url: "https://www.mbank.cz/o-nas/bezpecnost/klient/phishing/" },
    ],
  },
  {
    cs: {
      title: "Platím nechtěné SMS předplatné",
      steps: [
        "Uložte SMS a zkontrolujte vyúčtování. Poskytovatele zjistíte u operátora nebo přes Platmobilem.cz.",
        "Zrušte předplatné podle pokynů konkrétní služby. STOP nebo STOP ALL není univerzální postup pro všechny platby.",
        "Potom požádejte operátora o blokaci dalších plateb. Obsah služby reklamujte u poskytovatele, chyby ve vyúčtování u operátora.",
      ],
    },
    en: {
      title: "I have an unwanted SMS subscription",
      steps: [
        "Save the messages and check your bill. Find the provider through your carrier or Platmobilem.cz.",
        "Cancel using that service’s instructions. STOP and STOP ALL are not universal commands for every payment.",
        "Then ask your carrier to block further payments. Dispute service content with the provider and billing errors with the carrier.",
      ],
    },
    sources: [
      { label: "ČTÚ", url: "https://ctu.gov.cz/mam-problem-se-sluzbami-3-stran" },
      { label: "T-Mobile", url: "https://www.t-mobile.cz/platebni-a-premium-sms" },
    ],
  },
  {
    cs: {
      title: "Připojil/a jsem se k neznámé Wi-Fi",
      steps: [
        "Odpojte se. Na iPhonu: Nastavení → Wi-Fi → Upravit → ⓘ u sítě → Ignorovat tuto síť.",
        "Použijte důvěryhodné připojení. Na podezřelé stránce nezadávejte další údaje.",
        "Pokud jste již zadali kartu či přihlášení, postupujte podle příslušného návodu výše.",
      ],
    },
    en: {
      title: "I joined an unfamiliar Wi-Fi network",
      steps: [
        "Disconnect. On iPhone: Settings → Wi-Fi → Edit → ⓘ beside the network → Forget This Network.",
        "Use a trusted connection. Do not enter more details on a suspicious page.",
        "If you already entered card or login details, follow the matching steps above.",
      ],
    },
    sources: [
      { label: "Apple", url: "https://support.apple.com/cs-cz/102480" },
      { label: "MONETA", url: "https://www.moneta.cz/caste-dotazy/odpoved/co-je-to-phishing" },
    ],
  },
  {
    cs: {
      title: "Potvrdil/a jsem přihlášení přes QR",
      steps: [
        "Další cizí přihlášení odmítněte. Ve WhatsApp otevřete Propojená zařízení, vyberte neznámé zařízení a Odhlásit.",
        "V Telegramu otevřete Nastavení → Zařízení a ukončete cizí relaci. Zapněte dvoufázové ověření.",
        "Pokud šlo o Bank iD, ihned volejte vlastní banku. Požádejte o zablokování přihlašovacích údajů.",
      ],
    },
    en: {
      title: "I approved a QR login",
      steps: [
        "Reject further unfamiliar logins. In WhatsApp, open Linked devices, select the unfamiliar device and Log out.",
        "In Telegram, open Settings → Devices and end unfamiliar sessions. Enable Two-Step Verification.",
        "For Bank iD, call your bank immediately and ask to block compromised login credentials.",
      ],
    },
    sources: [
      { label: "WhatsApp", url: "https://faq.whatsapp.com/834124628020911/" },
      { label: "Telegram", url: "https://telegram.org/faq#q-my-phone-was-stolen-what-do-i-do" },
      { label: "Bank iD", url: "https://bankid.cz/lide/caste-dotazy/" },
    ],
  },
  {
    cs: {
      title: "Sdílel/a jsem eSIM QR kód",
      steps: [
        "Kód dál neposílejte. Z jiného telefonu nebo osobně kontaktujte svého operátora.",
        "Požádejte o prověření a blokaci podezřelé SIM nebo eSIM. Pokud je ohrožené bankovnictví, volejte i banku.",
        "Z bezpečného zařízení změňte hesla ohrožených účtů. S operátorem řešte náhradní SIM.",
      ],
    },
    en: {
      title: "I shared an eSIM QR code",
      steps: [
        "Do not share it further. Contact your carrier from another phone or in person.",
        "Ask to investigate and block a compromised SIM or eSIM. Call your bank too if banking access is at risk.",
        "Change compromised account passwords from a safe device. Arrange a replacement SIM with your carrier.",
      ],
    },
    sources: [
      {
        label: "O2",
        url: "https://www.o2.cz/podpora/volani-z-mobilu/co-delat-kdyz-prijdete-o-telefon",
      },
      {
        label: "Vodafone",
        url: "https://www.vodafone.cz/pece/ztraceny-ci-odcizeny-telefon-sim/zablokovani-telefonu-ci-sim/odcizeny-telefon/",
      },
    ],
  },
];
export const operators: Guide[] = [
  {
    cs: {
      title: "O2",
      steps: [
        "Na webu Moje O2 vyberte mobilní tarif → Nastavení → Platba přes SMS → Nastavit → Konfigurovat službu → Zakázáno vše.",
        "Stejně zakažte Platbu přes internet. Zahrnuje i nákupy Apple, Google a Microsoft.",
        "U Platby voláním zvolte Aktivní + Zakázáno vše. Neaktivní služba sama drahé hovory neblokuje.",
        "Předplatné zrušte u poskytovatele. O2 obvykle uvádí STOP ALL na prvních pět číslic služby. Pomoc: 800 02 02 02.",
      ],
    },
    en: {
      title: "O2",
      steps: [
        "On O2’s website, select your plan and open settings for SMS payments. Configure the service and block everything.",
        "Also block internet payments. This includes Apple, Google and Microsoft purchases.",
        "For payment by calling, keep the service active and select the option to block everything. Making the service inactive alone does not block premium calls.",
        "Cancel subscriptions with the provider. O2 commonly specifies STOP ALL to the first five digits of the service number. Help: 800 02 02 02.",
      ],
    },
    sources: [
      { label: "O2 · SMS", url: "https://www.o2.cz/podpora/financni-sluzby/platba-pres-sms" },
      {
        label: "O2 · internet",
        url: "https://www.o2.cz/podpora/financni-sluzby/platba-pres-internet",
      },
      {
        label: "O2 · audiotex",
        enLabel: "O2 · premium calls",
        url: "https://www.o2.cz/podpora/financni-sluzby/platba-volanim",
      },
      { label: "O2 · kontakt", enLabel: "O2 · contact", url: "https://www.o2.cz/osobni/kontakty" },
    ],
  },
  {
    cs: {
      title: "T-Mobile",
      steps: [
        "Na webu Můj T-Mobile → Služby → Platební služby zablokujte Premium SMS, m-platbu a audiotex.",
        "V aplikaci vypnete m-platbu přes Nastavení → vaše číslo → Zpoplatněné služby nad rámec tarifu → Nastavení m-platby.",
        "Na webu zkontrolujte Služby → Platební služby → Seznam aktivních předplatných.",
        "SMS předplatné zrušte podle původní zprávy, případně STOP na původní pětimístné číslo. Udělejte to před blokací SMS plateb. Pomoc: 800 73 73 73.",
      ],
    },
    en: {
      title: "T-Mobile",
      steps: [
        "On T-Mobile’s website, open services and then payment services. Block Premium SMS, mobile payments and premium-rate calls.",
        "In the app, open settings, select your number and find paid services outside your plan. Turn off mobile payments in their settings.",
        "On the website, open services, payment services and the list of active subscriptions.",
        "Cancel SMS subscriptions using the original message, or STOP to the original five-digit number. Do this before blocking SMS payments. Help: 800 73 73 73.",
      ],
    },
    sources: [
      {
        label: "T-Mobile · m-platba",
        enLabel: "T-Mobile · mobile payments",
        url: "https://www.t-mobile.cz/m-platba",
      },
      { label: "T-Mobile · SMS", url: "https://www.t-mobile.cz/platebni-a-premium-sms" },
      {
        label: "T-Mobile · kontakt",
        enLabel: "T-Mobile · contact",
        url: "https://www.t-mobile.cz/kontakty-t-mobile",
      },
    ],
  },
  {
    cs: {
      title: "Vodafone",
      steps: [
        "Na webu Můj Vodafone → Služby → Blokování vypněte zvlášť Premium SMS, m-platby a Audiotex.",
        "V aplikaci Můj Vodafone+ → Služby → vaše číslo → Přehled → Více → Blokování. Blokace Premium SMS ovlivní i SMS jízdenky a DMS.",
        "Předplatné ukončete podle zprávy, případně STOP na prvních pět číslic služby. Poskytovatele zjistíte přes Platmobilem.cz.",
        "Platby zkontrolujte ve vyúčtování v části Platby třetím stranám. Pomoc: *77 z Vodafone, jinak 800 77 00 77.",
      ],
    },
    en: {
      title: "Vodafone",
      steps: [
        "On Vodafone’s website, open services and blocking options. Block Premium SMS, mobile payments and premium-rate calls separately.",
        "In Vodafone’s app, open services, select your number, then overview, more and blocking options. A Premium SMS block also affects SMS tickets and DMS donations.",
        "Cancel using the message instructions, or STOP to the first five digits of the service number. Find the provider through Platmobilem.cz.",
        "Check third-party payments on your bill. Help: *77 from Vodafone, otherwise 800 77 00 77.",
      ],
    },
    sources: [
      {
        label: "Vodafone · blokování",
        enLabel: "Vodafone · payment blocking",
        url: "https://www.vodafone.cz/pece/tarify-sluzby/sms-a-mms-zpravy/blokovani-plateb-tretich-stran/",
      },
      {
        label: "Vodafone · SMS",
        url: "https://www.vodafone.cz/pece/vyuctovani-platby-kredit/platby-mobilem/premium-sms-platby-tretim-stranam/",
      },
      {
        label: "Vodafone · kontakt",
        enLabel: "Vodafone · contact",
        url: "https://www.vodafone.cz/pece/muj-vodafone/muj-vodafone-77/kontakt-operatora/",
      },
    ],
  },
];
export const bankNotes: Record<string, Record<Locale, string>> = {
  "Česká spořitelna": {
    cs: "Nonstop blokace karty a Bankovní IDentity.",
    en: "24/7 card and Bankovní IDentita blocking.",
  },
  ČSOB: {
    cs: "Nonstop bezpečnostní linka pro podvod, účet a kartu.",
    en: "24/7 security line for fraud, accounts and cards.",
  },
  "Komerční banka": {
    cs: "Nonstop blokace karty. Obecná linka +420 955 551 505: po–pá 7–22, so–ne 8–22.",
    en: "24/7 card blocking. General line +420 955 551 505: Mon–Fri 7–22, Sat–Sun 8–22.",
  },
  "MONETA Money Bank": {
    cs: "Nonstop blokace karet a platebních kanálů, i přes virtuální asistentku. Konzultace mají omezenou provozní dobu.",
    en: "24/7 card and payment-channel blocking, including via a virtual assistant. Consultation hours are limited.",
  },
  "Air Bank": {
    cs: "Nonstop urgentní blokace karty nebo účtu. Pomoci může asistentka Aneta.",
    en: "24/7 urgent card or account blocking. The Aneta assistant may help.",
  },
  "Fio banka": {
    cs: "Nonstop blokace karet. Zneužitý účet: +420 224 346 392, také nonstop.",
    en: "24/7 card blocking. Compromised account: +420 224 346 392, also 24/7.",
  },
  Raiffeisenbank: {
    cs: "Nonstop blokace karty a přístupu k účtu po podvodu.",
    en: "24/7 card and account-access blocking after fraud.",
  },
  "UniCredit Bank": {
    cs: "Nonstop při blokaci karty nebo ohrožení peněz. Ostatní dotazy denně 7–22.",
    en: "24/7 for card blocking or money at risk. Other enquiries daily 7–22.",
  },
  mBank: {
    cs: "Operátor po–pá 8–20, víkendy a svátky 8–18. Mimo tuto dobu bezpečnostní blokace hlasovým automatem.",
    en: "Staff: Mon–Fri 8–20, weekends and public holidays 8–18. Automated security blocking outside those hours.",
  },
  "Partners Banka": {
    cs: "Blokace karty nonstop. Běžná podpora po–pá 8–20 mimo svátky.",
    en: "24/7 card blocking. General support Mon–Fri 8–20, excluding public holidays.",
  },
  "Banka CREDITAS": {
    cs: "Nonstop blokace karty a hlášení podezření na podvod.",
    en: "24/7 card blocking and suspected fraud reports.",
  },
  "Max banka": {
    cs: "Bývalé produkty Max, nyní CREDITAS. Nonstop blokace karty a internetového bankovnictví i hlášení podvodu.",
    en: "Former Max products, now CREDITAS. 24/7 card and online-banking blocking and fraud reports.",
  },
};
