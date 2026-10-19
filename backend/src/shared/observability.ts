import { Logger } from "@aws-lambda-powertools/logger";
import { Metrics, MetricUnit } from "@aws-lambda-powertools/metrics";
import { Tracer } from "@aws-lambda-powertools/tracer";

export const logger = new Logger({ serviceName: "safeqr", logLevel: "INFO" });
export const metrics = new Metrics({
  namespace: "SafeQR",
  serviceName: "backend",
});
export const tracer = new Tracer({
  serviceName: "safeqr",
  captureHTTPsRequests: false,
});

export function count(name: string): void {
  metrics.addMetric(name, MetricUnit.Count, 1);
  metrics.publishStoredMetrics();
}

export async function measured<T>(
  name: string,
  task: () => Promise<T>,
): Promise<T> {
  const parent = tracer.getSegment();
  const segment = parent?.addNewSubsegment(name);
  if (segment) tracer.setSegment(segment);
  try {
    return await task();
  } catch (error) {
    logger.warn("Operation failed", { operation: name });
    count("OperationFailed");
    throw error;
  } finally {
    segment?.close();
    if (parent) tracer.setSegment(parent);
  }
}
