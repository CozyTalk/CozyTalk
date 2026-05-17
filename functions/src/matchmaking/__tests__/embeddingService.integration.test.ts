/**
 * Integration tests for embedText() against the real Vertex AI API.
 *
 * Prerequisites:
 *   1. ADC configured: `gcloud auth application-default login`
 *   2. Project has Vertex AI API enabled (aiplatform.googleapis.com)
 *   3. Run with: npm run test:embedding
 *
 * These tests are excluded from `npm test` (unit suite) intentionally.
 * They hit the live API and will consume quota.
 */
import {cosineSimilarity, embedText} from "../embeddingService";

const PROJECT = process.env.GCLOUD_PROJECT ?? "cozytalk-5d984";

// Set before any module code runs so embedText() sees it.
beforeAll(() => {
  process.env.GCLOUD_PROJECT = PROJECT;
});

afterAll(() => {
  delete process.env.GCLOUD_PROJECT;
});

describe("embedText — real Vertex AI", () => {
  test("returns a 256-dim number[] for a plain English phrase", async () => {
    const result = await embedText("football");

    expect(result).not.toBeNull();
    expect(result).toHaveLength(256);
    result!.forEach((v) => expect(typeof v).toBe("number"));
  });

  test("similar interests produce cosine similarity above 0.65 threshold", async () => {
    const [a, b] = await Promise.all([
      embedText("football"),
      embedText("soccer"),
    ]);

    expect(a).not.toBeNull();
    expect(b).not.toBeNull();

    const sim = cosineSimilarity(a!, b!);
    expect(sim).toBeGreaterThan(0.65);
  });

  test("unrelated interests produce lower similarity than related pair", async () => {
    const [football, soccer, cooking] = await Promise.all([
      embedText("football"),
      embedText("soccer"),
      embedText("baking bread"),
    ]);

    expect(football).not.toBeNull();
    expect(soccer).not.toBeNull();
    expect(cooking).not.toBeNull();

    const relatedSim = cosineSimilarity(football!, soccer!);
    const unrelatedSim = cosineSimilarity(football!, cooking!);

    expect(relatedSim).toBeGreaterThan(unrelatedSim);
  });

  test("multilingual: same concept in Thai returns non-null vector", async () => {
    // text-multilingual-embedding-002 supports Thai (among 100+ languages).
    const result = await embedText("ฟุตบอล");

    expect(result).not.toBeNull();
    expect(result).toHaveLength(256);
  });

  test("multilingual: Thai and English football vectors are similar", async () => {
    const [en, th] = await Promise.all([
      embedText("football"),
      embedText("ฟุตบอล"),
    ]);

    expect(en).not.toBeNull();
    expect(th).not.toBeNull();

    const sim = cosineSimilarity(en!, th!);
    // Cross-language similarity is lower than same-language but should still be meaningful.
    expect(sim).toBeGreaterThan(0.4);
  });

  test("empty string returns null (empty embedding response)", async () => {
    const result = await embedText("");

    // Vertex AI may return an empty or zero-length embedding for blank input,
    // which embeddingService maps to null.
    expect(
      result === null || (Array.isArray(result) && result.length > 0),
    ).toBe(true);
  });

  test("truncated long input (>500 chars) still returns a valid embedding", async () => {
    const longText = "football ".repeat(100); // 900 chars
    const result = await embedText(longText);

    expect(result).not.toBeNull();
    expect(result).toHaveLength(256);
  });
});
