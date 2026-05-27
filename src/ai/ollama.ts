import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolCall,
  ToolDefinition,
} from "./provider.js";

export class OllamaProvider implements AIProvider {
  name = "Ollama";
  models = ["llama3.3", "llama3.1", "codellama", "mistral", "qwen2.5"];
  requiresKey = false;
  configured = true;

  private baseUrl: string;
  private model: string;

  constructor(config: ProviderConfig = {}) {
    this.baseUrl = config.baseUrl || process.env.OLLAMA_URL || "http://localhost:11434";
    this.model = config.model || this.models[0];
  }

  async chat(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    model?: string
  ): Promise<ChatResponse> {
    const body: Record<string, unknown> = {
      model: model || this.model,
      messages: messages.map((m) => ({
        role: m.role,
        content: m.content,
      })),
      stream: false,
      options: { temperature: 0.7 },
    };

    if (tools.length > 0) {
      body.tools = tools.map((t) => ({
        type: "function",
        function: {
          name: t.name,
          description: t.description,
          parameters: t.parameters,
        },
      }));
    }

    const res = await fetch(`${this.baseUrl}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Ollama error ${res.status}: ${err}`);
    }

    const data = await res.json();
    const msg = data.message;
    if (!msg) throw new Error("Ollama returned no message");

    const toolCalls: ToolCall[] = [];
    if (msg.tool_calls) {
      for (const tc of msg.tool_calls) {
        toolCalls.push({
          id: `call_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
          name: tc.function.name,
          arguments: tc.function.arguments || {},
        });
      }
    }

    return {
      content: msg.content || "",
      tool_calls: toolCalls,
    };
  }
}
