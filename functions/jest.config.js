/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: "node",
  transform: {
    "^.+\\.tsx?$": ["ts-jest", {
      tsconfig: "tsconfig.test.json",
      isolatedModules: true,
    }],
  },
  setupFilesAfterEnv: ["<rootDir>/jest.setup.ts"],
  testMatch: ["**/__tests__/**/*.test.ts"],
  testPathIgnorePatterns: ["/node_modules/", "\\.integration\\.test\\.ts$"],
  testTimeout: 60_000,
  // Test suites share a single Firebase emulator instance. Running them in
  // parallel causes resetEmulatorData() in one suite to wipe state being
  // actively used by the other, producing non-deterministic failures.
  maxWorkers: 1,
};
