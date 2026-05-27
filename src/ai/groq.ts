import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolCall,
  ToolDefinition,
} from "./provider.js";

export class GroqProvider implements AIProvider {
  name = "Groq";
  models = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"];
  requiresKey = true;
  configured = false;

  private apiKey: string;
  private model: string;

  constructor(config: ProviderConfig = {}) {
    this.apiKey = config.apiKey || process.env.GROQ_API_KEY || "";
    this.model = config.model || this.models[0];
    this.configured = !!this.apiKey;
  }

  async chat(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    model?: string
  ): Promise<ChatResponse> {
    const body: Record<string, unknown> = {
      model: model || this.model,
      messages: messages.map((m) => {
        const msg: Record<string, unknown> = { role: m.role, content: m.content };
        if (m.tool_calls && m.tool_calls.length > 0) {
          msg.tool_calls = m.tool_calls.map((tc) => ({
            id: tc.id,
            type: "function",
            function: { name: tc.name, arguments: JSON.stringify(tc.arguments) },
          }));
        }
        if (m.tool_call_id) msg.tool_call_id = m.tool_call_id;
        return msg;
      }),
      temperature: 0.7,
      max_tokens: 4096,
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

    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Groq API error ${res.status}: ${err}`);
    }

    const data = await res.json();
    const choice = data.choices?.[0];
    if (!choice) throw new Error("Groq returned no choices");

    const msg = choice.message;
    const toolCalls: ToolCall[] = [];

    if (msg.tool_calls) {
      for (const tc of msg.tool_calls) {
        toolCalls.push({
          id: tc.id,
          name: tc.function.name,
          arguments: JSON.parse(tc.function.arguments || "{}"),
        });
      }
    }

    return {
      content: msg.content || "",
      tool_calls: toolCalls,
    };
  }
}
