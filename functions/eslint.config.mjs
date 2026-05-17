import tsPlugin from "@typescript-eslint/eslint-plugin";
import importX from "eslint-plugin-import-x";
import prettierConfig from "eslint-config-prettier";
import globals from "globals";

export default [
  {ignores: ["lib/**/*", "generated/**/*", "eslint.config.mjs", "jest.config.js", "jest.integration.config.js", "src/**/__tests__/**"]},
  ...tsPlugin.configs["flat/recommended"],
  importX.flatConfigs.recommended,
  {
    languageOptions: {
      parserOptions: {
        project: ["tsconfig.json"],
        sourceType: "module",
      },
      globals: {...globals.es6, ...globals.node},
    },
    rules: {
      "import-x/no-unresolved": "off",
    },
  },
  prettierConfig,
];
