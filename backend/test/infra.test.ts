import { App } from "aws-cdk-lib";
import { Match, Template } from "aws-cdk-lib/assertions";
import { describe, it } from "vitest";
import { SafeQrStack } from "../lib/stack.js";

describe("deployable infrastructure", () => {
  it("can map api.safeqr.cz using a supplied Frankfurt certificate", () => {
    const app = new App({
      outdir: ".cache/test-domain",
      context: {
        "aws:cdk:bundling-stacks": [],
        apiCertificateArn:
          "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012",
      },
    });
    const template = Template.fromStack(
      new SafeQrStack(app, "DomainTest", { env: { region: "eu-central-1" } }),
    );
    template.hasResourceProperties("AWS::ApiGatewayV2::DomainName", {
      DomainName: "api.safeqr.cz",
    });
    template.hasResourceProperties("AWS::ApiGatewayV2::ApiMapping", {
      Stage: "$default",
    });
  });
  it("uses bounded ARM functions, expiring private storage, EU models and the Prague schedule", () => {
    const app = new App({
      outdir: ".cache/test-cdk",
      context: { "aws:cdk:bundling-stacks": [] },
    });
    const template = Template.fromStack(
      new SafeQrStack(app, "Test", { env: { region: "eu-central-1" } }),
    );
    template.resourceCountIs("AWS::Lambda::Function", 3);
    template.allResourcesProperties("AWS::Lambda::Function", {
      Runtime: "nodejs24.x",
      Architectures: ["arm64"],
      TracingConfig: { Mode: "Active" },
      ReservedConcurrentExecutions: Match.absent(),
    });
    template.hasResourceProperties("AWS::DynamoDB::Table", {
      TimeToLiveSpecification: { AttributeName: "expiresAt", Enabled: true },
      BillingMode: "PAY_PER_REQUEST",
    });
    template.hasResourceProperties("AWS::S3::Bucket", {
      LifecycleConfiguration: {
        Rules: [Match.objectLike({ ExpirationInDays: 1 })],
      },
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
    template.hasResourceProperties("AWS::Scheduler::Schedule", {
      ScheduleExpression: "cron(0 6 * * ? *)",
      ScheduleExpressionTimezone: "Europe/Prague",
      Target: Match.objectLike({
        RetryPolicy: { MaximumEventAgeInSeconds: 60, MaximumRetryAttempts: 0 },
      }),
    });
    template.hasResourceProperties("AWS::ApiGatewayV2::Api", {
      CorsConfiguration: Match.objectLike({
        AllowOrigins: ["https://safeqr.cz", "https://www.safeqr.cz"],
      }),
    });
    template.hasResourceProperties("AWS::Lambda::EventInvokeConfig", {
      MaximumRetryAttempts: 0,
      MaximumEventAgeInSeconds: 60,
    });
    template.hasResourceProperties("AWS::IAM::Policy", {
      PolicyDocument: {
        Statement: Match.arrayWith([
          Match.objectLike({
            Action: [
              "bedrock-agentcore:StartBrowserSession",
              "bedrock-agentcore:StopBrowserSession",
              "bedrock-agentcore:ConnectBrowserAutomationStream",
            ],
            Resource:
              "arn:aws:bedrock-agentcore:eu-central-1:aws:browser/aws.browser.v1",
          }),
        ]),
        Version: "2012-10-17",
      },
    });
  }, 30_000);
});
