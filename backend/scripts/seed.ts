import seeds from "../data/verified-cases.json" with { type: "json" };
import { publicCase, validateCase } from "../src/intel/schema.js";
import { DynamoIntelStore } from "../src/intel/store.js";
import { env } from "../src/shared/config.js";

const items = seeds.map((item) => ({
  ...item,
  record: validateCase(item.record),
}));
if (process.argv.includes("--dry-run")) {
  console.log(
    JSON.stringify(
      items.map((item) => publicCase(item, "cs")),
      null,
      2,
    ),
  );
} else {
  try {
    const store = new DynamoIntelStore(env("INTEL_TABLE"));
    for (const item of items) await store.put(item);
    console.log(
      `Loaded ${items.length} verified source records. Re-running is safe.`,
    );
  } catch {
    console.error(
      "Seeding failed. Check the SSO session and INTEL_TABLE in backend/.env.",
    );
    process.exitCode = 1;
  }
}
