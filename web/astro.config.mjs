import { defineConfig } from "astro/config";
export default defineConfig({
  site: "https://bezpecneqr.cz",
  output: "static",
  compressHTML: true,
  trailingSlash: "always",
  build: { inlineStylesheets: "never" },
  vite: { build: { assetsInlineLimit: 0 } },
});
