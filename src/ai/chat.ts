import type {
  AIProvider,
  ChatMessage,
  ChatResponse,
  ProviderConfig,
  ToolDefinition,
} from "./provider.js";
import { GroqProvider } from "./groq.js";
import { GeminiProvider } from "./gemini.js";
import { OllamaProvider } from "./ollama.js";
import { HuggingFaceProvider } from "./huggingface.js";
import { ClaudeProvider } from "./claude.js";
import { MistralProvider } from "./mistral.js";
import { DeepSeekProvider } from "./deepseek.js";
import { SambaNovaProvider } from "./sambanova.js";
import { sendToPlugin } from "../bridge.js";
import { getToolDefinitions } from "../tools.js";

const SYSTEM_PROMPT = `You are an AI assistant integrated into Roblox Studio. You can read, write, and modify the user's Roblox project. You have access to tools that interact with Roblox Studio directly.

When the user asks you to do something in their Roblox project, use the available tools. Always explain what you're doing and show results.

You can:
- Browse the game hierarchy (Explorer)
- Read, write, create, and delete scripts
- Get and set properties on instances
- Search for instances by name or class
- Execute arbitrary Lua code
- Get and set the current selection

Be helpful, concise, and proactive. If a task requires multiple steps, do them one at a time and report progress.`;

export class ChatEngine {
  private providers: Map<string, AIProvider> = new Map();
  private activeProvider: string = "Groq";
  private conversations: Map<string, ChatMessage[]> = new Map();
  private tools: ToolDefinition[];

  constructor() {
    this.tools = getToolDefinitions();
    this.providers.set("Groq", new GroqProvider());
    this.providers.set("Gemini", new GeminiProvider());
    this.providers.set("Ollama", new OllamaProvider());
    this.providers.set("HuggingFace", new HuggingFaceProvider());
    this.providers.set("Claude", new ClaudeProvider());
    this.providers.set("Mistral", new MistralProvider());
    this.providers.set("DeepSeek", new DeepSeekProvider());
    this.providers.set("SambaNova", new SambaNovaProvider());
  }

  getProviders() {
    const result: Record<string, unknown>[] = [];
    for (const [name, p] of this.providers) {
      result.push({
        name: p.name,
        models: p.models,
        requiresKey: p.requiresKey,
        configured: p.configured,
        active: name === this.activeProvider,
      });
    }
    return result;
  }

  setProvider(name: string): boolean {
    if (this.providers.has(name)) {
      this.activeProvider = name;
      return true;
    }
    return false;
  }

  configureProvider(name: string, config: ProviderConfig): boolean {
    const provider = this.providers.get(name);
    if (!provider) return false;

    if (config.apiKey !== undefined) {
      (provider as any).apiKey = config.apiKey;
      provider.configured = !!config.apiKey;
    }
    if (config.model !== undefined) {
      (provider as any).model = config.model;
    }
    if (config.baseUrl !== undefined) {
      (provider as any).baseUrl = config.baseUrl;
    }

    return true;
  }

  async chat(
    sessionId: string,
    userMessage: string
  ): Promise<{ response: string; toolCalls: { name: string; args: unknown }[] }> {
    const provider = this.providers.get(this.activeProvider);
    if (!provider) throw new Error(`Provider ${this.activeProvider} not found`);
    if (provider.requiresKey && !provider.configured) {
      throw new Error(
        `${provider.name} requires an API key. Set it in Settings.`
      );
    }

    // Get or create conversation
    if (!this.conversations.has(sessionId)) {
      this.conversations.set(sessionId, [
        { role: "system", content: SYSTEM_PROMPT },
      ]);
    }
    const messages = this.conversations.get(sessionId)!;

    // Add user message
    messages.push({ role: "user", content: userMessage });

    const allToolCalls: { name: string; args: unknown }[] = [];
    let finalResponse = "";

    // Tool execution loop (max 5 iterations)
    for (let i = 0; i < 5; i++) {
      let response: ChatResponse;
      try {
        response = await provider.chat(messages, this.tools);
      } catch (err: any) {
        throw new Error(`AI error: ${err.message}`);
      }

      // Add assistant message
      const assistantMsg: ChatMessage = {
        role: "assistant",
        content: response.content,
        tool_calls: response.tool_calls.length > 0 ? response.tool_calls : undefined,
      };
      messages.push(assistantMsg);
      finalResponse = response.content;

      // If no tool calls, we're done
      if (response.tool_calls.length === 0) break;

      // Execute tool calls
      for (const tc of response.tool_calls) {
        allToolCalls.push({ name: tc.name, args: tc.arguments });

        let result: unknown;
        try {
          result = await sendToPlugin(tc.name, tc.arguments);
        } catch (err: any) {
          result = { error: err.message };
        }

        // Add tool result to conversation
        messages.push({
          role: "tool",
          content: JSON.stringify(result),
          tool_call_id: tc.id,
        });
      }
    }

    // Trim conversation if too long (keep system + last 20 messages)
    if (messages.length > 25) {
      const system = messages[0];
      const recent = messages.slice(-20);
      this.conversations.set(sessionId, [system, ...recent]);
    }

    return { response: finalResponse, toolCalls: allToolCalls };
  }

  clearConversation(sessionId: string) {
    this.conversations.delete(sessionId);
  }
}
