import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolCall,
  ToolDefinition,
} from "./provider.js";

export class ClaudeProvider implements AIProvider {
  name = "Claude";
  models = ["claude-sonnet-4-20250514", "claude-3-5-haiku-20241022", "claude-3-haiku-20240307"];
  requiresKey = true;
  configured = false;

  private apiKey: string;
  private model: string;

  constructor(config: ProviderConfig = {}) {
    this.apiKey = config.apiKey || process.env.CLAUDE_API_KEY || "";
    this.model = config.model || this.models[0];
    this.configured = !!this.apiKey;
  }

  async chat(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    model?: string
  ): Promise<ChatResponse> {
    // Extract system message
    const systemMsg = messages.find((m) => m.role === "system");
    const nonSystemMessages = messages.filter((m) => m.role !== "system");

    // Build Anthropic Messages API format
    const anthropicMessages: Record<string, unknown>[] = [];
    for (const m of nonSystemMessages) {
      if (m.role === "tool") {
        // Tool results go as user messages with tool_result content
        anthropicMessages.push({
          role: "user",
          content: [
            {
              type: "tool_result",
              tool_use_id: m.tool_call_id,
              content: m.content,
            },
          ],
        });
      } else if (m.role === "assistant" && m.tool_calls && m.tool_calls.length > 0) {
        // Assistant message with tool use blocks
        const content: Record<string, unknown>[] = [];
        if (m.content) {
          content.push({ type: "text", text: m.content });
        }
        for (const tc of m.tool_calls) {
          content.push({
            type: "tool_use",
            id: tc.id,
            name: tc.name,
            input: tc.arguments,
          });
        }
        anthropicMessages.push({ role: "assistant", content });
      } else {
        anthropicMessages.push({ role: m.role, content: m.content });
      }
    }

    // Build tools in Anthropic format
    const anthropicTools = tools.map((t) => ({
      name: t.name,
      description: t.description,
      input_schema: t.parameters,
    }));

    const body: Record<string, unknown> = {
      model: model || this.model,
      max_tokens: 4096,
      messages: anthropicMessages,
    };

    if (systemMsg) {
      body.system = systemMsg.content;
    }

    if (anthropicTools.length > 0) {
      body.tools = anthropicTools;
    }

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": this.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Claude API error ${res.status}: ${err}`);
    }

    const data = await res.json();
    const toolCalls: ToolCall[] = [];
    let content = "";

    for (const block of data.content || []) {
      if (block.type === "text") {
        content += block.text;
      } else if (block.type === "tool_use") {
        toolCalls.push({
          id: block.id,
          name: block.name,
          arguments: block.input,
        });
      }
    }

    return { content, tool_calls: toolCalls };
  }
}
