import { describe, expect, it } from "vitest";
import { cleanPhoto } from "../src/shared/photo.js";

const frame = Buffer.from([0xff, 0xc0, 0, 11, 8, 0, 1, 0, 1, 1, 1, 0x11, 0]);
const scan = Buffer.from([
  0xff, 0xda, 0, 8, 1, 1, 0, 0, 63, 0, 0x12, 0x34, 0xff, 0xd9,
]);
const metadata = Buffer.from("Exif private location");
const marker = Buffer.alloc(4);
marker[0] = 0xff;
marker[1] = 0xe1;
marker.writeUInt16BE(metadata.length + 2, 2);

describe("photo minimization", () => {
  it("removes JPEG metadata before temporary storage or inference", () => {
    const input = Buffer.concat([
      Buffer.from([0xff, 0xd8]),
      marker,
      metadata,
      frame,
      scan,
    ]);
    const output = Buffer.from(cleanPhoto(input.toString("base64")));
    expect(output.includes(metadata)).toBe(false);
    expect(output.subarray(-scan.length)).toEqual(scan);
  });
  it("rejects invalid base64, missing scans and excessive dimensions", () => {
    expect(() => cleanPhoto("not an image")).toThrow();
    expect(() =>
      cleanPhoto(Buffer.from([0xff, 0xd8, 0xff, 0xd9]).toString("base64")),
    ).toThrow();
    const huge = Buffer.from(frame);
    huge.writeUInt16BE(9000, 5);
    expect(() =>
      cleanPhoto(
        Buffer.concat([Buffer.from([0xff, 0xd8]), huge, scan]).toString(
          "base64",
        ),
      ),
    ).toThrow("dimensions");
  });
  it("also removes metadata between progressive scans", () => {
    const input = Buffer.concat([
      Buffer.from([0xff, 0xd8]),
      frame,
      scan.subarray(0, -2),
      marker,
      metadata,
      scan,
    ]);
    expect(
      Buffer.from(cleanPhoto(input.toString("base64"))).includes(metadata),
    ).toBe(false);
  });
});
