import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolCall,
  ToolDefinition,
} from "./provider.js";

export class GeminiProvider implements AIProvider {
  name = "Gemini";
  models = ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"];
  requiresKey = true;
  configured = false;

  private apiKey: string;
  private model: string;

  constructor(config: ProviderConfig = {}) {
    this.apiKey = config.apiKey || process.env.GEMINI_API_KEY || "";
    this.model = config.model || this.models[0];
    this.configured = !!this.apiKey;
  }

  private convertMessages(messages: ChatMessage[]) {
    const contents: Record<string, unknown>[] = [];
    let systemInstruction: string | undefined;

    for (const msg of messages) {
      if (msg.role === "system") {
        systemInstruction = msg.content;
        continue;
      }

      if (msg.role === "assistant") {
        const parts: Record<string, unknown>[] = [];
        if (msg.content) parts.push({ text: msg.content });
        if (msg.tool_calls) {
          for (const tc of msg.tool_calls) {
            parts.push({
              functionCall: { name: tc.name, args: tc.arguments },
            });
          }
        }
        if (parts.length > 0) contents.push({ role: "model", parts });
        continue;
      }

      if (msg.role === "tool") {
        contents.push({
          role: "function",
          parts: [
            {
              functionResponse: {
                name: msg.tool_call_id || "unknown",
                response: { result: msg.content },
              },
            },
          ],
        });
        continue;
      }

      // user message
      contents.push({ role: "user", parts: [{ text: msg.content }] });
    }

    return { contents, systemInstruction };
  }

  private convertTools(tools: ToolDefinition[]) {
    if (tools.length === 0) return undefined;
    return [
      {
        functionDeclarations: tools.map((t) => ({
          name: t.name,
          description: t.description,
          parameters: t.parameters,
        })),
      },
    ];
  }

  async chat(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    model?: string
  ): Promise<ChatResponse> {
    const { contents, systemInstruction } = this.convertMessages(messages);
    const geminiTools = this.convertTools(tools);

    const body: Record<string, unknown> = { contents };
    if (systemInstruction) {
      body.systemInstruction = { parts: [{ text: systemInstruction }] };
    }
    if (geminiTools) body.tools = geminiTools;

    const m = model || this.model;
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${this.apiKey}`;

    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Gemini API error ${res.status}: ${err}`);
    }

    const data = await res.json();
    const candidate = data.candidates?.[0];
    if (!candidate?.content?.parts) throw new Error("Gemini returned no candidates");

    let content = "";
    const toolCalls: ToolCall[] = [];

    for (const part of candidate.content.parts) {
      if (part.text) content += part.text;
      if (part.functionCall) {
        toolCalls.push({
          id: `call_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
          name: part.functionCall.name,
          arguments: part.functionCall.args || {},
        });
      }
    }

    return { content, tool_calls: toolCalls };
  }
}
