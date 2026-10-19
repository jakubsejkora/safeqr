import { spawnSync } from "node:child_process";
import { REGION } from "../src/shared/config.js";

for (const args of [
  ["typecheck"],
  ["test"],
  ["lint"],
  [
    "exec",
    "cdk",
    "deploy",
    "SafeQrBackend",
    "--outputs-file",
    "deployment.json",
    ...process.argv.slice(2),
  ],
]) {
  const result = spawnSync("pnpm", args, {
    stdio: "inherit",
    env: { ...process.env, AWS_REGION: REGION, AWS_DEFAULT_REGION: REGION },
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
