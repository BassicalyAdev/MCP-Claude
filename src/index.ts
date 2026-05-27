#!/usr/bin/env node

import { startBridge } from "./bridge.js";

const PORT = Number(process.env.PORT) || 3636;

async function main() {
  await startBridge(PORT);
  console.log(`\n  Roblox Studio AI Server`);
  console.log(`  ========================`);
  console.log(`  Server running on http://localhost:${PORT}`);
  console.log(`  Plugin polls:  http://localhost:${PORT}/poll`);
  console.log(`  Chat API:      http://localhost:${PORT}/chat`);
  console.log(`  Providers:     http://localhost:${PORT}/providers`);
  console.log(`  Health:        http://localhost:${PORT}/health`);
  console.log(`\n  Free AI providers:`);
  console.log(`    Groq         - https://console.groq.com (free API key)`);
  console.log(`    Gemini       - https://aistudio.google.com (free API key)`);
  console.log(`    Ollama       - http://localhost:11434 (no key needed)`);
  console.log(`    HuggingFace  - https://huggingface.co (free token)`);
  console.log(`\n  Waiting for Roblox Studio plugin to connect...\n`);
}

main().catch((err) => {
  console.error(`Fatal error: ${err}`);
  process.exit(1);
});
