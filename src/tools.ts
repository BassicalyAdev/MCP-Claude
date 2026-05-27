import type { ToolDefinition } from "./ai/provider.js";

const toolDefs: ToolDefinition[] = [
  {
    name: "get_hierarchy",
    description:
      "Get the Roblox game object hierarchy (Explorer tree). Returns a nested tree of instances with their names, classes, and children.",
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description:
            'Root path to start from. Defaults to "game". Use paths like "game.Workspace.MyPart".',
        },
        depth: {
          type: "number",
          description: "Max depth to traverse. Defaults to 3.",
        },
      },
    },
  },
  {
    name: "read_script",
    description:
      "Read the source code of a Script, LocalScript, or ModuleScript in Roblox Studio.",
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: 'Full path to the script, e.g. "game.ServerScriptService.MyScript".',
        },
      },
      required: ["path"],
    },
  },
  {
    name: "write_script",
    description: "Write or overwrite the source code of a Script, LocalScript, or ModuleScript.",
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: 'Full path to the script, e.g. "game.ServerScriptService.MyScript".',
        },
        source: { type: "string", description: "The Lua source code to write." },
      },
      required: ["path", "source"],
    },
  },
  {
    name: "create_script",
    description: "Create a new Script, LocalScript, or ModuleScript in Roblox Studio.",
    parameters: {
      type: "object",
      properties: {
        parent: {
          type: "string",
          description: 'Parent path, e.g. "game.ServerScriptService" or "game.Workspace".',
        },
        name: { type: "string", description: "Name of the new script." },
        className: {
          type: "string",
          enum: ["Script", "LocalScript", "ModuleScript"],
          description: "Type of script to create.",
        },
        source: { type: "string", description: "Initial source code." },
      },
      required: ["parent", "name", "className"],
    },
  },
  {
    name: "delete_instance",
    description: "Delete an instance from the Roblox game by path.",
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: 'Full path to the instance, e.g. "game.Workspace.OldPart".',
        },
      },
      required: ["path"],
    },
  },
  {
    name: "get_properties",
    description: "Get all properties of a Roblox instance.",
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: 'Full path to the instance, e.g. "game.Workspace.MyPart".',
        },
      },
      required: ["path"],
    },
  },
  {
    name: "set_property",
    description:
      'Set a property on a Roblox instance. Supports string, number, boolean, Vector3, Color3, and CFrame values.',
    parameters: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: 'Full path to the instance, e.g. "game.Workspace.MyPart".',
        },
        property: {
          type: "string",
          description: "Property name, e.g. 'Position', 'Color', 'Name'.",
        },
        value: {
          type: "string",
          description:
            'Property value as a string. For Vector3: "1,2,3". For Color3: "1,0,0". For booleans: "true"/"false". For numbers: "42".',
        },
      },
      required: ["path", "property", "value"],
    },
  },
  {
    name: "execute_lua",
    description:
      "Execute arbitrary Lua code in Roblox Studio. The code runs with full API access. Use `return` to send a value back.",
    parameters: {
      type: "object",
      properties: {
        code: { type: "string", description: "Lua code to execute in Roblox Studio." },
      },
      required: ["code"],
    },
  },
  {
    name: "search_instances",
    description: "Search for instances in the Roblox game by ClassName, Name, or both.",
    parameters: {
      type: "object",
      properties: {
        className: {
          type: "string",
          description: "Filter by ClassName, e.g. 'Part', 'Script', 'Model'.",
        },
        name: { type: "string", description: "Filter by Name (partial match)." },
        root: {
          type: "string",
          description: 'Root path to search from. Defaults to "game".',
        },
        maxResults: {
          type: "number",
          description: "Maximum results to return. Defaults to 50.",
        },
      },
    },
  },
  {
    name: "get_selection",
    description: "Get the currently selected instances in Roblox Studio.",
    parameters: { type: "object", properties: {} },
  },
  {
    name: "set_selection",
    description: "Set the selection in Roblox Studio to specific instances.",
    parameters: {
      type: "object",
      properties: {
        paths: {
          type: "array",
          items: { type: "string" },
          description:
            'List of instance paths to select, e.g. ["game.Workspace.Part1", "game.Workspace.Part2"].',
        },
      },
      required: ["paths"],
    },
  },
];

export function getToolDefinitions(): ToolDefinition[] {
  return toolDefs;
}
