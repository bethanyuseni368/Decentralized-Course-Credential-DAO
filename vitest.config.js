import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "clarinet",
    globals: true,
    testTimeout: 30000,
    hookTimeout: 30000,
    teardownTimeout: 30000,
    singleThread: true
  },
});
