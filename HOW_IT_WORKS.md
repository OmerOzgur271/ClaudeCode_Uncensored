# How this repo works

A short, plain-language tour. For setup steps see [README.md](README.md). For troubleshooting see [MANUAL.md](MANUAL.md).

## The problem

Claude Code only speaks one "language": the **Anthropic Messages API**.

Kimi K3.1 and GLM 5.3 on Amazon Bedrock only speak another one: the **OpenAI-compatible API**.

So Claude Code cannot talk to them directly. Setting `CLAUDE_CODE_USE_BEDROCK=1` does not help, because that only works for Anthropic's own models on Bedrock.

## The fix: a translator in the middle

The repo runs a small program called **LiteLLM** on your own computer. It acts as a translator.

```
You type in claude-bedrock
        │  (Anthropic format)
        ▼
LiteLLM proxy on 127.0.0.1:4000   ← runs locally, only your machine can reach it
        │  (OpenAI format)
        ▼
Bedrock  https://bedrock-runtime.<region>.amazonaws.com/openai/v1
        │
        ▼
Kimi K3.1  or  GLM 5.3
```

Claude Code thinks it is talking to Anthropic. It is really talking to LiteLLM, which forwards everything to Bedrock and translates the answers back.

## What `install.sh` does, step by step

1. **Reads settings** from `.env` (region, model IDs, port). It refuses bare model IDs like `zai.glm-5.3`. You must use a profile ID like `global.zai.glm-5.3`.
2. **Tests the key.** It sends a tiny "hi" to each model. Models that fail are dropped. If none work, it stops and changes nothing.
3. **Hides the key.** It moves the API key into the macOS Keychain (or Linux `secret-tool`, or a private file as a last resort). It checks the key was stored, then blanks it in `.env`.
4. **Sets up the proxy.** It installs LiteLLM with `uv` if needed. It writes the proxy config and a random local password (the "proxy key"). That password is not your Bedrock key. It stops other programs on your machine from using the proxy.
5. **Creates the `claude-bedrock` command.** This is a wrapper around the normal `claude` command with different settings.
6. **Hooks into your shell.** It adds one small block to `~/.zshrc` / `~/.bashrc`, so the new commands exist in new terminals. It saves a backup first.
7. **Cursor panel (optional).** If Cursor is installed, it switches Cursor's Claude Code chat panel to Bedrock too. Set `BEDROCK_CURSOR=off` in `.env` to skip this.
8. **Final test.** It asks the model to reply "hello" through Claude Code.

## What happens when you run `claude-bedrock`

1. It checks if the proxy is running. If not, it starts it in the background.
2. The proxy reads the Bedrock key from the secure store at start-up. The key is never saved in a config file.
3. Claude Code starts with these settings:
   - talk to `http://127.0.0.1:4000` instead of Anthropic,
   - use the first model as default and the second for `/model opus`,
   - use a separate config folder, `~/.claude-bedrock`.

Your normal `claude` command, login, settings and history in `~/.claude` stay untouched.

## Where things live

| Location | What is there |
|---|---|
| This repo | The installer, uninstaller and helper scripts |
| `lib/litellm_write.py` | Writes the proxy config (model list, Bedrock URL; no keys inside) |
| `lib/picker_write.py` | Makes the `/model` menu show only your Bedrock models, with readable names |
| `lib/cursor_toggle.py` | The `bedrock-cursor on / off / status` command for Cursor's chat panel |
| `~/.config/bedrock-agents/` | Everything the installer generates: proxy config, start script, shell functions, log |
| `~/.claude-bedrock/` | Claude Code's separate settings and history for Bedrock sessions |
| Keychain / secret-tool | The Bedrock API key |

## Everyday commands

| Command | What it does |
|---|---|
| `claude-bedrock` | Start Claude Code on Kimi / GLM |
| `/model opus` (inside Claude Code) | Switch to the second model |
| `bedrock-proxy-stop` | Stop the local proxy |
| `bedrock-cursor on` / `off` / `status` | Switch Cursor's Claude Code panel to Bedrock or back |
| `./uninstall.sh` | Undo everything (key, shell block, generated files, Cursor change) |

## Safety in one paragraph

The API key goes into the system's secure store and is removed from `.env`. The proxy listens only on `127.0.0.1`, so nothing on your network can reach it. A random local password protects it from other programs on your own machine. Your normal Claude Code setup is never modified.
