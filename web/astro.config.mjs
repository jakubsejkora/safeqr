import { defineConfig } from "astro/config";
export default defineConfig({
  site: "https://safeqr.cz",
  output: "static",
  compressHTML: true,
  trailingSlash: "always",
  build: { inlineStylesheets: "never" },
  vite: { build: { assetsInlineLimit: 0 } },
});
