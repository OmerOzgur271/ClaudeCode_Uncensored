# Agent instructions: Claude Code on Bedrock (Kimi K3.1, GLM 5.3)

When the user opens this repo and asks you to install it:

1. Do **not** ask the user to type the API key into the chat. The key must never appear in chat, logs or files as plain text.
2. Check whether `.env` exists (`test -f .env`) but do **not** read its contents. If it is missing, tell the user: "create it with `cp .env.example .env` and paste your key yourself", or "run `./install.sh` in your own terminal; it asks for the key hidden".
3. When the user says `.env` is filled in, run `./install.sh`. The script checks the key against each model, moves the key to the secure store, blanks it in `.env`, sets up the local LiteLLM proxy and the `claude-bedrock` command, and runs a test.
4. Summarize the ✓ and ✗ lines of the output. For ✗ lines, check the "Troubleshooting" table in MANUAL.md.
5. Remind the user to open a new terminal (in Cursor: Terminal > New Terminal) and run `claude-bedrock`.

Rules:

- Never print the output of `security find-generic-password ... -w`, `secret-tool lookup`, `~/.config/bedrock-agents/key` or `~/.config/bedrock-agents/api-key`. That output is the key itself.
- Never print `.env`, `~/.config/bedrock-agents/proxy-key`, `claude-env.sh`, or the value of `AWS_BEARER_TOKEN_BEDROCK`.
- Do not change the user's normal `~/.claude` settings. `claude-bedrock` uses `~/.claude-bedrock`.
- Do not set `CLAUDE_CODE_USE_BEDROCK=1` for Kimi or GLM; it only works for Anthropic models.
- Do not expose the proxy beyond `127.0.0.1`.
- Do not suggest `--dangerously-skip-permissions`.
- Uninstall: `./uninstall.sh`.
