import { BedrockRuntimeClient } from "@aws-sdk/client-bedrock-runtime";
import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { MODELS } from "../src/shared/config.js";
import { BedrockModel } from "../src/shared/model.js";

const input = {
  model: MODELS.sonnet,
  system: "Static safety instructions",
  data: { kind: "sms" },
  schema: z.object({ score: z.number().min(0).max(100) }),
};

describe("Bedrock protocol and budget", () => {
  it("sends Converse tool schemas, static cache points and no more than three calls", async () => {
    const client = new BedrockRuntimeClient({ region: "eu-central-1" });
    const send = vi.spyOn(client, "send").mockImplementation(async () => ({
      stopReason: "tool_use",
      output: {
        message: {
          content: [{ toolUse: { name: "report", input: { score: 20 } } }],
        },
      },
    }));
    const model = new BedrockModel(3, client, async () => undefined);
    await Promise.all([model.ask(input), model.ask(input), model.ask(input)]);
    await expect(model.ask(input)).rejects.toThrow("budget");
    expect(send).toHaveBeenCalledTimes(3);
    expect(send.mock.calls[0]?.[0].input).toMatchObject({
      modelId: MODELS.sonnet,
      system: [{ text: input.system }, { cachePoint: { type: "default" } }],
      toolConfig: { toolChoice: { tool: { name: "report" } } },
    });
    expect([...model.used]).toEqual([MODELS.sonnet]);
  });
  it("does not list failed models as contributors and does not retry model errors", async () => {
    const client = new BedrockRuntimeClient({ region: "eu-central-1" });
    const send = vi
      .spyOn(client, "send")
      .mockRejectedValue(new Error("Throttled"));
    const model = new BedrockModel(3, client, async () => undefined);
    await expect(model.ask(input)).rejects.toThrow();
    expect(send).toHaveBeenCalledTimes(1);
    expect(model.used.size).toBe(0);
  });
});
