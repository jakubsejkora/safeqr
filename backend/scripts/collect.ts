import { Apify } from "../src/intel/apify.js";
import { claimCollection, collect } from "../src/intel/collector.js";
import { actorJobs } from "../src/intel/sources.js";
import { DynamoIntelStore } from "../src/intel/store.js";
import { env } from "../src/shared/config.js";
import { BedrockModel } from "../src/shared/model.js";

if (process.argv.includes("--dry-run")) {
  console.log(
    JSON.stringify(
      actorJobs().map(({ actor, build, capUsd }) => ({ actor, build, capUsd })),
      null,
      2,
    ),
  );
} else {
  try {
    const result = await collect({
      apify: new Apify(env("APIFY_TOKEN")),
      intel: new DynamoIntelStore(env("INTEL_TABLE")),
      model: new BedrockModel(8),
      claim: claimCollection,
    });
    console.log(JSON.stringify(result, null, 2));
  } catch {
    console.error(
      "Collection failed. Check the SSO session, table names and APIFY_TOKEN in backend/.env.",
    );
    process.exitCode = 1;
  }
}
