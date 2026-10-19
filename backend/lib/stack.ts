import { CfnOutput, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import { Api } from "./api.js";
import { Checks } from "./checks.js";
import { Intel } from "./intel.js";
import { Storage } from "./storage.js";

export class SafeQrStack extends Stack {
  constructor(scope: Construct, id: string, props: StackProps = {}) {
    super(scope, id, props);
    const storage = new Storage(this, "Storage");
    const checks = new Checks(this, "Checks", storage);
    const api = new Api(this, "Api", storage, checks.worker);
    new Intel(this, "Intel", storage);
    new CfnOutput(this, "ApiUrl", { value: api.http.apiEndpoint });
    new CfnOutput(this, "ChecksTable", { value: storage.checks.tableName });
    new CfnOutput(this, "IntelTable", { value: storage.intel.tableName });
    new CfnOutput(this, "MediaBucket", { value: storage.media.bucketName });
    if (api.customDomainTarget)
      new CfnOutput(this, "ApiDomainTarget", { value: api.customDomainTarget });
  }
}
