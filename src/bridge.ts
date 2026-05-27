import express from "express";

export interface PendingRequest {
  id: string;
  tool: string;
  args: Record<string, unknown>;
  resolve: (result: unknown) => void;
  reject: (error: Error) => void;
}

const requestQueue: PendingRequest[] = [];
const pendingResults = new Map<string, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
let pluginConnected = false;
let lastPollTime = 0;

export function sendToPlugin(tool: string, args: Record<string, unknown>): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const id = crypto.randomUUID();
    requestQueue.push({ id, tool, args, resolve, reject });
    pendingResults.set(id, { resolve, reject });

    // Timeout after 30 seconds
    setTimeout(() => {
      if (pendingResults.has(id)) {
        pendingResults.delete(id);
        reject(new Error("Request timed out after 30s"));
      }
    }, 30000);
  });
}

export function startBridge(port: number = 3636): Promise<void> {
  const app = express();
  app.use(express.json({ limit: "10mb" }));

  // Plugin polls for pending requests
  app.get("/poll", (_req, res) => {
    pluginConnected = true;
    lastPollTime = Date.now();

    if (requestQueue.length > 0) {
      const req = requestQueue.shift()!;
      res.json({ id: req.id, tool: req.tool, args: req.args });
    } else {
      res.json({ idle: true });
    }
  });

  // Plugin posts results back
  app.post("/result", (req, res) => {
    const { id, result, error } = req.body;
    const pending = pendingResults.get(id);

    if (pending) {
      pendingResults.delete(id);
      if (error) {
        pending.reject(new Error(error));
      } else {
        pending.resolve(result);
      }
      res.json({ ok: true });
    } else {
      res.status(404).json({ error: "Unknown request id" });
    }
  });

  // Health check
  app.get("/health", (_req, res) => {
    res.json({
      connected: pluginConnected && Date.now() - lastPollTime < 5000,
      pendingRequests: requestQueue.length,
      lastPoll: lastPollTime,
    });
  });

  return new Promise((resolve) => {
    app.listen(port, () => {
      resolve();
    });
  });
}
