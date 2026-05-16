import {cosineSimilarity, meanVector, embedText} from "../embeddingService";

// ── cosineSimilarity ──────────────────────────────────────────────────────────

describe("cosineSimilarity", () => {
  test("parallel vectors (identical) → 1.0", () => {
    expect(cosineSimilarity([1, 0, 0], [1, 0, 0])).toBeCloseTo(1.0);
  });

  test("opposite vectors → -1.0", () => {
    expect(cosineSimilarity([1, 0], [-1, 0])).toBeCloseTo(-1.0);
  });

  test("orthogonal vectors → 0.0", () => {
    expect(cosineSimilarity([1, 0], [0, 1])).toBeCloseTo(0.0);
  });

  test("zero vector → 0.0 (safe divide-by-zero)", () => {
    expect(cosineSimilarity([0, 0, 0], [1, 2, 3])).toBe(0);
    expect(cosineSimilarity([0, 0, 0], [0, 0, 0])).toBe(0);
  });

  test("empty vectors → 0.0", () => {
    expect(cosineSimilarity([], [])).toBe(0);
  });

  test("mismatched lengths → 0.0", () => {
    expect(cosineSimilarity([1, 2], [1, 2, 3])).toBe(0);
  });

  test("scaled parallel vectors still → 1.0", () => {
    expect(cosineSimilarity([1, 1], [3, 3])).toBeCloseTo(1.0);
  });
});

// ── meanVector ────────────────────────────────────────────────────────────────

describe("meanVector", () => {
  test("single vector → identity (same values)", () => {
    expect(meanVector([[0.1, 0.2, 0.3]])).toEqual([0.1, 0.2, 0.3]);
  });

  test("two vectors → element-wise average", () => {
    const result = meanVector([
      [0.0, 1.0],
      [1.0, 0.0],
    ]);
    expect(result[0]).toBeCloseTo(0.5);
    expect(result[1]).toBeCloseTo(0.5);
  });

  test("three vectors → element-wise average", () => {
    const result = meanVector([
      [0.0, 0.0],
      [1.0, 0.0],
      [2.0, 3.0],
    ]);
    expect(result[0]).toBeCloseTo(1.0);
    expect(result[1]).toBeCloseTo(1.0);
  });

  test("empty input → empty array", () => {
    expect(meanVector([])).toEqual([]);
  });
});

// ── embedText graceful degradation (no mock needed) ───────────────────────────

describe("embedText — graceful degradation", () => {
  const originalEnv = process.env;

  afterEach(() => {
    process.env = originalEnv;
    jest.resetAllMocks();
  });

  test("returns null when GCLOUD_PROJECT is not set (never throws)", async () => {
    process.env = {...originalEnv, GCLOUD_PROJECT: undefined};

    const result = await embedText("football");

    expect(result).toBeNull();
  });

  test("returns null when Vertex AI client throws (never throws)", async () => {
    process.env = {...originalEnv, GCLOUD_PROJECT: "test-project"};

    // Real client will fail to connect in the test environment.
    const result = await embedText("football");

    expect(result).toBeNull();
  });
});

// ── embedText — mock-based ────────────────────────────────────────────────────

describe("embedText — mocked Vertex AI client", () => {
  let mockPredict: jest.Mock;
  let savedProject: string | undefined;

  /**
   * Builds the Vertex AI response shape that embeddingService.ts parses.
   * Returns the array that predict() resolves to: [response].
   */
  const makeResponse = (values: number[]) => [
    {
      predictions: [
        {
          structValue: {
            fields: {
              embeddings: {
                structValue: {
                  fields: {
                    values: {
                      listValue: {
                        values: values.map((n) => ({numberValue: n})),
                      },
                    },
                  },
                },
              },
            },
          },
        },
      ],
    },
  ];

  beforeEach(() => {
    savedProject = process.env.GCLOUD_PROJECT;
    mockPredict = jest.fn();
    jest.resetModules();
    jest.doMock("@google-cloud/aiplatform", () => ({
      v1: {
        PredictionServiceClient: jest.fn(() => ({predict: mockPredict})),
      },
      helpers: {
        // Pass-through so we can inspect the raw objects sent to predict().
        toValue: (obj: unknown) => obj,
      },
    }));
  });

  afterEach(() => {
    if (savedProject === undefined) {
      delete process.env.GCLOUD_PROJECT;
    } else {
      process.env.GCLOUD_PROJECT = savedProject;
    }
    jest.resetModules();
  });

  type EmbedFn = (text: string) => Promise<number[] | null>;

  // Must be called inside a test, after jest.doMock(), to get a fresh module
  // instance with the mock applied. The singleton _client resets with each
  // jest.resetModules() call, so every test gets a clean slate.
  const loadEmbedText = (): EmbedFn =>
    (require("../embeddingService") as {embedText: EmbedFn}).embedText; // eslint-disable-line

  test("returns 256-dim number[] on valid Vertex AI response", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    const expected = Array.from({length: 256}, (_, i) => i * 0.001);
    mockPredict.mockResolvedValueOnce(makeResponse(expected));

    const result = await loadEmbedText()("football");

    expect(result).toHaveLength(256);
    expect(result).toEqual(expected);
  });

  test("sends trimmed text and SEMANTIC_SIMILARITY task type to Vertex AI", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockResolvedValueOnce(makeResponse([0.1]));

    await loadEmbedText()("  football fan  ");

    type Arg = {instances: Array<{content: string; task_type: string}>};
    const call = mockPredict.mock.calls[0][0] as Arg;
    expect(call.instances[0].content).toBe("football fan");
    expect(call.instances[0].task_type).toBe("SEMANTIC_SIMILARITY");
  });

  test("truncates input longer than 500 chars before sending", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockResolvedValueOnce(makeResponse([0.5]));

    await loadEmbedText()("x".repeat(600));

    type Arg = {instances: Array<{content: string}>};
    const call = mockPredict.mock.calls[0][0] as Arg;
    expect(call.instances[0].content).toHaveLength(500);
  });

  test("sends outputDimensionality: 256 in parameters", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockResolvedValueOnce(makeResponse([0.1]));

    await loadEmbedText()("football");

    type Arg = {parameters: {outputDimensionality: number}};
    const call = mockPredict.mock.calls[0][0] as Arg;
    expect(call.parameters.outputDimensionality).toBe(256);
  });

  test("returns null when predictions array is empty (malformed response)", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockResolvedValueOnce([{predictions: []}]);

    const result = await loadEmbedText()("football");
    expect(result).toBeNull();
  });

  test("returns null when prediction is missing the embeddings field", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockResolvedValueOnce([
      {predictions: [{structValue: {fields: {}}}]},
    ]);

    const result = await loadEmbedText()("football");
    expect(result).toBeNull();
  });

  test("returns null when embeddings.values list is empty", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockResolvedValueOnce(makeResponse([]));

    const result = await loadEmbedText()("football");
    expect(result).toBeNull();
  });

  test("returns null (never throws) when Vertex AI client rejects", async () => {
    process.env.GCLOUD_PROJECT = "test-project";
    mockPredict.mockRejectedValueOnce(
      new Error("UNAVAILABLE: Connection refused"),
    );

    const result = await loadEmbedText()("football");
    expect(result).toBeNull();
  });
});
