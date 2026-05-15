let currentIdToken: string | null = null;

export const sleep = (ms: number): Promise<void> =>
  new Promise((r) => setTimeout(r, ms));

export const signInAnon = async (): Promise<string> => {
  const res = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key",
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({returnSecureToken: true}),
    },
  );
  const body = (await res.json()) as {idToken: string; localId: string};
  currentIdToken = body.idToken;
  return body.localId;
};

export const signOut = (): void => {
  currentIdToken = null;
};

export const callFn = async (
  name: string,
  data: Record<string, unknown> = {},
): Promise<Record<string, unknown>> => {
  const headers: Record<string, string> = {"Content-Type": "application/json"};
  if (currentIdToken) {
    headers["Authorization"] = `Bearer ${currentIdToken}`;
  }
  const res = await fetch(
    `http://127.0.0.1:5001/cozytalk-5d984/us-central1/${name}`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({data}),
    },
  );
  const body = (await res.json()) as {
    result?: Record<string, unknown>;
    error?: {status: string; message: string};
  };
  if (body.error) {
    const code = body.error.status.toLowerCase().replace(/_/g, "-");
    throw new Error(`${code}: ${body.error.message}`);
  }
  return body.result ?? {};
};

export const resetEmulatorData = async (): Promise<void> => {
  await Promise.all([
    fetch(
      "http://127.0.0.1:8080/emulator/v1/projects/cozytalk-5d984/databases/(default)/documents",
      {method: "DELETE"},
    ),
    fetch("http://127.0.0.1:9000/.json?ns=cozytalk-5d984-default-rtdb", {
      method: "DELETE",
    }),
  ]);
};

export const rtdbGet = async (
  path: string,
): Promise<{value: unknown; exists: boolean}> => {
  const params = new URLSearchParams({"ns": "cozytalk-5d984-default-rtdb"});
  if (currentIdToken) {
    params.set("auth", currentIdToken);
  }
  const res = await fetch(
    `http://127.0.0.1:9000/${path}.json?${params}`,
  );
  const data: unknown = await res.json();
  return {value: data, exists: data !== null};
};

const decodeFirestoreValue = (v: unknown): unknown => {
  if (typeof v !== "object" || v === null) return v;
  const m = v as Record<string, unknown>;
  if ("stringValue" in m) return m["stringValue"];
  if ("integerValue" in m) return parseInt(String(m["integerValue"]), 10);
  if ("doubleValue" in m) return Number(m["doubleValue"]);
  if ("booleanValue" in m) return m["booleanValue"] as boolean;
  if ("nullValue" in m) return null;
  if ("timestampValue" in m) return m["timestampValue"];
  if ("arrayValue" in m) {
    const arr = m["arrayValue"] as {values?: unknown[]};
    const vals = arr.values ?? [];
    return vals.map(decodeFirestoreValue);
  }
  if ("mapValue" in m) {
    const mv = m["mapValue"] as {fields?: Record<string, unknown>};
    if (!mv.fields) return {};
    return decodeFirestoreFields(mv.fields);
  }
  return m;
};

const decodeFirestoreFields = (
  fields: Record<string, unknown>,
): Record<string, unknown> =>
  Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [k, decodeFirestoreValue(v)]),
  );

export const adminFirestoreDoc = async (
  path: string,
): Promise<Record<string, unknown> | null> => {
  const res = await fetch(
    `http://127.0.0.1:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/${path}`,
    {headers: {Authorization: "Bearer owner"}},
  );
  if (res.status === 404) return null;
  const body = (await res.json()) as {
    fields?: Record<string, unknown>;
  };
  if (!body.fields) return {};
  return decodeFirestoreFields(body.fields);
};

export const waitUntilAdminDocMatches = async (
  path: string,
  predicate: (doc: Record<string, unknown> | null) => boolean,
  options: {timeout?: number; interval?: number} = {},
): Promise<Record<string, unknown> | null> => {
  const timeout = options.timeout ?? 20000;
  const interval = options.interval ?? 500;
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const doc = await adminFirestoreDoc(path);
    if (predicate(doc)) return doc;
    await sleep(interval);
  }
  return adminFirestoreDoc(path);
};

export const tryLeaveRoom = async (roomId: string): Promise<void> => {
  try {
    await callFn("leaveRoom", {roomId});
  } catch (_) {}
};

export const tryCancelPool = async (): Promise<void> => {
  try {
    await callFn("cancel1v1Pool");
  } catch (_) {}
};

export const buildRoom = async (targetSize: number): Promise<string> => {
  signOut();
  await signInAnon();
  const res = await callFn("createCustomRoom");
  const roomId = res["roomId"] as string;
  for (let i = 1; i < targetSize; i++) {
    signOut();
    await signInAnon();
    await callFn("joinRoomById", {roomId});
  }
  return roomId;
};
