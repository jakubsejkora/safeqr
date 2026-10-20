import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { LIMITS, REGION } from "./config.js";
import type { Check, CheckRequest, Step, Verdict } from "./schemas.js";

export type StoredRequest = Omit<CheckRequest, "scene"> & {
  scene?: Omit<NonNullable<CheckRequest["scene"]>, "image">;
};
export interface CheckRecord extends Check {
  request?: StoredRequest;
  photoKey?: string;
  screenshotKey?: string;
  createdAt: number;
  expiresAt: number;
  claimedAt?: number;
}
export interface CheckStore {
  create(record: CheckRecord): Promise<void>;
  get(id: string): Promise<CheckRecord | undefined>;
  claim(id: string): Promise<boolean>;
  step(id: string, index: number, step: Step): Promise<void>;
  finish(id: string, verdict: Verdict, screenshotKey?: string): Promise<void>;
  fail(id: string): Promise<void>;
}
export const documentClient = DynamoDBDocumentClient.from(
  new DynamoDBClient({ region: REGION, maxAttempts: 2 }),
  {
    marshallOptions: { removeUndefinedValues: true },
  },
);
function conditional(error: unknown): boolean {
  return (
    error instanceof Error && error.name === "ConditionalCheckFailedException"
  );
}

export class DynamoCheckStore implements CheckStore {
  constructor(
    private readonly table: string,
    private readonly db = documentClient,
  ) {}

  async create(record: CheckRecord): Promise<void> {
    await this.db.send(
      new PutCommand({
        TableName: this.table,
        Item: { pk: record.id, ...record },
        ConditionExpression: "attribute_not_exists(pk)",
      }),
    );
  }

  async get(id: string): Promise<CheckRecord | undefined> {
    const { Item } = await this.db.send(
      new GetCommand({
        TableName: this.table,
        Key: { pk: id },
        ConsistentRead: true,
      }),
    );
    if (!Item || Item.expiresAt <= Date.now() / 1000) return undefined;
    return Item as CheckRecord;
  }

  async claim(id: string): Promise<boolean> {
    try {
      await this.db.send(
        new UpdateCommand({
          TableName: this.table,
          Key: { pk: id },
          UpdateExpression: "SET claimedAt = :now",
          ConditionExpression:
            "attribute_exists(pk) AND attribute_not_exists(claimedAt) AND #status = :running AND expiresAt > :now",
          ExpressionAttributeNames: { "#status": "status" },
          ExpressionAttributeValues: {
            ":now": Math.floor(Date.now() / 1000),
            ":running": "running",
          },
        }),
      );
      return true;
    } catch (error) {
      if (conditional(error)) return false;
      throw error;
    }
  }

  async step(id: string, index: number, step: Step): Promise<void> {
    await this.db.send(
      new UpdateCommand({
        TableName: this.table,
        Key: { pk: id },
        UpdateExpression: `SET steps[${index}] = :step`,
        ConditionExpression: "#status = :running",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: { ":step": step, ":running": "running" },
      }),
    );
  }

  async finish(
    id: string,
    verdict: Verdict,
    screenshotKey?: string,
  ): Promise<void> {
    await this.db.send(
      new UpdateCommand({
        TableName: this.table,
        Key: { pk: id },
        UpdateExpression: `SET #status = :completed, #result = :result${screenshotKey ? ", screenshotKey = :key" : ""} REMOVE #request, photoKey`,
        ConditionExpression: "#status = :running",
        ExpressionAttributeNames: {
          "#status": "status",
          "#result": "result",
          "#request": "request",
        },
        ExpressionAttributeValues: {
          ":completed": "completed",
          ":running": "running",
          ":result": verdict,
          ...(screenshotKey ? { ":key": screenshotKey } : {}),
        },
      }),
    );
  }

  async fail(id: string): Promise<void> {
    try {
      await this.db.send(
        new UpdateCommand({
          TableName: this.table,
          Key: { pk: id },
          UpdateExpression: "SET #status = :failed REMOVE #request, photoKey",
          ConditionExpression: "#status = :running",
          ExpressionAttributeNames: {
            "#status": "status",
            "#request": "request",
          },
          ExpressionAttributeValues: {
            ":failed": "failed",
            ":running": "running",
          },
        }),
      );
    } catch (error) {
      if (!conditional(error)) throw error;
    }
  }
}

export class QuotaExceeded extends Error {}

export async function claimOnce(table: string, key: string): Promise<void> {
  try {
    await documentClient.send(
      new PutCommand({
        TableName: table,
        Item: {
          pk: key,
          expiresAt:
            Math.floor(Date.now() / 1000) + 2 * LIMITS.retentionSeconds,
        },
        ConditionExpression: "attribute_not_exists(pk)",
      }),
    );
  } catch (error) {
    if (conditional(error)) throw new QuotaExceeded();
    throw error;
  }
}

export async function takeQuota(
  table: string,
  scope: string,
  windowSeconds: number,
  limit: number,
): Promise<void> {
  const window = Math.floor(Date.now() / 1000 / windowSeconds);
  try {
    await documentClient.send(
      new UpdateCommand({
        TableName: table,
        Key: { pk: `quota#${scope}#${window}` },
        UpdateExpression: "SET expiresAt = :expiry ADD used :one",
        ConditionExpression: "attribute_not_exists(used) OR used < :limit",
        ExpressionAttributeValues: {
          ":expiry": (window + 1) * windowSeconds + LIMITS.retentionSeconds,
          ":one": 1,
          ":limit": limit,
        },
      }),
    );
  } catch (error) {
    if (conditional(error)) throw new QuotaExceeded();
    throw error;
  }
}
