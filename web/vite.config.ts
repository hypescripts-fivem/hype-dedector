import { fileURLToPath, URL } from "url";

import { defineConfig } from "vite";

import tailwindcss from "@tailwindcss/vite";

import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    fs: {
      allow: [fileURLToPath(new URL("..", import.meta.url))],
    },
  },
  build: {
    outDir: "./dist",
    emptyOutDir: true,
    // echarts (bar + canvas, tree-shaken) is one large chunk; NUI loads from disk so the size is only a warning
    chunkSizeWarningLimit: 700,
    rolldownOptions: {
      // Only reports how long plugins (vue, tailwind) took; a 3s build has nothing to tune
      checks: { bundlerTimings: false },
    },
  },
  base: "./",
});