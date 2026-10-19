import type { CodeKind } from "./schemas.js";

/** Removes common secrets and identifiers before sending text to a model. */
export function redact(text: string): string {
  return text
    .replace(/https?:\/\/[^\s<>"']+/gi, (value) => {
      try {
        const url = new URL(value);
        url.username = "";
        url.password = "";
        url.search = "";
        url.hash = "";
        url.pathname = url.pathname.replace(/[^/]{40,}/g, "REDACTED");
        return url.href;
      } catch {
        return "[link]";
      }
    })
    .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[email]")
    .replace(/\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){11,30}\b/gi, "[account]")
    .replace(
      /\b0x[a-fA-F0-9]{40}\b|\b(?:bc1|[13])[a-zA-Z0-9]{25,62}\b/g,
      "[crypto address]",
    )
    .replace(/(?:\+?\d[\s().-]*){7,}/g, (value) =>
      /^\d{4}-\d{2}-\d{2}[ .]*$/.test(value) ? value : "[number]",
    )
    .replace(
      /\b(?:password|passwd|token|secret|pin|otp|heslo)\s*[:=]\s*[^\s;,]+/gi,
      "[secret]",
    )
    .replace(/(?:^|;)P:[^;]*(?=;|$)/g, ";P:[secret]");
}

export function redactArticle(text: string): string {
  return redact(text)
    .replace(/@[\p{L}\p{N}_]+/gu, "[handle]")
    .replace(
      /\b(?:[Pp]aní|[Pp]an|[Ss]lečna|[Pp]oškozený|[Pp]oškozená|[Oo]běť|Mr|Mrs|Ms)\s+\p{Lu}\p{Ll}+(?:[ -]\p{Lu}\p{Ll}+){0,3}/gu,
      "[person]",
    )
    .replace(/\b[\p{Lu}][\p{Ll}]+(?:\s+[\p{Lu}][\p{Ll}]+){1,3}\b/gu, "[name]")
    .replace(/[„“"].{1,300}?[„“"]/gu, "[quotation removed]")
    .replace(
      /\b(?:ulice|bytem|adresa|street|address)\s*:?[^.!?\n]{0,100}/giu,
      "[address]",
    );
}

export function describePayload(kind: CodeKind, payload: string): string {
  if (
    ["wifi", "contact", "event", "email", "location", "eSIM", "login"].includes(
      kind,
    )
  )
    return `[${kind} details withheld; use the on-device assessment]`;
  if (kind === "payment") {
    const amount = payload.match(/(?:^|\*)AM:([\d.]{1,20})(?:\*|$)/)?.[1];
    const currency = payload.match(/(?:^|\*)CC:([A-Z]{3})(?:\*|$)/)?.[1];
    return `Payment code. Amount: ${amount ?? "unknown"}. Currency: ${currency ?? "unknown"}. Recipient and message withheld.`;
  }
  if (["phone", "sms", "crypto", "messaging"].includes(kind))
    return `[${kind}; recipient and message withheld; exact threat matching runs separately]`;
  return redact(payload);
}
