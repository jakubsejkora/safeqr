import { App } from "aws-cdk-lib";
import { SafeQrStack } from "../lib/stack.js";
import { REGION } from "../src/shared/config.js";

const app = new App();
new SafeQrStack(app, "SafeQrBackend", {
  env: { region: REGION },
  description: "Safe QR private deep checks and public quishing evidence",
});
