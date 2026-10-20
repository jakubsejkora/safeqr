import { describe, expect, it } from "vitest";
import {
  inspectControls,
  riskyDownload,
} from "../src/checks/link/page-requests.js";

const inspect = (html: string) =>
  inspectControls(html, "https://operator.example/");

describe("requests from visible controls", () => {
  it("ignores prose, menus and hidden or disabled fields", () => {
    const page = `
      <p>Display a phone number, e-mail, payment methods and password help.</p>
      <nav><a href="/password">Heslo</a><a href="/card">Platební karta</a></nav>
      <input type="hidden" name="cardnumber">
      <input disabled type="password">
      <section hidden><input type="tel"></section>
      <div style="display: none"><input autocomplete="cc-number"></div>
      <input name="query" placeholder="Hledat">
    `;
    expect(inspect(page)).toEqual({ asksFor: [], downloads: false });
  });
  it("uses field labels, autocomplete and placeholders", () => {
    const page = `
      <label for="number">Číslo karty</label><input id="number">
      <input autocomplete="one-time-code">
      <input placeholder="Telefonní číslo">
      <label>E-mail<input type="text"></label>
      <input type="password">
    `;
    expect(inspect(page).asksFor).toEqual(
      expect.arrayContaining([
        "card",
        "payment",
        "otp",
        "phone",
        "personalData",
        "password",
      ]),
    );
  });
  it("uses associated labels captured from outside the visible field fragment", () => {
    expect(
      inspect('<input data-safeqr-label="Číslo karty">').asksFor,
    ).toContain("card");
  });
  it("detects payment frames and wallet buttons, not unrelated embeds or display controls", () => {
    expect(
      inspect(`
      <iframe src="https://js.stripe.com/card" title="Secure card field"></iframe>
      <button aria-label="Apple Pay"></button>
    `).asksFor,
    ).toEqual(expect.arrayContaining(["card", "payment"]));
    expect(
      inspect(`
      <iframe src="https://video.example/player"></iframe>
      <button>Display prices</button><button>Privacy settings</button>
    `).asksFor,
    ).toEqual([]);
  });
  it("does not interpret a newsletter request as a password or payment request", () => {
    expect(
      inspect(`
      <p>We never ask for your card or password.</p>
      <input type="email" autocomplete="email"><button>Subscribe</button>
    `).asksFor,
    ).toEqual(["personalData"]);
  });
});

describe("download classification", () => {
  it.each(["pdf", "jpg", "png", "ics", "vcf", "pkpass"])(
    "ignores an ordinary %s download",
    (extension) => {
      expect(
        inspect(`<a download href="/file.${extension}">Download</a>`).downloads,
      ).toBe(false);
      expect(
        riskyDownload("https://example.com/download", `file.${extension}`),
      ).toBe(false);
    },
  );
  it.each([
    "apk",
    "ipa",
    "mobileconfig",
    "exe",
    "msi",
    "dmg",
    "pkg",
    "bat",
    "cmd",
    "scr",
    "js",
    "vbs",
    "jar",
    "ps1",
    "zip",
    "7z",
    "tar.gz",
  ])("flags an offered %s file", (extension) => {
    expect(
      inspect(`<a href="/file.${extension}?download=1">Download</a>`).downloads,
    ).toBe(true);
    expect(
      riskyDownload("https://example.com/download", `file.${extension}`),
    ).toBe(true);
  });
  it("does not flag ordinary JavaScript resources and uses attachment content types", () => {
    expect(inspect('<script src="/app.js"></script>').downloads).toBe(false);
    expect(
      riskyDownload("https://example.com/file", "", "application/zip"),
    ).toBe(true);
    expect(
      riskyDownload("https://example.com/file", "", "application/pdf"),
    ).toBe(false);
  });
});
