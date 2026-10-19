import {
  GetCommand,
  QueryCommand,
  TransactWriteCommand,
} from "@aws-sdk/lib-dynamodb";
import { indicatorKey, matchesIndicator } from "../checks/intel/indicators.js";
import type { Case, Indicator, Locale } from "../shared/schemas.js";
import { documentClient } from "../shared/storage.js";
import {
  hash,
  type IntelCase,
  matchingIndicators,
  publicCase,
  validateCase,
} from "./schema.js";

export interface IntelStore {
  list(locale: Locale, limit: number): Promise<Case[]>;
  match(indicators: Indicator[], locale: Locale): Promise<Case[]>;
  has(id: string): Promise<boolean>;
  put(item: IntelCase): Promise<void>;
}

export class DynamoIntelStore implements IntelStore {
  constructor(
    private readonly table: string,
    private readonly db = documentClient,
  ) {}
  async has(id: string): Promise<boolean> {
    const response = await this.db.send(
      new GetCommand({
        TableName: this.table,
        Key: { pk: id, sk: "case" },
        ProjectionExpression: "pk",
      }),
    );
    return Boolean(response.Item);
  }
  async list(locale: Locale, limit: number): Promise<Case[]> {
    const response = await this.db.send(
      new QueryCommand({
        TableName: this.table,
        KeyConditionExpression: "pk = :pk",
        ExpressionAttributeValues: { ":pk": "feed" },
        ScanIndexForward: false,
        Limit: limit,
      }),
    );
    return (response.Items ?? []).map((item) =>
      publicCase(item.data as IntelCase, locale),
    );
  }
  async put(item: IntelCase): Promise<void> {
    const record = validateCase(item.record);
    if (!record.sourcePublishedDate)
      throw new Error("Undated case cannot enter public feed");
    const indicators = matchingIndicators(record);
    const rows = [
      { pk: record.id, sk: "case", data: item },
      {
        pk: "feed",
        sk: `${record.sourcePublishedDate}#${record.id}`,
        data: item,
      },
      ...indicators.map((indicator) => ({
        pk: indicatorKey(indicator),
        sk: `${record.id}#${hash(indicator.value)}`,
        data: item,
        indicator,
      })),
    ];
    try {
      await this.db.send(
        new TransactWriteCommand({
          TransactItems: rows.map((row, index) => ({
            Put: {
              TableName: this.table,
              Item: row,
              ...(index === 0
                ? { ConditionExpression: "attribute_not_exists(pk)" }
                : {}),
            },
          })),
        }),
      );
    } catch (error) {
      if (
        error instanceof Error &&
        error.name === "TransactionCanceledException" &&
        (await this.has(record.id))
      )
        return;
      throw error;
    }
  }
  async match(indicators: Indicator[], locale: Locale): Promise<Case[]> {
    const results = new Map<string, Case>();
    const groups = new Map<string, Indicator[]>();
    for (const indicator of indicators) {
      const key = indicatorKey(indicator);
      groups.set(key, [...(groups.get(key) ?? []), indicator]);
    }
    const entries = [...groups.entries()];
    for (let offset = 0; offset < entries.length; offset += 8) {
      await Promise.all(
        entries.slice(offset, offset + 8).map(async ([key, candidates]) => {
          const response = await this.db.send(
            new QueryCommand({
              TableName: this.table,
              KeyConditionExpression: "pk = :pk",
              ExpressionAttributeValues: { ":pk": key },
              Limit: 20,
            }),
          );
          for (const item of response.Items ?? []) {
            if (
              !candidates.some((candidate) =>
                matchesIndicator(candidate, item.indicator as Indicator),
              )
            )
              continue;
            const match = publicCase(item.data as IntelCase, locale);
            results.set(match.id, match);
          }
        }),
      );
    }
    return [...results.values()].slice(0, 10);
  }
}
