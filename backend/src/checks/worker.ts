import { DynamoIntelStore, type IntelStore } from "../intel/store.js";
import { env } from "../shared/config.js";
import { type MediaStore, S3MediaStore } from "../shared/media.js";
import { BedrockModel, type Model } from "../shared/model.js";
import { linkTarget } from "../shared/network.js";
import { count, measured } from "../shared/observability.js";
import { checkIdSchema, type Step } from "../shared/schemas.js";
import { type CheckStore, DynamoCheckStore } from "../shared/storage.js";
import { extractIndicators } from "./intel/indicators.js";
import { domainAge } from "./link/domain.js";
import { inspectLink, type SandboxResult } from "./link/sandbox.js";
import { type TraceResult, traceLink } from "./link/tracer.js";
import { inspectScene } from "./scene/agent.js";
import { inspectSocial, type SocialResult } from "./social/agent.js";
import { isInstagramUrl } from "./social/links.js";
import { createVerdict, type Evidence } from "./verdict/agent.js";
import { progress, say } from "./verdict/copy.js";

export interface WorkerDependencies {
  checks: CheckStore;
  media: MediaStore;
  intel: IntelStore;
  model: () => Model;
  trace?: typeof traceLink;
  sandbox?: typeof inspectLink;
  scene?: typeof inspectScene;
  age?: typeof domainAge;
  social?: typeof inspectSocial;
}
const stepIds: Step["id"][] = [
  "redirects",
  "sandbox",
  "scene",
  "intel",
  "verdict",
];

export function createWorker(
  deps: WorkerDependencies,
): (event: { id: string }) => Promise<void> {
  return async (event) => {
    const id = checkIdSchema.parse(event.id);
    const record = await deps.checks.get(id);
    if (!record?.request || !(await deps.checks.claim(id))) return;
    const request = record.request;
    const target = linkTarget(request.payload);
    const model = deps.model();
    const evidence: Evidence = { intel: [], limitations: [] };
    let screenshotKey: string | undefined;
    let photoDeleted = !record.photoKey;
    let socialApplied = false;
    let socialResult: SocialResult | undefined;
    const step = (name: Step["id"], status: Step["status"]) =>
      deps.checks.step(
        id,
        stepIds.indexOf(name),
        name === "intel" && socialApplied
          ? {
              id: name,
              status,
              label: say(
                request.locale,
                "Prohlížíme profil a jeho odkazy (Apify)",
                "Checking the profile and its links (Apify)",
              ),
            }
          : progress(request.locale, name, status),
      );
    try {
      const traceTask = async (): Promise<TraceResult | undefined> => {
        if (request.kind !== "link") {
          await step("redirects", "skipped");
          return undefined;
        }
        await step("redirects", "running");
        const result = await (deps.trace ?? traceLink)(target);
        if (result.limitation)
          evidence.limitations.push(
            result.limitation === "blocked" ? "blocked" : "redirects",
          );
        await step("redirects", result.limitation ? "failed" : "done");
        return result;
      };
      const sandboxTask = async (): Promise<SandboxResult | undefined> => {
        if (request.kind !== "link") {
          await step("sandbox", "skipped");
          return undefined;
        }
        await step("sandbox", "running");
        try {
          const result = await (deps.sandbox ?? inspectLink)(target, model);
          if (result.restricted) evidence.limitations.push("restricted");
          if (result.navigationFailed) evidence.limitations.push("sandbox");
          if (result.modelFailed) evidence.limitations.push("browserModel");
          evidence.downloads = result.downloads;
          if (!isInstagramUrl(result.report.finalUrl)) {
            screenshotKey = `screenshots/${id}.jpg`;
            await deps.media.put(screenshotKey, result.screenshot);
          }
          await step("sandbox", result.navigationFailed ? "failed" : "done");
          return result;
        } catch {
          evidence.limitations.push("sandbox");
          await step("sandbox", "failed");
          return undefined;
        }
      };
      const tracing = traceTask();
      const socialTask = async () => {
        if (request.kind !== "link") return;
        const trace = await tracing.catch(() => undefined);
        socialResult = await (deps.social ?? inspectSocial)(
          { url: trace?.report?.finalUrl ?? target, page: trace?.page },
          {
            progress: async () => {
              socialApplied = true;
              await step("intel", "running");
            },
          },
        );
      };
      const sceneTask = async () => {
        if (!record.photoKey) {
          await step("scene", "skipped");
          return;
        }
        await step("scene", "running");
        let bytes: Uint8Array | undefined;
        try {
          bytes = await deps.media.get(record.photoKey);
          // The traced destination lets the scene judge codes that redirect through QR or shortener services.
          const destination = (await tracing.catch(() => undefined))?.report
            ?.finalUrl;
          evidence.scene = await (deps.scene ?? inspectScene)(
            request,
            bytes,
            model,
            destination,
          );
          await step("scene", "done");
        } catch {
          evidence.limitations.push("scene");
          await step("scene", "failed");
        } finally {
          bytes?.fill(0);
          try {
            await deps.media.delete(record.photoKey);
            photoDeleted = true;
          } catch {
            evidence.limitations.push("photoDeletion");
          }
        }
      };
      const initialIntel = async () => {
        await step("intel", "running");
        try {
          evidence.intel = await deps.intel.match(
            extractIndicators(
              request.payload,
              request.kind === "link" ? [target] : [],
            ),
            request.locale,
          );
        } catch {
          evidence.limitations.push("intel");
        }
      };
      const settled = await Promise.allSettled([
        tracing,
        sandboxTask(),
        sceneTask(),
        initialIntel(),
        socialTask(),
      ]);
      const trace =
        settled[0].status === "fulfilled" ? settled[0].value : undefined;
      const sandbox =
        settled[1].status === "fulfilled" ? settled[1].value : undefined;
      if (settled.some((result) => result.status === "rejected"))
        evidence.limitations.push("model");
      evidence.link = sandbox?.report ?? trace?.report;
      if (
        request.kind === "link" &&
        !socialResult?.report &&
        sandbox?.report.finalUrl &&
        sandbox.report.finalUrl !== trace?.report?.finalUrl
      ) {
        socialResult = await (deps.social ?? inspectSocial)(
          { url: sandbox.report.finalUrl },
          {
            progress: async () => {
              socialApplied = true;
              await step("intel", "running");
            },
          },
        );
      }
      if (socialResult?.report) {
        evidence.social = socialResult.report;
        evidence.limitations.push("socialScope", ...socialResult.limitations);
      }
      if (request.kind === "link") {
        const tracedDestination = trace?.report?.hops.at(-1);
        const traceOpened =
          trace?.report &&
          !trace.limitation &&
          (!sandbox || sandbox.report.finalUrl === trace.report.finalUrl) &&
          (!tracedDestination?.status || tracedDestination.status < 400);
        evidence.destinationUnavailable =
          !(sandbox && !sandbox.navigationFailed) && !traceOpened;
        if (evidence.social?.profile) evidence.destinationUnavailable = false;
      }
      if (evidence.link) {
        const traced = trace?.report?.hops ?? [];
        const browsed = sandbox?.report.hops ?? [];
        const overlap = browsed.findLastIndex(
          (hop) => hop.url === traced.at(-1)?.url,
        );
        evidence.link.hops = [...traced, ...browsed.slice(overlap + 1)].slice(
          0,
          20,
        );
        const [age, matches] = await Promise.allSettled([
          (deps.age ?? domainAge)(evidence.link.finalUrl),
          deps.intel.match(
            extractIndicators("", [
              evidence.link.finalUrl,
              ...evidence.link.hops.map((hop) => hop.url),
            ]),
            request.locale,
          ),
        ]);
        if (age.status === "fulfilled" && age.value !== undefined)
          evidence.link.domainAgeDays = age.value;
        else evidence.limitations.push("domain");
        if (matches.status === "fulfilled")
          evidence.intel = [
            ...new Map(
              [...evidence.intel, ...matches.value].map((item) => [
                item.id,
                item,
              ]),
            ).values(),
          ];
        else evidence.limitations.push("intel");
      }
      await step(
        "intel",
        evidence.limitations.includes("intel") ? "failed" : "done",
      );
      await step("verdict", "running");
      const verdict = await createVerdict(request, evidence, model);
      await step("verdict", "done");
      await deps.checks.finish(id, verdict, screenshotKey);
      count("CheckCompleted");
    } catch {
      await deps.checks.fail(id);
      count("CheckFailed");
    } finally {
      if (record.photoKey && !photoDeleted)
        await deps.media
          .delete(record.photoKey)
          .catch(() => count("PhotoDeletionFailed"));
    }
  };
}

export const handler = (event: { id: string }): Promise<void> =>
  measured("check", () =>
    createWorker({
      checks: new DynamoCheckStore(env("CHECKS_TABLE")),
      media: new S3MediaStore(env("MEDIA_BUCKET")),
      intel: new DynamoIntelStore(env("INTEL_TABLE")),
      model: () => new BedrockModel(),
    })(event),
  );
