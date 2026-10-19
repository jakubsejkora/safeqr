export const REGION = "eu-central-1";
export const MODELS = {
  sonnet: "eu.anthropic.claude-sonnet-4-5-20250929-v1:0",
  haiku: "eu.anthropic.claude-haiku-4-5-20251001-v1:0",
} as const;

export const LIMITS = {
  requestBytes: 2_100_000,
  retentionSeconds: 86_400,
  checkStartsPerMinute: 12,
  checksPerDay: 500,
  modelCallsPerMinute: 20,
  checkModelCalls: 3,
  linkBytes: 512_000,
  hops: 10,
  screenshotSeconds: 900,
} as const;

export function env(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing configuration: ${name}`);
  return value;
}
