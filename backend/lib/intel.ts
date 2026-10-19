import {
  Duration,
  aws_iam as iam,
  aws_scheduler as scheduler,
  aws_secretsmanager as secrets,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import { MODELS } from "../src/shared/config.js";
import { grantModels, grantTable, makeFunction } from "./functions.js";
import type { Storage } from "./storage.js";

export class Intel extends Construct {
  constructor(scope: Construct, id: string, storage: Storage) {
    super(scope, id);
    const secret = secrets.Secret.fromSecretNameV2(
      this,
      "ApifyToken",
      "safeqr/apify-token",
    );
    const collector = makeFunction(
      this,
      "Collector",
      "src/intel/collector.ts",
      {
        CHECKS_TABLE: storage.checks.tableName,
        INTEL_TABLE: storage.intel.tableName,
        APIFY_SECRET_ARN: secret.secretArn,
      },
      Duration.minutes(14).toSeconds(),
      { memory: 512 },
    );
    secret.grantRead(collector);
    grantTable(
      collector,
      storage.checks.tableArn,
      ["PutItem", "UpdateItem"],
      ["quota#models#*", "collector#*"],
    );
    grantTable(collector, storage.intel.tableArn, [
      "GetItem",
      "PutItem",
      "Query",
    ]);
    grantModels(collector, [MODELS.haiku]);
    const role = new iam.Role(this, "ScheduleRole", {
      assumedBy: new iam.ServicePrincipal("scheduler.amazonaws.com"),
    });
    collector.grantInvoke(role);
    new scheduler.CfnSchedule(this, "Daily", {
      scheduleExpression: "cron(0 6 * * ? *)",
      scheduleExpressionTimezone: "Europe/Prague",
      flexibleTimeWindow: { mode: "OFF" },
      target: {
        arn: collector.functionArn,
        roleArn: role.roleArn,
        input: "{}",
        retryPolicy: { maximumRetryAttempts: 0, maximumEventAgeInSeconds: 60 },
      },
    });
  }
}
