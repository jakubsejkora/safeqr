import QRCode from "qrcode";
export interface QRImage {
  svg: string;
  payload: string;
  innerPayload?: string;
  inset?: { x: number; y: number; size: number; extent: number };
}
export async function qrImage(payload: string, innerPayload?: string): Promise<QRImage> {
  if (!innerPayload)
    return {
      payload,
      svg: await QRCode.toString(payload, {
        type: "svg",
        errorCorrectionLevel: "H",
        margin: 4,
        color: { dark: "#102e2a", light: "#ffffff" },
      }),
    };
  // A high-version outer symbol leaves enough independent modules for a readable inner code.
  const outer = QRCode.create(payload, { version: 12, errorCorrectionLevel: "H" });
  const inner = QRCode.create(innerPayload, { errorCorrectionLevel: "L" });
  const extent = outer.modules.size + 8;
  const size = 18;
  const x = (extent - size) / 2;
  const path = (qr: ReturnType<typeof QRCode.create>) => {
    let d = "";
    for (let row = 0; row < qr.modules.size; row++)
      for (let col = 0; col < qr.modules.size; col++)
        if (qr.modules.get(row, col)) d += `M${col + 4} ${row + 4}h1v1h-1z`;
    return d;
  };
  return {
    payload,
    innerPayload,
    inset: { x, y: x, size, extent },
    svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${extent} ${extent}" shape-rendering="crispEdges"><path fill="#fff" d="M0 0h${extent}v${extent}H0z"/><path fill="#102e2a" d="${path(outer)}"/><svg x="${x}" y="${x}" width="${size}" height="${size}" viewBox="0 0 ${inner.modules.size + 8} ${inner.modules.size + 8}"><path fill="#fff" d="M0 0h${inner.modules.size + 8}v${inner.modules.size + 8}H0z"/><path fill="#102e2a" d="${path(inner)}"/></svg></svg>`,
  };
}
