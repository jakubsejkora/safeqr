import { lookup } from "node:dns/promises";
import http from "node:http";
import https from "node:https";
import { isIP } from "node:net";
import ipaddr from "ipaddr.js";
import { LIMITS } from "./config.js";

export class UnsafeUrl extends Error {}
export type Resolver = (
  hostname: string,
) => Promise<{ address: string; family: number }[]>;
const resolve: Resolver = (hostname) =>
  lookup(hostname, { all: true, verbatim: true });

/** Mirrors the device's HTTPS default for codes containing a bare domain. */
export function linkTarget(payload: string): string {
  const input = payload.trim();
  return !/\s/.test(input) &&
    /^(?:[\p{L}\p{N}-]+\.)+[\p{L}]{2,63}(?::[0-9]{1,5})?(?:[/?#].*)?$/u.test(
      input,
    )
    ? `https://${input}`
    : input;
}

export function publicAddress(address: string): boolean {
  try {
    const parsed = ipaddr.parse(address);
    if (parsed.range() !== "unicast") return false;
    if (parsed.kind() === "ipv4") {
      const blocked = [
        "192.0.0.0/24",
        "192.88.99.0/24",
        "198.18.0.0/15",
        "192.175.48.0/24",
      ];
      return !blocked.some((cidr) => parsed.match(ipaddr.parseCIDR(cidr)));
    }
    return (
      parsed.match(ipaddr.parseCIDR("2000::/3")) &&
      !["2001::/23", "2002::/16", "3fff::/20"].some((cidr) =>
        parsed.match(ipaddr.parseCIDR(cidr)),
      )
    );
  } catch {
    return false;
  }
}

export function webUrl(input: string): URL {
  if (
    input.includes("\\") ||
    [...input].some(
      (character) =>
        character.charCodeAt(0) <= 32 || character.charCodeAt(0) === 127,
    )
  )
    throw new UnsafeUrl("Invalid link");
  let url: URL;
  try {
    url = new URL(input);
  } catch {
    throw new UnsafeUrl("Invalid link");
  }
  if (
    !["http:", "https:"].includes(url.protocol) ||
    url.username ||
    url.password ||
    (url.port && !["80", "443"].includes(url.port))
  )
    throw new UnsafeUrl("Unsupported link");
  const hostname = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (
    !hostname ||
    hostname.endsWith(".") ||
    /(^|\.)(localhost|local|internal|home|test|invalid|onion)$/.test(hostname)
  )
    throw new UnsafeUrl("Private destination");
  url.hash = "";
  return url;
}

export async function publicTarget(
  input: string,
  resolver: Resolver = resolve,
): Promise<{ url: URL; address: string; family: number }> {
  const url = webUrl(input);
  const hostname = url.hostname.replace(/^\[|\]$/g, "");
  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    const addresses = isIP(hostname)
      ? [{ address: hostname, family: isIP(hostname) }]
      : await Promise.race([
          resolver(hostname),
          new Promise<never>((_, reject) => {
            timeout = setTimeout(() => reject(new Error("DNS timeout")), 1500);
          }),
        ]);
    if (
      !addresses.length ||
      addresses.some(({ address }) => !publicAddress(address))
    )
      throw new UnsafeUrl("Private destination");
    const address = addresses[0];
    if (!address) throw new UnsafeUrl("Unresolved destination");
    return { url, ...address };
  } finally {
    clearTimeout(timeout);
  }
}

export interface WebResponse {
  status: number;
  headers: Record<string, string>;
  body: Buffer;
}
export type WebFetch = (
  url: string,
  options?: { signal?: AbortSignal; maxBytes?: number },
) => Promise<WebResponse>;

/** Fetches one hop using a validated, pinned IP; never forwards caller credentials. */
export const safeFetch: WebFetch = async (input, options = {}) => {
  const { url, address, family } = await publicTarget(input);
  const signal = options.signal ?? AbortSignal.timeout(4000);
  signal.throwIfAborted();
  return new Promise((resolveResponse, reject) => {
    const request = (url.protocol === "https:" ? https : http).request(
      {
        hostname: address,
        family,
        servername: isIP(url.hostname.replace(/^\[|\]$/g, ""))
          ? undefined
          : url.hostname,
        port: url.port || (url.protocol === "https:" ? 443 : 80),
        method: "GET",
        path: `${url.pathname}${url.search}`,
        agent: false,
        signal,
        headers: {
          Host: url.host,
          "User-Agent": "SafeQR/1.0",
          Accept: "*/*",
          "Accept-Encoding": "identity",
        },
      },
      (response) => {
        const chunks: Buffer[] = [];
        let size = 0;
        response.on("data", (chunk: Buffer) => {
          size += chunk.length;
          if (size > (options.maxBytes ?? LIMITS.linkBytes)) {
            request.destroy(new Error("Response too large"));
            return;
          }
          chunks.push(chunk);
        });
        response.on("error", () => reject(new Error("Response unavailable")));
        response.on("end", () => {
          const headers: Record<string, string> = {};
          for (const name of [
            "content-type",
            "location",
            "refresh",
            "content-disposition",
            "content-encoding",
          ]) {
            const value = response.headers[name];
            if (typeof value === "string") headers[name] = value;
          }
          resolveResponse({
            status: response.statusCode ?? 502,
            headers,
            body: Buffer.concat(chunks),
          });
        });
      },
    );
    request.on("error", () => reject(new Error("Destination unavailable")));
    request.end();
  });
};
