import express from "express";
import { ChatEngine } from "./ai/chat.js";

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

export const chatEngine = new ChatEngine();

export function sendToPlugin(tool: string, args: Record<string, unknown>): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const id = crypto.randomUUID();
    requestQueue.push({ id, tool, args, resolve, reject });
    pendingResults.set(id, { resolve, reject });

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

  // CORS for plugin HTTP requests
  app.use((_req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Content-Type");
    res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    if (_req.method === "OPTIONS") return res.sendStatus(200);
    next();
  });

  // === Plugin polling ===

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

  app.post("/result", (req, res) => {
    const { id, result, error } = req.body;
    const pending = pendingResults.get(id);
    if (pending) {
      pendingResults.delete(id);
      if (error) pending.reject(new Error(error));
      else pending.resolve(result);
      res.json({ ok: true });
    } else {
      res.status(404).json({ error: "Unknown request id" });
    }
  });

  // === Chat API ===

  app.post("/chat", async (req, res) => {
    try {
      const { message, session } = req.body;
      if (!message) return res.status(400).json({ error: "Missing message" });

      const sessionId = session || "default";
      const result = await chatEngine.chat(sessionId, message);
      res.json(result);
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // === Provider management ===

  app.get("/providers", (_req, res) => {
    res.json({ providers: chatEngine.getProviders() });
  });

  app.post("/provider", (req, res) => {
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: "Missing provider name" });
    const ok = chatEngine.setProvider(name);
    res.json({ ok });
  });

  app.post("/config", (req, res) => {
    const { provider, apiKey, model, baseUrl } = req.body;
    if (!provider) return res.status(400).json({ error: "Missing provider name" });
    const ok = chatEngine.configureProvider(provider, { apiKey, model, baseUrl });
    res.json({ ok });
  });

  // === Health ===

  app.get("/health", (_req, res) => {
    res.json({
      connected: pluginConnected && Date.now() - lastPollTime < 5000,
      pendingRequests: requestQueue.length,
      lastPoll: lastPollTime,
    });
  });

  return new Promise((resolve) => {
    app.listen(port, () => resolve());
  });
}
