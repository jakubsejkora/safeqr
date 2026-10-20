import { MODELS } from "../../shared/config.js";
import type { Model } from "../../shared/model.js";
import { describePayload } from "../../shared/privacy.js";
import { type SceneReport, sceneSchema } from "../../shared/schemas.js";
import type { StoredRequest } from "../../shared/storage.js";
import { SCENE_PROMPT } from "./prompt.v2.js";

export function inspectScene(
  request: StoredRequest,
  image: Uint8Array,
  model: Model,
  destination?: string,
): Promise<SceneReport> {
  return model.ask({
    model: MODELS.sonnet,
    system: SCENE_PROMPT,
    schema: sceneSchema,
    data: {
      locale: request.locale,
      kind: request.kind,
      content: describePayload(request.kind, request.payload),
      codeBounds: request.scene?.codeBounds,
      destination: destination && new URL(destination).hostname,
    },
    image,
    maxTokens: 600,
  });
}
