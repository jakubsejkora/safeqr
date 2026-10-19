import { Apify } from "../src/intel/apify.js";
import { claimCollection, collect } from "../src/intel/collector.js";
import { actorJobs } from "../src/intel/sources.js";
import { DynamoIntelStore } from "../src/intel/store.js";
import { env, REGION } from "../src/shared/config.js";
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
    const token =
      process.env.APIFY_TOKEN ||
      (
        await new SecretsManagerClient({ region: REGION, maxAttempts: 1 }).send(
          new GetSecretValueCommand({
            SecretId: process.env.APIFY_SECRET_ARN ?? "safeqr/apify-token",
          }),
        )
      ).SecretString;
    if (!token) throw new Error("Collector credentials unavailable");
    const result = await collect({
      apify: new Apify(token),
      intel: new DynamoIntelStore(env("INTEL_TABLE")),
      model: new BedrockModel(8),
      claim: claimCollection,
    });
    console.log(JSON.stringify(result, null, 2));
  } catch {
    console.error(
      "Collection failed. Check the SSO session, table names and Secrets Manager access (or local APIFY_TOKEN).",
    );
    process.exitCode = 1;
  }
}

import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
