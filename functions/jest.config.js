/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  globals: {
    "ts-jest": {
      tsconfig: "tsconfig.test.json",
    },
  },
  testMatch: ["**/__tests__/**/*.test.ts"],
  testTimeout: 60_000,
};
