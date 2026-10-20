import { describe, expect, it, vi } from "vitest";
import { domainAge } from "../src/checks/link/domain.js";
import { traceLink } from "../src/checks/link/tracer.js";
import {
  linkTarget,
  publicAddress,
  publicTarget,
  UnsafeUrl,
  type WebFetch,
  type WebResponse,
  webUrl,
} from "../src/shared/network.js";

const page = (status: number, headers = {}, body = ""): WebResponse => ({
  status,
  headers,
  body: Buffer.from(body),
});

describe("SSRF boundaries", () => {
  it("uses the device's HTTPS default for a bare domain without changing schemes", () => {
    expect(linkTarget("safeqr.cz/path")).toBe("https://safeqr.cz/path");
    expect(linkTarget("file:///etc/passwd")).toBe("file:///etc/passwd");
    expect(() => webUrl("https://example.com/\\\\private")).toThrow(UnsafeUrl);
  });
  it.each([
    "127.0.0.1",
    "0.0.0.0",
    "10.2.3.4",
    "172.16.2.1",
    "192.168.1.1",
    "100.64.0.1",
    "169.254.169.254",
    "192.0.0.8",
    "198.18.0.1",
    "192.0.2.1",
    "224.0.0.1",
    "240.0.0.1",
    "::1",
    "::",
    "fe80::1",
    "fc00::1",
    "::ffff:127.0.0.1",
    "2001:db8::1",
    "2002:7f00:1::1",
    "64:ff9b::a00:1",
  ])("rejects reserved address %s", (address) =>
    expect(publicAddress(address)).toBe(false),
  );
  it.each(["8.8.8.8", "93.184.216.34", "2606:4700:4700::1111"])(
    "accepts public address %s",
    (address) => expect(publicAddress(address)).toBe(true),
  );
  it.each([
    "file:///etc/passwd",
    "https://user:secret@example.com",
    "http://localhost",
    "http://printer.local",
    "https://example.com:444",
    "https://example.com.",
  ])("rejects unsupported target %s", (url) =>
    expect(() => webUrl(url)).toThrow(UnsafeUrl),
  );
  it.each(["http://2130706433/", "http://0x7f000001/", "http://0177.0.0.1/"])(
    "normalizes and blocks alternate IP notation %s",
    async (url) => expect(publicTarget(url)).rejects.toThrow(UnsafeUrl),
  );
  it("rejects a hostname when any resolved address is private", async () => {
    await expect(
      publicTarget("https://example.com", async () => [
        { address: "8.8.8.8", family: 4 },
        { address: "127.0.0.1", family: 4 },
      ]),
    ).rejects.toThrow(UnsafeUrl);
  });
  it("pins the validated address and does not reuse a DNS result", async () => {
    const dns = vi
      .fn()
      .mockResolvedValueOnce([{ address: "8.8.8.8", family: 4 }])
      .mockResolvedValueOnce([{ address: "127.0.0.1", family: 4 }]);
    expect((await publicTarget("https://example.com", dns)).address).toBe(
      "8.8.8.8",
    );
    await expect(publicTarget("https://example.com", dns)).rejects.toThrow(
      UnsafeUrl,
    );
  });
});

describe("redirect and domain evidence", () => {
  it.each([302, 403, 404, 429, 500, 503])(
    "does not treat HTTP %i without a redirect target as a successful inspection",
    async (status) => {
      const fetch = vi.fn<WebFetch>().mockResolvedValue(page(status));
      const result = await traceLink("https://example.com/", fetch);
      expect(result.limitation).toBe("unavailable");
      expect(result.report?.hops).toEqual([
        { url: "https://example.com/", status, via: "http" },
      ]);
      expect(fetch).toHaveBeenCalledOnce();
    },
  );
  it("follows relative HTTP and quoted meta redirects", async () => {
    const fetch = vi
      .fn<WebFetch>()
      .mockResolvedValueOnce(page(302, { location: "/next" }))
      .mockResolvedValueOnce(
        page(
          200,
          { "content-type": "text/html" },
          '<meta http-equiv="Refresh" content="0; URL=\'https://final.example/\'"><title>Wait</title>',
        ),
      )
      .mockResolvedValueOnce(
        page(
          200,
          { "content-type": "text/html" },
          "<title>Destination</title>",
        ),
      );
    const result = await traceLink("https://example.com", fetch);
    expect(result.report?.finalUrl).toBe("https://final.example/");
    expect(result.report?.hops.map((hop) => hop.via)).toEqual([
      "http",
      "http",
      "meta",
    ]);
    expect(result.report?.pageTitle).toBe("Destination");
  });
  it("blocks an unsafe redirect before issuing its request", async () => {
    const fetch = vi
      .fn<WebFetch>()
      .mockResolvedValue(page(302, { location: "file:///etc/passwd" }));
    expect((await traceLink("https://example.com", fetch)).limitation).toBe(
      "blocked",
    );
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("caps redirect loops and never makes more than ten requests", async () => {
    const fetch = vi
      .fn<WebFetch>()
      .mockImplementation(async (url) => page(302, { location: `${url}next` }));
    expect((await traceLink("https://example.com", fetch)).limitation).toBe(
      "hopLimit",
    );
    expect(fetch).toHaveBeenCalledTimes(10);
  });
  it("reads only the start of large pages while tracing", async () => {
    const fetch = vi
      .fn<WebFetch>()
      .mockResolvedValueOnce(
        page(303, { location: "https://www.example.com/watch" }),
      )
      .mockResolvedValueOnce(
        page(200, { "content-type": "text/html" }, "<title>Video</title>"),
      );
    const trace = await traceLink("https://example.com/v", fetch);
    expect(trace.report?.finalUrl).toBe("https://www.example.com/watch");
    expect(trace.report?.pageTitle).toBe("Video");
    expect(fetch.mock.calls.every(([, options]) => options?.truncate)).toBe(
      true,
    );
  });
  it("degrades on timeouts and oversized bodies", async () => {
    expect(
      await traceLink("https://example.com", async () => {
        throw new Error("Response too large");
      }),
    ).toEqual({ limitation: "unavailable" });
  });
  it("uses the registrable domain and only the registration event", async () => {
    const fetch = vi.fn<WebFetch>().mockResolvedValue(
      page(
        200,
        {},
        JSON.stringify({
          events: [
            { eventAction: "last changed", eventDate: "2020-01-01" },
            {
              eventAction: "registration",
              eventDate: new Date(Date.now() - 10 * 86400000).toISOString(),
            },
          ],
          entities: [{ personalData: "must not be returned" }],
        }),
      ),
    );
    expect(await domainAge("https://login.parking.co.uk/pay", fetch)).toBe(10);
    expect(fetch.mock.calls[0]?.[0]).toBe(
      "https://rdap.org/domain/parking.co.uk",
    );
  });
});
