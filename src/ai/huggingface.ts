import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolCall,
  ToolDefinition,
} from "./provider.js";

export class HuggingFaceProvider implements AIProvider {
  name = "HuggingFace";
  models = [
    "meta-llama/Llama-3.3-70B-Instruct",
    "mistralai/Mixtral-8x7B-Instruct-v0.1",
    "Qwen/Qwen2.5-72B-Instruct",
  ];
  requiresKey = true;
  configured = false;

  private apiKey: string;
  private model: string;

  constructor(config: ProviderConfig = {}) {
    this.apiKey = config.apiKey || process.env.HF_API_KEY || "";
    this.model = config.model || this.models[0];
    this.configured = !!this.apiKey;
  }

  private formatPrompt(messages: ChatMessage[], tools: ToolDefinition[]): string {
    let prompt = "";

    // System message with tool info
    const systemMsgs = messages.filter((m) => m.role === "system");
    if (systemMsgs.length > 0) {
      prompt += systemMsgs.map((m) => m.content).join("\n") + "\n\n";
    }

    if (tools.length > 0) {
      prompt += "You have access to these tools. To call a tool, respond with a JSON block:\n";
      prompt += '```tool_call\n{"name": "tool_name", "arguments": {"key": "value"}}\n```\n\n';
      prompt += "Available tools:\n";
      for (const t of tools) {
        prompt += `- ${t.name}: ${t.description}\n`;
      }
      prompt += "\n";
    }

    prompt += "<|begin_of_text|>\n";

    for (const msg of messages) {
      if (msg.role === "system") continue;
      if (msg.role === "user") {
        prompt += `<|start_header_id|>user<|end_header_id|>\n${msg.content}<|eot_id|>\n`;
      } else if (msg.role === "assistant") {
        prompt += `<|start_header_id|>assistant<|end_header_id|>\n${msg.content}<|eot_id|>\n`;
      } else if (msg.role === "tool") {
        prompt += `<|start_header_id|>tool_result<|end_header_id|>\n${msg.content}<|eot_id|>\n`;
      }
    }

    prompt += "<|start_header_id|>assistant<|end_header_id|>\n";
    return prompt;
  }

  private parseToolCalls(text: string): { cleanText: string; toolCalls: ToolCall[] } {
    const toolCalls: ToolCall[] = [];
    let cleanText = text;

    const regex = /```tool_call\s*\n?([\s\S]*?)```/g;
    let match;
    while ((match = regex.exec(text)) !== null) {
      try {
        const tc = JSON.parse(match[1].trim());
        toolCalls.push({
          id: `call_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
          name: tc.name,
          arguments: tc.arguments || {},
        });
      } catch {
        // skip malformed tool calls
      }
      cleanText = cleanText.replace(match[0], "").trim();
    }

    return { cleanText, toolCalls };
  }

  async chat(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    model?: string
  ): Promise<ChatResponse> {
    const prompt = this.formatPrompt(messages, tools);

    const res = await fetch(
      `https://api-inference.huggingface.co/models/${model || this.model}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          inputs: prompt,
          parameters: {
            max_new_tokens: 2048,
            temperature: 0.7,
            return_full_text: false,
          },
        }),
      }
    );

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`HuggingFace API error ${res.status}: ${err}`);
    }

    const data = await res.json();
    const text = Array.isArray(data) ? data[0]?.generated_text || "" : data.generated_text || "";

    const { cleanText, toolCalls } = this.parseToolCalls(text);

    return { content: cleanText, tool_calls: toolCalls };
  }
}
