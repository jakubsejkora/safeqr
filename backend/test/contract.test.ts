import { readFileSync } from "node:fs";
import { Ajv2020 } from "ajv/dist/2020.js";
import formats from "ajv-formats";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import { z } from "zod";
import fixtures from "../../spec/fixtures/codes.json" with { type: "json" };
import seeds from "../data/verified-cases.json" with { type: "json" };
import { deterministicVerdict } from "../src/checks/verdict/agent.js";
import { publicCase, validateCase } from "../src/intel/schema.js";
import {
  acceptedSchema,
  caseSchema,
  checkSchema,
  findingSchema,
  kindSchema,
  linkSchema,
  localeSchema,
  requestSchema,
  sceneSchema,
  stepSchema,
  verdictSchema,
} from "../src/shared/schemas.js";
import { request } from "./helpers.js";

const spec = parse(
  readFileSync(new URL("../../spec/openapi.yaml", import.meta.url), "utf8"),
);
const ajv = new Ajv2020({ strict: false });
formats.default(ajv);
const validate = (name: string, value: unknown) =>
  ajv.compile({
    ...spec.components.schemas[name],
    components: spec.components,
  })(value);

describe("shared OpenAPI contract", () => {
  it("accepts every shared code fixture and preserves each supplied device risk floor", () => {
    for (const fixture of fixtures) {
      const floor =
        fixture.expected.level === "danger"
          ? 70
          : fixture.expected.level === "caution"
            ? 30
            : 0;
      const input = requestSchema.parse({
        payload: fixture.raw,
        kind: fixture.expected.kind,
        locale: fixture.locale.startsWith("cs") ? "cs" : "en",
        device: { score: floor, floor, findingIds: fixture.expected.findings },
      });
      const verdict = deterministicVerdict(input, {
        intel: [],
        limitations: [],
      });
      expect(validate("CheckRequest", input), fixture.id).toBe(true);
      expect(validate("Verdict", verdict), fixture.id).toBe(true);
      expect(verdict.score, fixture.id).toBeGreaterThanOrEqual(floor);
    }
  });
  it("mirrors required fields, property names and enums without altering the shared spec", () => {
    const schemas = {
      CheckRequest: requestSchema,
      CheckAccepted: acceptedSchema,
      Check: checkSchema,
      Step: stepSchema,
      Verdict: verdictSchema,
      Finding: findingSchema,
      LinkReport: linkSchema,
      SceneReport: sceneSchema,
      Case: caseSchema,
    };
    for (const [name, schema] of Object.entries(schemas)) {
      const generated = z.toJSONSchema(schema);
      expect(Object.keys(generated.properties ?? {}).sort()).toEqual(
        Object.keys(spec.components.schemas[name].properties).sort(),
      );
      expect(generated.required?.slice().sort()).toEqual(
        spec.components.schemas[name].required.slice().sort(),
      );
    }
    expect(kindSchema.options).toEqual(spec.components.schemas.CodeKind.enum);
    expect(localeSchema.options).toEqual(spec.components.schemas.Locale.enum);
  });
  it("emits contract-valid deterministic verdicts and bilingual source cases", () => {
    for (const locale of ["cs", "en"] as const) {
      expect(
        validate(
          "Verdict",
          deterministicVerdict(
            { ...request, locale },
            { intel: [], limitations: ["sandbox"] },
          ),
        ),
      ).toBe(true);
      for (const seed of seeds)
        expect(
          validate(
            "Case",
            publicCase({ ...seed, record: validateCase(seed.record) }, locale),
          ),
        ).toBe(true);
    }
  });
  it("requires the on-device assessment and honors code size and score limits", () => {
    expect(
      requestSchema.safeParse({ ...request, device: undefined }).success,
    ).toBe(false);
    expect(
      requestSchema.safeParse({ ...request, payload: "x".repeat(4097) })
        .success,
    ).toBe(false);
    expect(
      requestSchema.safeParse({
        ...request,
        device: { ...request.device, floor: 101 },
      }).success,
    ).toBe(false);
    expect(validate("CheckRequest", request)).toBe(true);
  });
});
