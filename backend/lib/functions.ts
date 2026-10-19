import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  Duration,
  aws_iam as iam,
  aws_lambda as lambda,
  aws_logs as logs,
  RemovalPolicy,
} from "aws-cdk-lib";
import { NodejsFunction, OutputFormat } from "aws-cdk-lib/aws-lambda-nodejs";
import type { Construct } from "constructs";
import { MODELS, REGION } from "../src/shared/config.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export function makeFunction(
  scope: Construct,
  id: string,
  entry: string,
  environment: Record<string, string>,
  timeout: number,
  options: { browser?: boolean; memory?: number } = {},
): NodejsFunction {
  const logGroup = new logs.LogGroup(scope, `${id}Logs`, {
    retention: logs.RetentionDays.ONE_WEEK,
    removalPolicy: RemovalPolicy.DESTROY,
  });
  return new NodejsFunction(scope, id, {
    entry: path.join(root, entry),
    projectRoot: root,
    depsLockFilePath: path.join(root, "pnpm-lock.yaml"),
    runtime: lambda.Runtime.NODEJS_24_X,
    architecture: lambda.Architecture.ARM_64,
    handler: "handler",
    timeout: Duration.seconds(timeout),
    memorySize: options.memory ?? 256,
    tracing: lambda.Tracing.ACTIVE,
    logGroup,
    environment: {
      ...environment,
      POWERTOOLS_SERVICE_NAME: "safeqr",
      POWERTOOLS_METRICS_NAMESPACE: "SafeQR",
      POWERTOOLS_LOG_LEVEL: "INFO",
      POWERTOOLS_LOGGER_LOG_EVENT: "false",
      POWERTOOLS_TRACER_CAPTURE_RESPONSE: "false",
      POWERTOOLS_TRACER_CAPTURE_ERROR: "false",
      NODE_OPTIONS: "--enable-source-maps",
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD: "1",
    },
    bundling: {
      format: OutputFormat.ESM,
      target: "node24",
      sourceMap: true,
      minify: true,
      externalModules: [],
      nodeModules: options.browser ? ["playwright-core"] : [],
      banner:
        "import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);",
    },
  });
}

export function grantModels(fn: NodejsFunction, models: string[]): void {
  const destinations = [
    "eu-central-1",
    "eu-north-1",
    "eu-south-1",
    "eu-south-2",
    "eu-west-1",
    "eu-west-3",
  ];
  fn.addToRolePolicy(
    new iam.PolicyStatement({
      actions: ["bedrock:InvokeModel"],
      resources: models.map(
        (model) =>
          `arn:aws:bedrock:${REGION}:${fn.stack.account}:inference-profile/${model}`,
      ),
    }),
  );
  fn.addToRolePolicy(
    new iam.PolicyStatement({
      actions: ["bedrock:InvokeModel"],
      resources: models.flatMap((model) =>
        destinations.map(
          (region) =>
            `arn:aws:bedrock:${region}::foundation-model/${model.replace(/^eu\./, "")}`,
        ),
      ),
      conditions: {
        StringEquals: {
          "bedrock:InferenceProfileArn": models.map(
            (model) =>
              `arn:aws:bedrock:${REGION}:${fn.stack.account}:inference-profile/${model}`,
          ),
        },
      },
    }),
  );
}
export const allModels = [MODELS.sonnet, MODELS.haiku];

export function grantTable(
  fn: NodejsFunction,
  arn: string,
  actions: string[],
  prefixes?: string[],
): void {
  fn.addToRolePolicy(
    new iam.PolicyStatement({
      actions: actions.map((action) => `dynamodb:${action}`),
      resources: [arn],
      ...(prefixes
        ? {
            conditions: {
              "ForAllValues:StringLike": { "dynamodb:LeadingKeys": prefixes },
            },
          }
        : {}),
    }),
  );
}
