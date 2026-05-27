# AI Assistant for Roblox Studio

Multi-AI assistant that lives inside Roblox Studio. Chat with AI directly in Studio to read, write, and modify your project. Supports multiple free AI providers — no paid API keys required.

## Supported AI Providers (All Free)

| Provider | Speed | Quality | Setup |
|----------|-------|---------|-------|
| **Groq** | Fastest | Great | Free API key at [console.groq.com](https://console.groq.com) |
| **Gemini** | Fast | Best | Free API key at [aistudio.google.com](https://aistudio.google.com) |
| **Ollama** | Depends | Good | 100% local, no key needed. Install [Ollama](https://ollama.com) |
| **HuggingFace** | Slower | Good | Free token at [huggingface.co](https://huggingface.co) |
| **Claude** | Fast | Excellent | Free tier API key at [console.anthropic.com](https://console.anthropic.com) |
| **Mistral** | Fast | Great | Free API key at [console.mistral.ai](https://console.mistral.ai) |
| **DeepSeek** | Fast | Great | Free API key at [platform.deepseek.com](https://platform.deepseek.com) |
| **SambaNova** | Fast | Great | Free API key at [cloud.sambanova.ai](https://cloud.sambanova.ai) |

## How It Works

```
You type in Studio plugin chat
        ↓
Plugin sends message to server (HTTP POST /chat)
        ↓
Server calls AI provider (Groq/Gemini/Ollama/HuggingFace/Claude/Mistral/DeepSeek/SambaNova)
        ↓
AI requests tool calls (read_script, write_script, etc.)
        ↓
Server sends tool requests to plugin (HTTP GET /poll)
        ↓
Plugin executes in Studio, posts results back
        ↓
Server feeds results to AI, gets final response
        ↓
Plugin displays AI response in chat
```

No Claude Code CLI required. The server is standalone — just run it and chat.

## Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) v18+
- [Roblox Studio](https://create.roblox.com/)
- One free API key (Groq, Gemini, Claude, Mistral, DeepSeek, SambaNova, or HuggingFace) — or Ollama for 100% local use

### Setup

**Windows (one-click):**

```
setup.bat
```

**Manual:**

```bash
npm install
npm run build
```

Copy the plugin to Roblox Studio:

```bash
# Windows
copy plugin\ClaudeMCP.lua "%LOCALAPPDATA%\Roblox\Plugins\"

# macOS
cp plugin/ClaudeMCP.lua ~/Documents/Roblox/Plugins/
```

### Run

**Step 1 — Start the server:**

Open a terminal (Command Prompt, PowerShell, or any terminal) and navigate to the project folder:

```bash
cd "MCP Claude"
npm start
```

You should see:
```
  Roblox Studio AI Server
  ========================
  Server running on http://localhost:3636
  Waiting for Roblox Studio plugin to connect...
```

**Keep this terminal window open** — the server must be running while you use the plugin.

> **Tip:** If you used `setup.bat`, you can also double-click `start.bat` (if it exists) or create a shortcut. The server runs on `http://localhost:3636` by default.

**Step 2 — Use it in Roblox Studio:**

1. Open Roblox Studio — the plugin loads automatically with an "AI Assistant" panel
2. Click the **gear icon** in the plugin panel
3. Enter your API key (or configure Ollama URL)
4. Select your AI provider from the dropdown
5. Start chatting!

> **Note:** The server must be running (`npm start`) BEFORE you open the plugin in Studio. If the status dot is red, the server isn't running or the port is wrong.

### Environment Variables (Optional)

You can also set API keys via `.env` file:

```bash
cp .env.example .env
# Edit .env with your keys
```

## What the AI Can Do

| Tool | Description |
|------|-------------|
| `get_hierarchy` | Browse the Explorer tree |
| `read_script` | Read script source code |
| `write_script` | Write/overwrite scripts |
| `create_script` | Create Script, LocalScript, or ModuleScript |
| `delete_instance` | Remove instances |
| `get_properties` | Read all properties of an instance |
| `set_property` | Set Vector3, Color3, CFrame, string, number, bool |
| `execute_lua` | Run arbitrary Lua in Studio |
| `search_instances` | Find instances by ClassName or Name |
| `get_selection` | Get current Studio selection |
| `set_selection` | Set the Studio selection |

### Example Prompts

- "Create a part in Workspace called MyPart"
- "Show me all scripts in ServerScriptService"
- "Make all parts in the model red and anchored"
- "Create a sprint script for the player"
- "Find all Part instances and make them transparent"

## Plugin GUI

The dockable panel in Studio has:

- **Provider dropdown** — switch between Groq, Gemini, Ollama, HuggingFace, Claude, Mistral, DeepSeek, SambaNova
- **Settings** (gear icon) — configure API keys and Ollama URL
- **Chat area** — conversation with the AI, tool call notifications
- **Status dot** — green = connected, red = disconnected, yellow = thinking

### Chat Commands

| Command | Description |
|---------|-------------|
| `/help` | Show help message |
| `/clear` | Clear the chat |

## Architecture

### Server (`src/`)

- **`index.ts`** — Entry point, starts Express server on port 3636
- **`bridge.ts`** — HTTP endpoints: `/chat`, `/poll`, `/result`, `/providers`, `/config`, `/health`
- **`tools.ts`** — 11 tool definitions (JSON Schema format)
- **`ai/provider.ts`** — AI provider interface
- **`ai/groq.ts`** — Groq API client
- **`ai/gemini.ts`** — Google Gemini API client
- **`ai/ollama.ts`** — Ollama local API client
- **`ai/huggingface.ts`** — HuggingFace Inference API client
- **`ai/claude.ts`** — Anthropic Claude API client
- **`ai/mistral.ts`** — Mistral AI API client
- **`ai/deepseek.ts`** — DeepSeek API client
- **`ai/sambanova.ts`** — SambaNova API client
- **`ai/chat.ts`** — Chat engine with tool execution loop

### Plugin (`plugin/`)

- **`ClaudeMCP.lua`** — Full plugin with chat UI, provider selector, settings panel, and tool execution

### Communication

Roblox Studio can't host HTTP servers, so the plugin polls:

1. User sends message in plugin chat
2. Plugin POSTs to `/chat` on the server
3. Server calls the AI provider
4. AI returns tool calls → server queues them
5. Plugin polls `GET /poll`, executes tools, POSTs results to `/result`
6. Server feeds results back to AI until done
7. Final response sent back to plugin

## Development

```bash
# Watch mode
npm run dev

# Build
npm run build

# Start
npm start
```

Change port:
```bash
PORT=4000 npm start
```

## License

MIT
