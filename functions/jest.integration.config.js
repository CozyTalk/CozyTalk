/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  globals: {
    "ts-jest": {
      tsconfig: "tsconfig.test.json",
    },
  },
  testMatch: ["**/__tests__/**/*.integration.test.ts"],
  // Vertex AI round-trips can take a few seconds each; allow the same budget as unit tests.
  testTimeout: 60_000,
  maxWorkers: 1,
};
