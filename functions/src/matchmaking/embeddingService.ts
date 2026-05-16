import {v1, helpers} from "@google-cloud/aiplatform";
import * as logger from "firebase-functions/logger";

const EMBEDDING_MODEL = "text-multilingual-embedding-002";
const EMBEDDING_DIMS = 256;
const EMBEDDING_LOCATION = "us-central1";

export const INTEREST_SIMILARITY_THRESHOLD = 0.65;

let _client: v1.PredictionServiceClient | null = null;

/**
 * Returns a lazily-initialised Vertex AI prediction client.
 * Reuses the same instance across invocations within the same Function instance.
 * @return {v1.PredictionServiceClient} Singleton prediction client.
 */
function _getClient(): v1.PredictionServiceClient {
  if (!_client) {
    _client = new v1.PredictionServiceClient({
      apiEndpoint: `${EMBEDDING_LOCATION}-aiplatform.googleapis.com`,
    });
  }
  return _client;
}

/**
 * Embeds text using Vertex AI text-multilingual-embedding-002 (256 dims,
 * SEMANTIC_SIMILARITY task type). Truncates input to 500 chars before sending.
 * Returns null on any failure — callers must degrade to random matching gracefully.
 * Requires GCLOUD_PROJECT env var (set automatically by Firebase Functions runtime).
 * @param {string} text - The interest phrase to embed.
 * @return {Promise<number[] | null>} 256-dim vector, or null on error.
 */
export async function embedText(text: string): Promise<number[] | null> {
  try {
    const project = process.env.GCLOUD_PROJECT;
    if (!project) {
      logger.warn("GCLOUD_PROJECT not set — skipping embedding");
      return null;
    }

    const endpoint =
      `projects/${project}/locations/${EMBEDDING_LOCATION}` +
      `/publishers/google/models/${EMBEDDING_MODEL}`;

    const [response] = await _getClient().predict({
      endpoint,
      instances: [
        helpers.toValue({
          content: text.trim().slice(0, 500),
          task_type: "SEMANTIC_SIMILARITY",
        })!,
      ],
      parameters: helpers.toValue({outputDimensionality: EMBEDDING_DIMS}),
    });

    const values =
      response.predictions?.[0]?.structValue?.fields?.[
        "embeddings"
      ]?.structValue?.fields?.["values"]?.listValue?.values?.map(
        (v) => v.numberValue ?? 0,
      ) ?? [];

    if (values.length === 0) {
      logger.warn("Empty embedding response from Vertex AI", {
        model: EMBEDDING_MODEL,
      });
      return null;
    }

    return values;
  } catch (error) {
    logger.warn("Embedding failed — proceeding without interest matching", {
      error: String(error),
    });
    return null;
  }
}

/**
 * Computes cosine similarity between two equal-length vectors.
 * Returns 0 when either vector has zero magnitude or the arrays have different lengths.
 * @param {number[]} a - First vector.
 * @param {number[]} b - Second vector.
 * @return {number} Similarity score in [-1, 1].
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0;
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 0 : dot / denom;
}

/**
 * Computes the element-wise mean of an array of equal-length vectors.
 * Returns an empty array when the input is empty.
 * @param {number[][]} vectors - Array of same-length numeric vectors.
 * @return {number[]} Mean vector, same length as each input vector.
 */
export function meanVector(vectors: number[][]): number[] {
  if (vectors.length === 0) return [];
  const dims = vectors[0].length;
  const sum = new Array<number>(dims).fill(0);
  for (const v of vectors) {
    for (let i = 0; i < dims; i++) {
      sum[i] += v[i];
    }
  }
  return sum.map((s) => s / vectors.length);
}
