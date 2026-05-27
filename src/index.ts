#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerTools } from "./tools.js";
import { startBridge } from "./bridge.js";

const BRIDGE_PORT = Number(process.env.BRIDGE_PORT) || 3636;

async function main() {
  // Start the HTTP bridge that the Roblox plugin connects to
  await startBridge(BRIDGE_PORT);

  // Create MCP server
  const server = new McpServer({
    name: "roblox-studio-mcp",
    version: "1.0.0",
  });

  // Register all tools
  registerTools(server);

  // Connect via stdio transport
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Log to stderr (stdout is reserved for MCP protocol)
  process.stderr.write(
    `Roblox Studio MCP server running. Bridge on port ${BRIDGE_PORT}\n`
  );
}

main().catch((err) => {
  process.stderr.write(`Fatal error: ${err}\n`);
  process.exit(1);
});
