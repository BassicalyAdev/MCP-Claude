# MCP Claude - Roblox Studio Integration

An MCP (Model Context Protocol) server that lets Claude read, write, and modify your Roblox Studio project. Includes a dockable plugin GUI for status monitoring.

## How It Works

```
Claude CLI  <──stdio──>  MCP Server (Node.js)  <──HTTP──>  Roblox Plugin (Lua)
                              port 3636              poll/result
```

The MCP server runs locally and communicates with a Roblox Studio plugin via HTTP polling. Claude can browse your game hierarchy, read/write scripts, modify properties, search instances, and execute arbitrary Lua code.

## Features

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

## Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) v18+
- [Roblox Studio](https://create.roblox.com/)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)

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

Copy the plugin to Roblox Studio's plugins folder:

```bash
# Windows
copy plugin\ClaudeMCP.lua "%LOCALAPPDATA%\Roblox\Plugins\"

# macOS
cp plugin/ClaudeMCP.lua ~/Documents/Roblox/Plugins/
```

### Configure Claude Code

Add to your Claude Code MCP settings (`settings.json`):

```json
{
  "mcpServers": {
    "roblox-studio": {
      "command": "node",
      "args": ["C:/path/to/MCP Claude/build/index.js"]
    }
  }
}
```

### Run

1. Open Roblox Studio — the plugin loads automatically with a "Claude AI" panel
2. Start the MCP server:
   ```bash
   npm start
   ```
3. Use Claude Code CLI — Claude can now see and modify your project

## Plugin GUI

The Roblox Studio plugin provides a dockable panel with:

- **Connection status** — green dot when connected to MCP server
- **Request counter** — shows how many operations Claude has performed
- **Tool call log** — displays each tool call as it happens
- **Chat interface** — type `/help` for available commands

### Commands

| Command | Description |
|---------|-------------|
| `/help` | Show available commands |
| `/status` | Show connection info and request count |
| `/clear` | Clear the chat log |

## Architecture

### MCP Server (`src/`)

- **`index.ts`** — Entry point. Creates the MCP server with stdio transport and starts the HTTP bridge.
- **`bridge.ts`** — Express HTTP server on port 3636. Manages a request queue that the Roblox plugin polls. Handles request/response matching with UUIDs and 30s timeouts.
- **`tools.ts`** — Registers all 11 MCP tools with Zod schema validation. Each tool sends its request to the plugin via the bridge.

### Roblox Plugin (`plugin/`)

- **`ClaudeMCP.lua`** — Single unified plugin file. Runs an HTTP polling loop (150ms interval) that fetches pending requests from the bridge, executes them using the Roblox API, and posts results back. Also creates the dockable GUI.

### Communication Pattern

Roblox Studio's HttpService can only make outgoing requests, so the bridge uses a polling pattern:

1. Claude calls an MCP tool
2. MCP server queues the request
3. Plugin polls `GET /poll` and receives the request
4. Plugin executes the operation in Studio
5. Plugin posts result to `POST /result`
6. MCP server resolves the tool call

## Development

```bash
# Watch mode (auto-rebuild on changes)
npm run dev

# Build once
npm run build

# Start server
npm start
```

The bridge port can be configured via environment variable:

```bash
BRIDGE_PORT=4000 npm start
```

## License

MIT
