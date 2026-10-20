import {
  Duration,
  aws_lambda_destinations as destinations,
  aws_iam as iam,
  aws_lambda as lambda,
  aws_secretsmanager as secrets,
  aws_sqs as sqs,
} from "aws-cdk-lib";
import type { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import { Construct } from "constructs";
import {
  allModels,
  grantModels,
  grantTable,
  makeFunction,
} from "./functions.js";
import type { Storage } from "./storage.js";

export class Checks extends Construct {
  readonly worker: NodejsFunction;
  constructor(scope: Construct, id: string, storage: Storage) {
    super(scope, id);
    const apifySecret = secrets.Secret.fromSecretNameV2(
      this,
      "ApifyToken",
      "safeqr/apify-token",
    );
    this.worker = makeFunction(
      this,
      "Worker",
      "src/checks/worker.ts",
      {
        CHECKS_TABLE: storage.checks.tableName,
        INTEL_TABLE: storage.intel.tableName,
        MEDIA_BUCKET: storage.media.bucketName,
        APIFY_SECRET_ARN: apifySecret.secretArn,
      },
      70,
      { browser: true, memory: 1024 },
    );
    grantTable(
      this.worker,
      storage.checks.tableArn,
      ["GetItem", "UpdateItem"],
      ["chk_*", "quota#models#*", "quota#profiles#*"],
    );
    apifySecret.grantRead(this.worker);
    grantTable(this.worker, storage.intel.tableArn, ["Query"]);
    storage.media.grantRead(this.worker, "scenes/*");
    storage.media.grantDelete(this.worker, "scenes/*");
    storage.media.grantPut(this.worker, "screenshots/*");
    grantModels(this.worker, allModels);
    this.worker.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "bedrock-agentcore:StartBrowserSession",
          "bedrock-agentcore:StopBrowserSession",
          "bedrock-agentcore:ConnectBrowserAutomationStream",
        ],
        resources: [
          `arn:aws:bedrock-agentcore:eu-central-1:aws:browser/aws.browser.v1`,
        ],
      }),
    );
    const failures = new sqs.Queue(this, "Failures", {
      encryption: sqs.QueueEncryption.SQS_MANAGED,
      retentionPeriod: Duration.days(1),
      enforceSSL: true,
    });
    new lambda.EventInvokeConfig(this, "Async", {
      function: this.worker,
      retryAttempts: 0,
      maxEventAge: Duration.minutes(1),
      onFailure: new destinations.SqsDestination(failures),
    });
  }
}
