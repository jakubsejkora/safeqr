import { Sha256 } from "@aws-crypto/sha256-js";
import {
  BedrockAgentCoreClient,
  StartBrowserSessionCommand,
  StopBrowserSessionCommand,
} from "@aws-sdk/client-bedrock-agentcore";
import { HttpRequest } from "@smithy/protocol-http";
import { SignatureV4 } from "@smithy/signature-v4";
import { type Browser, chromium } from "playwright-core";
import { REGION } from "../../shared/config.js";

export interface BrowserSession {
  browser: Browser;
  stop(): Promise<void>;
}

/** Connects Playwright to the isolated EU browser using IAM-signed CDP headers. */
export async function startBrowser(): Promise<BrowserSession> {
  const client = new BedrockAgentCoreClient({ region: REGION, maxAttempts: 1 });
  const browserIdentifier = "aws.browser.v1";
  const session = await client.send(
    new StartBrowserSessionCommand({
      browserIdentifier,
      name: "safeqr-check",
      sessionTimeoutSeconds: 60,
      viewPort: { width: 1280, height: 800 },
    }),
    { abortSignal: AbortSignal.timeout(4000) },
  );
  if (!session.sessionId) throw new Error("Browser session unavailable");
  const stop = async () => {
    await client.send(
      new StopBrowserSessionCommand({
        browserIdentifier,
        sessionId: session.sessionId,
      }),
      { abortSignal: AbortSignal.timeout(2500) },
    );
  };
  try {
    const hostname = `bedrock-agentcore.${REGION}.amazonaws.com`;
    const path = `/browser-streams/${browserIdentifier}/sessions/${session.sessionId}/automation`;
    const signer = new SignatureV4({
      service: "bedrock-agentcore",
      region: REGION,
      credentials: client.config.credentials,
      sha256: Sha256,
    });
    const signed = await signer.sign(
      new HttpRequest({
        protocol: "https:",
        hostname,
        method: "GET",
        path,
        headers: { host: hostname },
      }),
    );
    const browser = await chromium.connectOverCDP(`wss://${hostname}${path}`, {
      headers: signed.headers,
      timeout: 4000,
    });
    return {
      browser,
      stop: async () => {
        try {
          await browser.close();
        } finally {
          await stop();
        }
      },
    };
  } catch (error) {
    await stop().catch(() => undefined);
    throw error;
  }
}
