---
name: bedrock-setup
description: Sets up Claude Code to run on Amazon Bedrock's Kimi K3.1 and GLM 5.3 through a local LiteLLM proxy (works in Cursor's terminal). Use when the user says "install this repo", "set up bedrock", "use kimi/glm in claude code", or "run install.sh".
---

# Claude Code on Bedrock setup

Follow [AGENTS.md](../../../AGENTS.md) in the repo root. Summary:

1. Never ask for the key in chat. Never read `.env`.
2. If `.env` is missing: the user runs `cp .env.example .env` and pastes the key themselves, or runs `./install.sh` in their own terminal.
3. When `.env` is ready, run `./install.sh` and summarize the ✓ / ✗ lines.
4. On problems: [MANUAL.md](../../../MANUAL.md) > "Troubleshooting".
5. Remind the user to open a new terminal and run `claude-bedrock`.

Never print the output of key-reading commands (`security ... -w`, `secret-tool lookup`, `~/.config/bedrock-agents/key`) or the proxy key.
