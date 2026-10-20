import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { decode } from "bysquare/pay";
import jsQR from "jsqr";
import sharp from "sharp";
import { EXAMPLE_IBAN, gallery } from "../src/data/gallery.ts";
import { kitCodes } from "../src/data/kit.ts";
import { qrImage } from "../src/lib/qr.ts";

async function decoded(svg: Buffer, width = 1200) {
  const { data, info } = await sharp(svg)
    .resize(width, width)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  return jsQR(new Uint8ClampedArray(data), info.width, info.height)?.data;
}
for (const item of gallery) {
  const svg = await readFile(`dist/qr/${item.id}.svg`);
  assert.equal(
    await decoded(svg, item.arrangement === "nested" ? 292 : 1200),
    item.payload,
    `QR mismatch: ${item.id}`,
  );
  if (item.secondPayload)
    assert.equal(
      await decoded(await readFile(`dist/qr/${item.id}-second.svg`)),
      item.secondPayload,
      `Second QR mismatch: ${item.id}`,
    );
  if (item.arrangement === "nested") {
    const { inset } = await qrImage(item.payload, item.secondPayload);
    assert.ok(inset);
    const scale = 20;
    const full = await sharp(svg)
      .resize(inset.extent * scale, inset.extent * scale)
      .png()
      .toBuffer();
    const crop = await sharp(full)
      .extract({
        left: Math.round(inset.x * scale),
        top: Math.round(inset.y * scale),
        width: inset.size * scale,
        height: inset.size * scale,
      })
      .png()
      .toBuffer();
    assert.equal(
      await decoded(crop),
      item.secondPayload,
      "Inner QR must decode from the actual composite image",
    );
  }
  if (item.id === "pay-by-square")
    assert.equal(decode(item.payload).payments[0]?.bankAccounts[0]?.iban, EXAMPLE_IBAN);
}
for (const item of Object.values(kitCodes)) {
  assert.equal(
    await decoded(await readFile(`dist/qr/${item.id}.svg`)),
    item.payload,
    `Print kit QR mismatch: ${item.id}`,
  );
}
console.log(
  `Decoded all ${gallery.length} gallery SVGs, second codes, both layers of the nested QR, and ${Object.keys(kitCodes).length} print kit SVGs. PAY by square round-trip verified.`,
);
