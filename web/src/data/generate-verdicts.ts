import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { gallery } from "./gallery.ts";
import type { EngineVerdict, GalleryVerdicts } from "./verdicts.ts";

const webRoot = fileURLToPath(new URL("../../", import.meta.url));
const payloads = gallery.flatMap((item) =>
  item.secondPayload ? [item.payload, item.secondPayload] : [item.payload],
);

function inspect(locale: "cs" | "en"): EngineVerdict[] {
  const result = spawnSync(
    "swift",
    [
      "run",
      "--package-path",
      "../ios/SafeQRKit",
      "safeqr-inspect",
      "--locale",
      locale,
      "--",
      ...payloads,
    ],
    { cwd: webRoot, encoding: "utf8", maxBuffer: 4 * 1024 * 1024 },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || "safeqr-inspect failed");
  const verdicts: EngineVerdict[] = result.stdout
    .trimEnd()
    .split("\n")
    .map((line) => JSON.parse(line));
  assert.equal(verdicts.length, payloads.length, "Expected one verdict per code");
  for (const verdict of verdicts) {
    assert.ok(Number.isInteger(verdict.score) && verdict.score >= 0 && verdict.score <= 100);
    assert.equal(
      verdict.level,
      verdict.score < 30 ? "safe" : verdict.score < 70 ? "caution" : "danger",
    );
    assert.ok(
      verdict.title && verdict.summary && verdict.consequences.length && verdict.limitations.length,
    );
  }
  return verdicts;
}

const cs = inspect("cs");
const en = inspect("en");
for (const [index, verdict] of cs.entries()) {
  assert.equal(verdict.score, en[index].score, "Locale must not change risk");
  assert.equal(verdict.kind, en[index].kind, "Locale must not change the payload type");
  assert.deepEqual(
    verdict.findings.map((finding) => finding.id),
    en[index].findings.map((finding) => finding.id),
  );
}
assert.equal(new Set(gallery.map((item) => item.id)).size, gallery.length, "Duplicate gallery id");
let index = 0;
const verdicts: Record<string, GalleryVerdicts> = Object.fromEntries(
  gallery.map((item) => {
    const primary = index++;
    const secondary = item.secondPayload ? index++ : null;
    return [
      item.id,
      {
        payload: item.payload,
        secondPayload: item.secondPayload ?? null,
        cs: { primary: cs[primary], secondary: secondary === null ? null : cs[secondary] },
        en: { primary: en[primary], secondary: secondary === null ? null : en[secondary] },
      },
    ];
  }),
);
const formatted = spawnSync(
  "pnpm",
  ["exec", "biome", "format", "--stdin-file-path=src/data/verdicts.json"],
  { cwd: webRoot, input: JSON.stringify(verdicts), encoding: "utf8", maxBuffer: 4 * 1024 * 1024 },
);
if (formatted.error) throw formatted.error;
if (formatted.status !== 0) throw new Error(formatted.stderr || "Could not format verdicts");
writeFileSync(new URL("verdicts.json", import.meta.url), formatted.stdout);
console.log(
  `Generated Czech and English verdicts for ${gallery.length} examples (${payloads.length} codes).`,
);
