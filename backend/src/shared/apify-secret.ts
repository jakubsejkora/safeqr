import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import { env, REGION } from "./config.js";

/** Reads the service credential without exposing it to logs or caller input. */
export async function apifyToken(): Promise<string> {
  const secrets = new SecretsManagerClient({ region: REGION, maxAttempts: 1 });
  const secret = await secrets.send(
    new GetSecretValueCommand({ SecretId: env("APIFY_SECRET_ARN") }),
  );
  if (!secret.SecretString) throw new Error("Apify credentials unavailable");
  return secret.SecretString;
}
