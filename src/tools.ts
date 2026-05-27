import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendToPlugin } from "./bridge.js";

export function registerTools(server: McpServer) {
  server.tool(
    "get_hierarchy",
    "Get the Roblox game object hierarchy (Explorer tree). Returns a nested tree of instances with their names, classes, and children.",
    {
      path: z
        .string()
        .optional()
        .describe(
          'Root path to start from. Defaults to "game" (the whole game). Use paths like "game.Workspace.MyPart"'
        ),
      depth: z
        .number()
        .optional()
        .describe("Max depth to traverse. Defaults to 3. Use -1 for unlimited."),
    },
    async ({ path, depth }) => {
      const result = await sendToPlugin("get_hierarchy", {
        path: path || "game",
        depth: depth ?? 3,
      });
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "read_script",
    "Read the source code of a Script, LocalScript, or ModuleScript in Roblox Studio.",
    {
      path: z
        .string()
        .describe('Full path to the script, e.g. "game.ServerScriptService.MyScript"'),
    },
    async ({ path }) => {
      const result = await sendToPlugin("read_script", { path });
      return { content: [{ type: "text", text: String(result) }] };
    }
  );

  server.tool(
    "write_script",
    "Write or overwrite the source code of a Script, LocalScript, or ModuleScript.",
    {
      path: z
        .string()
        .describe('Full path to the script, e.g. "game.ServerScriptService.MyScript"'),
      source: z.string().describe("The Lua source code to write."),
    },
    async ({ path, source }) => {
      const result = await sendToPlugin("write_script", { path, source });
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    }
  );

  server.tool(
    "create_script",
    "Create a new Script, LocalScript, or ModuleScript in Roblox Studio.",
    {
      parent: z
        .string()
        .describe(
          'Parent path, e.g. "game.ServerScriptService" or "game.Workspace"'
        ),
      name: z.string().describe("Name of the new script."),
      className: z
        .enum(["Script", "LocalScript", "ModuleScript"])
        .describe("Type of script to create."),
      source: z.string().optional().describe("Initial source code."),
    },
    async ({ parent, name, className, source }) => {
      const result = await sendToPlugin("create_script", {
        parent,
        name,
        className,
        source: source || "",
      });
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    }
  );

  server.tool(
    "delete_instance",
    "Delete an instance from the Roblox game by path.",
    {
      path: z
        .string()
        .describe('Full path to the instance, e.g. "game.Workspace.OldPart"'),
    },
    async ({ path }) => {
      const result = await sendToPlugin("delete_instance", { path });
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    }
  );

  server.tool(
    "get_properties",
    "Get all properties of a Roblox instance.",
    {
      path: z
        .string()
        .describe('Full path to the instance, e.g. "game.Workspace.MyPart"'),
    },
    async ({ path }) => {
      const result = await sendToPlugin("get_properties", { path });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    }
  );

  server.tool(
    "set_property",
    "Set a property on a Roblox instance. Supports string, number, boolean, Vector3, Color3, and CFrame values.",
    {
      path: z
        .string()
        .describe('Full path to the instance, e.g. "game.Workspace.MyPart"'),
      property: z.string().describe("Property name, e.g. 'Position', 'Color', 'Name'"),
      value: z
        .string()
        .describe(
          'Property value as a string. For Vector3: "1,2,3". For Color3: "1,0,0". For booleans: "true"/"false". For numbers: "42".'
        ),
    },
    async ({ path, property, value }) => {
      const result = await sendToPlugin("set_property", { path, property, value });
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    }
  );

  server.tool(
    "execute_lua",
    "Execute arbitrary Lua code in Roblox Studio. The code runs in the Studio command bar context with full API access. Use `return` to send a value back.",
    {
      code: z.string().describe("Lua code to execute in Roblox Studio."),
    },
    async ({ code }) => {
      const result = await sendToPlugin("execute_lua", { code });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    }
  );

  server.tool(
    "search_instances",
    "Search for instances in the Roblox game by ClassName, Name, or both.",
    {
      className: z
        .string()
        .optional()
        .describe("Filter by ClassName, e.g. 'Part', 'Script', 'Model'"),
      name: z.string().optional().describe("Filter by Name (partial match)"),
      root: z
        .string()
        .optional()
        .describe('Root path to search from. Defaults to "game".'),
      maxResults: z
        .number()
        .optional()
        .describe("Maximum results to return. Defaults to 50."),
    },
    async ({ className, name, root, maxResults }) => {
      const result = await sendToPlugin("search_instances", {
        className: className || null,
        name: name || null,
        root: root || "game",
        maxResults: maxResults ?? 50,
      });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    }
  );

  server.tool(
    "get_selection",
    "Get the currently selected instances in Roblox Studio.",
    {},
    async () => {
      const result = await sendToPlugin("get_selection", {});
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    }
  );

  server.tool(
    "set_selection",
    "Set the selection in Roblox Studio to specific instances.",
    {
      paths: z
        .array(z.string())
        .describe(
          'List of instance paths to select, e.g. ["game.Workspace.Part1", "game.Workspace.Part2"]'
        ),
    },
    async ({ paths }) => {
      const result = await sendToPlugin("set_selection", { paths });
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    }
  );
}
