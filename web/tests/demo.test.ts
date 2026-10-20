import assert from "node:assert/strict";
import { test } from "node:test";
import demo from "../demo/index.ts";

test("the fictional profile exposes five training links without indexing or automatic requests", async () => {
  const response = await demo.fetch(new Request("https://training.test/bio"));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("X-Robots-Tag"), "noindex, nofollow");
  const html = await response.text();
  const links = [...html.matchAll(/<a href="([^"]+)" rel="nofollow noopener"/g)];
  assert.deepEqual(
    links.map((link) => link[1]),
    [
      "https://onlyfans.com/klara-training",
      "https://t.me/klara_training",
      "https://bit.ly/klara-vip",
      "https://linktr.ee/klara-training",
      "https://instagram.com/klara.training",
    ],
  );
  assert.match(html, /Tréninková ukázka Safe QR/);
  assert.match(html, /smyšlená postava/);
  assert.doesNotMatch(html, /<script|<form|<img|(?:src|href)="\/\//);
  const start = await demo.fetch(new Request("https://training.test/start"));
  assert.equal(start.status, 302);
  assert.equal(start.headers.get("Location"), "/step-2");
});
