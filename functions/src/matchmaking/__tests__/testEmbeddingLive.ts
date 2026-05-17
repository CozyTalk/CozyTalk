/**
 * Manual live test for the embedding service.
 * Run with: npx ts-node -P tsconfig.test.json src/matchmaking/__tests__/testEmbeddingLive.ts
 *
 * Requires:
 *   - gcloud auth application-default login
 *   - GCLOUD_PROJECT env var (or pass --project flag)
 *   - Vertex AI API enabled on the project
 */

import {embedText, cosineSimilarity} from "../embeddingService";

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? "cozytalk-5d984";

const pairs: Array<{a: string; b: string; expectHigh: boolean}> = [
  {a: "I love football", b: "soccer is my favourite sport", expectHigh: true},
  {a: "I love cooking pasta", b: "baking bread is my hobby", expectHigh: true},
  {a: "I love football", b: "I enjoy baking cakes", expectHigh: false},
  {a: "music and concerts", b: "playing guitar", expectHigh: true},
];

async function run(): Promise<void> {
  console.log("Embedding service live test\n");

  // 1. Embed a single phrase and check shape.
  const vec = await embedText("Hello, world!");
  if (!vec) {
    console.error("❌  embedText returned null — check your ADC credentials.");
    process.exit(1);
  }
  console.log(`✅  embedText returned ${vec.length}-dim vector (expected 256)`);
  if (vec.length !== 256) {
    console.error("❌  Unexpected dimension:", vec.length);
    process.exit(1);
  }

  // 2. Similarity tests.
  console.log("\nSimilarity tests (threshold = 0.65):\n");
  let allPassed = true;
  for (const {a, b, expectHigh} of pairs) {
    const [va, vb] = await Promise.all([embedText(a), embedText(b)]);
    if (!va || !vb) {
      console.error(`❌  Failed to embed: "${a}" or "${b}"`);
      allPassed = false;
      continue;
    }
    const sim = cosineSimilarity(va, vb);
    const passed = expectHigh ? sim >= 0.65 : sim < 0.65;
    const icon = passed ? "✅" : "❌";
    console.log(
      `${icon}  sim=${sim.toFixed(3)}  [${expectHigh ? "SHOULD match" : "should NOT match"}]`,
    );
    console.log(`     "${a}"`);
    console.log(`     "${b}"\n`);
    if (!passed) {
      allPassed = false;
    }
  }

  if (allPassed) {
    console.log("All tests passed ✅");
  } else {
    console.log(
      "Some tests failed ❌  — consider adjusting INTEREST_SIMILARITY_THRESHOLD",
    );
    process.exit(1);
  }
}

run().catch((e) => {
  console.error("Fatal:", e);
  process.exit(1);
});
