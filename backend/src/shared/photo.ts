/** Validates JPEG structure and drops metadata that can contain a location or a name. */
export function cleanPhoto(encoded: string): Uint8Array {
  if (
    !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(
      encoded,
    )
  )
    throw new Error("Invalid image");
  const bytes = Buffer.from(encoded, "base64");
  if (
    bytes.length < 20 ||
    bytes[0] !== 0xff ||
    bytes[1] !== 0xd8 ||
    bytes.at(-2) !== 0xff ||
    bytes.at(-1) !== 0xd9
  )
    throw new Error("Invalid JPEG");
  const parts = [bytes.subarray(0, 2)];
  let dimensions = false;
  let scanned = false;
  let offset = 2;
  while (offset < bytes.length) {
    const start = offset;
    if (bytes[offset++] !== 0xff) throw new Error("Invalid JPEG marker");
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xd9) {
      if (!scanned || offset !== bytes.length)
        throw new Error("Incomplete JPEG");
      parts.push(bytes.subarray(start, offset));
      return Buffer.concat(parts);
    }
    if (marker === undefined || marker === 0 || marker === 0xd8)
      throw new Error("Invalid JPEG marker");
    const length = bytes.readUInt16BE(offset);
    const end = offset + length;
    if (length < 2 || end > bytes.length - 2)
      throw new Error("Invalid JPEG segment");
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      if (length < 8) throw new Error("Invalid image dimensions");
      const height = bytes.readUInt16BE(offset + 3);
      const width = bytes.readUInt16BE(offset + 5);
      if (
        !height ||
        !width ||
        height > 4096 ||
        width > 4096 ||
        height * width > 12_000_000
      )
        throw new Error("Image dimensions too large");
      dimensions = true;
    }
    if (marker === 0xda) {
      if (!dimensions) throw new Error("Missing image dimensions");
      scanned = true;
      let next = end;
      while (next < bytes.length - 1) {
        if (bytes[next] !== 0xff) {
          next++;
          continue;
        }
        const following = bytes[next + 1];
        if (
          following === 0 ||
          (following !== undefined && following >= 0xd0 && following <= 0xd7)
        ) {
          next += 2;
          continue;
        }
        break;
      }
      parts.push(bytes.subarray(start, next));
      offset = next;
      continue;
    }
    if (!(marker >= 0xe1 && marker <= 0xef) && marker !== 0xfe)
      parts.push(bytes.subarray(start, end));
    offset = end;
  }
  throw new Error("Missing JPEG scan");
}
