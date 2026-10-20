import { vi } from "vitest";
import type { IntelStore } from "../src/intel/store.js";
import type { MediaStore } from "../src/shared/media.js";
import type { Model, ModelRequest } from "../src/shared/model.js";
import type { Case, Step, Verdict } from "../src/shared/schemas.js";
import type { CheckRecord, CheckStore } from "../src/shared/storage.js";

export const request = {
  payload: "https://example.com/",
  kind: "link" as const,
  locale: "en" as const,
  device: { score: 10, floor: 10, findingIds: [] },
};
export const id = "chk_01234567890123456789012345678901";
export const draft = {
  score: 5,
  findings: [],
  consequences: [],
  limitations: [],
};
export function returning(value: unknown): Model {
  return {
    used: new Set(),
    async ask<T>(request: ModelRequest<T>): Promise<T> {
      return request.schema.parse(value);
    },
  };
}
export function failing(): Model {
  return {
    used: new Set(),
    ask: vi.fn().mockRejectedValue(new Error("unavailable")),
  };
}
export class MemoryChecks implements CheckStore {
  records = new Map<string, CheckRecord>();
  async create(record: CheckRecord) {
    this.records.set(record.id, structuredClone(record));
  }
  async get(key: string) {
    const record = this.records.get(key);
    return record && record.expiresAt > Date.now() / 1000
      ? structuredClone(record)
      : undefined;
  }
  async claim(key: string) {
    const record = this.records.get(key);
    if (!record || record.claimedAt || record.status !== "running")
      return false;
    record.claimedAt = Date.now();
    return true;
  }
  async step(key: string, index: number, step: Step) {
    const record = this.records.get(key);
    if (record) record.steps[index] = step;
  }
  async finish(key: string, verdict: Verdict, screenshotKey?: string) {
    const record = this.records.get(key);
    if (record) {
      record.result = verdict;
      record.status = "completed";
      record.screenshotKey = screenshotKey;
      delete record.request;
      delete record.photoKey;
    }
  }
  async fail(key: string) {
    const record = this.records.get(key);
    if (record?.status === "running") {
      record.status = "failed";
      delete record.request;
      delete record.photoKey;
    }
  }
}
export function media(): MediaStore {
  return {
    put: vi.fn().mockResolvedValue(undefined),
    get: vi.fn().mockResolvedValue(new Uint8Array([255, 216, 255, 217])),
    delete: vi.fn().mockResolvedValue(undefined),
    sign: vi.fn().mockResolvedValue("https://media.example.com/screenshot.jpg"),
  };
}
export function intel(matches: Case[] = []): IntelStore {
  return {
    list: vi.fn().mockResolvedValue(matches),
    match: vi.fn().mockResolvedValue(matches),
    has: vi.fn().mockResolvedValue(false),
    put: vi.fn().mockResolvedValue(undefined),
  };
}
export function record(): CheckRecord {
  return {
    id,
    status: "running",
    steps: [],
    request,
    createdAt: Math.floor(Date.now() / 1000),
    expiresAt: Math.floor(Date.now() / 1000) + 86400,
  };
}
