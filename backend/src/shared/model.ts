import {
  BedrockRuntimeClient,
  type ContentBlock,
  ConverseCommand,
} from "@aws-sdk/client-bedrock-runtime";
import { z } from "zod";
import { env, LIMITS, REGION } from "./config.js";
import { takeQuota } from "./storage.js";

export interface ModelRequest<T> {
  model: string;
  system: string;
  data: unknown;
  schema: z.ZodType<T>;
  image?: Uint8Array;
  maxTokens?: number;
}
export interface Model {
  readonly used: Set<string>;
  ask<T>(request: ModelRequest<T>): Promise<T>;
}

/** Limits a check to three inference attempts, including failed calls. */
export class BedrockModel implements Model {
  readonly used = new Set<string>();
  private calls = 0;
  constructor(
    private readonly budget = LIMITS.checkModelCalls as number,
    private readonly client = new BedrockRuntimeClient({
      region: REGION,
      maxAttempts: 1,
    }),
    private readonly quota: () => Promise<void> = () =>
      takeQuota(env("CHECKS_TABLE"), "models", 60, LIMITS.modelCallsPerMinute),
  ) {}

  async ask<T>(request: ModelRequest<T>): Promise<T> {
    if (++this.calls > this.budget) throw new Error("Model budget exhausted");
    await this.quota();
    const content: ContentBlock[] = [{ text: JSON.stringify(request.data) }];
    if (request.image)
      content.push({
        image: { format: "jpeg", source: { bytes: request.image } },
      });
    const schema = z.toJSONSchema(request.schema, { target: "draft-7" });
    delete schema.$schema;
    const response = await this.client.send(
      new ConverseCommand({
        modelId: request.model,
        system: [{ text: request.system }, { cachePoint: { type: "default" } }],
        messages: [{ role: "user", content }],
        inferenceConfig: {
          maxTokens: request.maxTokens ?? 1800,
          temperature: 0,
        },
        toolConfig: {
          tools: [
            {
              toolSpec: {
                name: "report",
                description: "Return the evidence report.",
                inputSchema: { json: JSON.parse(JSON.stringify(schema)) },
              },
            },
          ],
          toolChoice: { tool: { name: "report" } },
        },
      }),
      { abortSignal: AbortSignal.timeout(10_000) },
    );
    if (response.stopReason !== "tool_use")
      throw new Error("Incomplete model report");
    const tool = response.output?.message?.content?.find(
      (block) => block.toolUse?.name === "report",
    )?.toolUse;
    const result = request.schema.parse(tool?.input);
    this.used.add(request.model);
    return result;
  }
}
