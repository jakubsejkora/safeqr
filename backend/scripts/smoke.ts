import { setTimeout } from "node:timers/promises";
import { env } from "../src/shared/config.js";
import { acceptedSchema, checkSchema } from "../src/shared/schemas.js";

try {
  const api = env("API_URL").replace(/\/$/, "");
  if (new URL(api).protocol !== "https:") throw new Error("HTTPS required");
  const response = await fetch(`${api}/v1/checks`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    signal: AbortSignal.timeout(20_000),
    body: JSON.stringify({
      payload:
        process.argv.slice(2).find((argument) => !argument.startsWith("--")) ??
        "https://safeqr.cz",
      kind: "link",
      locale: process.argv.includes("--cs") ? "cs" : "en",
      device: { score: 0, floor: 0, findingIds: [] },
    }),
  });
  if (response.status !== 202)
    throw new Error(`Start returned ${response.status}`);
  const accepted = acceptedSchema.parse(await response.json());
  const deadline = Date.now() + 160_000;
  let previous = "";
  for (;;) {
    await setTimeout(Math.max(500, Math.min(accepted.pollAfterMs, 3000)));
    const poll = await fetch(`${api}/v1/checks/${accepted.id}`, {
      signal: AbortSignal.timeout(10_000),
    });
    if (!poll.ok) throw new Error(`Poll returned ${poll.status}`);
    const check = checkSchema.parse(await poll.json());
    const steps = JSON.stringify(check.steps);
    if (steps !== previous) {
      console.log(
        check.steps.map((step) => `${step.status}: ${step.label}`).join("\n"),
      );
      previous = steps;
    }
    if (check.status !== "running") {
      console.log(JSON.stringify(check.result, null, 2));
      if (check.status !== "completed") process.exitCode = 1;
      break;
    }
    if (Date.now() > deadline) throw new Error("Timed out waiting for verdict");
  }
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message.replace(/https?:\S+/g, "[URL]")
      : "Smoke check failed",
  );
  process.exitCode = 1;
}
