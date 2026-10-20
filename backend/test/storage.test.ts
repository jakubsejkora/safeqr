import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { describe, expect, it, vi } from "vitest";
import { DynamoCheckStore } from "../src/shared/storage.js";
import { id } from "./helpers.js";

describe("terminal check transitions", () => {
  it("only fails running checks and tolerates another caller finishing first", async () => {
    const db = DynamoDBDocumentClient.from(
      new DynamoDBClient({ region: "eu-central-1" }),
    );
    const send = vi.spyOn(db, "send").mockRejectedValue(
      Object.assign(new Error("Already completed"), {
        name: "ConditionalCheckFailedException",
      }),
    );
    await expect(
      new DynamoCheckStore("checks", db).fail(id),
    ).resolves.toBeUndefined();
    expect(send.mock.calls[0]?.[0].input).toMatchObject({
      ConditionExpression: "#status = :running",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: { ":running": "running" },
    });
  });

  it("does not hide a failed database write", async () => {
    const db = DynamoDBDocumentClient.from(
      new DynamoDBClient({ region: "eu-central-1" }),
    );
    vi.spyOn(db, "send").mockRejectedValue(new Error("Unavailable"));
    await expect(new DynamoCheckStore("checks", db).fail(id)).rejects.toThrow(
      "Unavailable",
    );
  });
});
