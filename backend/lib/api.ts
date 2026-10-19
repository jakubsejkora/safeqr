import {
  aws_certificatemanager as certificates,
  Duration,
  aws_apigatewayv2 as gateway,
  aws_apigatewayv2_integrations as integrations,
} from "aws-cdk-lib";
import type { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import { Construct } from "constructs";
import { grantTable, makeFunction } from "./functions.js";
import type { Storage } from "./storage.js";

export class Api extends Construct {
  readonly http: gateway.HttpApi;
  readonly customDomainTarget?: string;
  constructor(
    scope: Construct,
    id: string,
    storage: Storage,
    worker: NodejsFunction,
  ) {
    super(scope, id);
    const handler = makeFunction(
      this,
      "Handler",
      "src/api/handler.ts",
      {
        CHECKS_TABLE: storage.checks.tableName,
        INTEL_TABLE: storage.intel.tableName,
        MEDIA_BUCKET: storage.media.bucketName,
        WORKER_NAME: worker.functionName,
      },
      15,
    );
    grantTable(
      handler,
      storage.checks.tableArn,
      ["GetItem", "PutItem", "UpdateItem"],
      ["chk_*", "quota#starts#*", "quota#daily#*"],
    );
    grantTable(handler, storage.intel.tableArn, ["Query"], ["feed"]);
    storage.media.grantPut(handler, "scenes/*");
    storage.media.grantDelete(handler, "scenes/*");
    storage.media.grantRead(handler, "screenshots/*");
    worker.grantInvoke(handler);
    const integration = new integrations.HttpLambdaIntegration(
      "Lambda",
      handler,
    );
    this.http = new gateway.HttpApi(this, "Http", {
      createDefaultStage: false,
      defaultIntegration: integration,
      corsPreflight: {
        allowOrigins: ["https://safeqr.cz", "https://www.safeqr.cz"],
        allowMethods: [
          gateway.CorsHttpMethod.GET,
          gateway.CorsHttpMethod.POST,
          gateway.CorsHttpMethod.OPTIONS,
        ],
        allowHeaders: ["content-type"],
        maxAge: Duration.hours(1),
      },
    });
    this.http.addRoutes({
      path: "/v1/checks",
      methods: [gateway.HttpMethod.POST],
      integration,
    });
    this.http.addRoutes({
      path: "/v1/checks/{checkId}",
      methods: [gateway.HttpMethod.GET],
      integration,
    });
    this.http.addRoutes({
      path: "/v1/cases",
      methods: [gateway.HttpMethod.GET],
      integration,
    });
    const stage = new gateway.HttpStage(this, "Stage", {
      httpApi: this.http,
      stageName: "$default",
      autoDeploy: true,
      throttle: { rateLimit: 20, burstLimit: 40 },
    });
    const certificateArn: unknown =
      this.node.tryGetContext("apiCertificateArn");
    if (certificateArn !== undefined) {
      if (
        typeof certificateArn !== "string" ||
        !/^arn:aws:acm:eu-central-1:\d{12}:certificate\/[a-f0-9-]+$/.test(
          certificateArn,
        )
      )
        throw new Error(
          "apiCertificateArn must be an ACM certificate in eu-central-1",
        );
      const domain = new gateway.DomainName(this, "Domain", {
        domainName: "api.safeqr.cz",
        certificate: certificates.Certificate.fromCertificateArn(
          this,
          "Certificate",
          certificateArn,
        ),
      });
      new gateway.ApiMapping(this, "Mapping", {
        api: this.http,
        domainName: domain,
        stage,
      });
      this.customDomainTarget = domain.regionalDomainName;
    }
  }
}
