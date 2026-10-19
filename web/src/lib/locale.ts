export type Locale = "cs" | "en";
export const text = (locale: Locale, cs: string, en: string): string => (locale === "cs" ? cs : en);
export const routes = {
  home: { cs: "/", en: "/en/" },
  gallery: { cs: "/galerie/", en: "/en/gallery/" },
  guides: { cs: "/navody/", en: "/en/guides/" },
  privacy: { cs: "/soukromi/", en: "/en/privacy/" },
  kit: { cs: "/kit/", en: "/en/kit/" },
} as const;
export type Page = keyof typeof routes;
export const verdict = (score: number, locale: Locale) =>
  score < 30
    ? { level: "safe", icon: "✓", label: text(locale, "Vypadá bezpečně", "Looks safe") }
    : score < 70
      ? { level: "caution", icon: "!", label: text(locale, "Buďte opatrní", "Be careful") }
      : { level: "danger", icon: "×", label: text(locale, "Nebezpečné", "Dangerous") };
