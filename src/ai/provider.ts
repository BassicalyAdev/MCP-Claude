export interface ToolDefinition {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
}

export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface ChatMessage {
  role: "system" | "user" | "assistant" | "tool";
  content: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
}

export interface ChatResponse {
  content: string;
  tool_calls: ToolCall[];
}

export interface AIProvider {
  name: string;
  models: string[];
  requiresKey: boolean;
  configured: boolean;

  chat(
    messages: ChatMessage[],
    tools: ToolDefinition[],
    model?: string
  ): Promise<ChatResponse>;
}

export interface ProviderConfig {
  apiKey?: string;
  model?: string;
  baseUrl?: string;
}
