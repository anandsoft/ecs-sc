import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api/catalog": {
        target: "http://127.0.0.1:8081",
        rewrite: (path) => path.replace(/^\/api\/catalog/, ""),
      },
      "/api/sales": {
        target: "http://127.0.0.1:8082",
        rewrite: (path) => path.replace(/^\/api\/sales/, ""),
      },
    },
  },
});
