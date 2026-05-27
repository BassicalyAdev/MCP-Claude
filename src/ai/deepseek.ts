import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolCall,
  ToolDefinition,
} from "./provider.js";

export class DeepSeekProvider implements AIProvider {
  name = "DeepSeek";
  models = ["deepseek-chat", "deepseek-reasoner"];
  requiresKey = true;
  configured = false;

  private apiKey: string;
  private model: string;

  constructor(config: ProviderConfig = {}) {
    this.apiKey = config.apiKey || process.env.DEEPSEEK_API_KEY || "";
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

    const res = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`DeepSeek API error ${res.status}: ${err}`);
    }

    const data = await res.json();
    const choice = data.choices?.[0];
    if (!choice) throw new Error("DeepSeek returned no choices");

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
