# Claude Code Uncensored on Amazon Bedrock with Kimi K3.1 Pro and GLM 5.3

**Run Claude Code with Kimi K3.1 Pro and GLM 5.3 through Amazon Bedrock.** One install script sets up a local LiteLLM proxy and adds a `claude-bedrock` command. You keep the Claude Code CLI and workflow, and Bedrock runs the models. It works in any terminal, in the Cursor terminal, and in Cursor's Claude Code panel.

```text
claude-bedrock → LiteLLM on 127.0.0.1:4000 → Amazon Bedrock → Kimi K3.1 / GLM 5.3
```

## Why use this repo?

- **Keep Claude Code, change the model.** You keep Claude Code's agent loop, tools, slash commands, and permission prompts. Kimi K3.1 Pro or GLM 5.3 does the reasoning.
- **Billing through your AWS account.** Usage goes on your AWS bill and appears in Bedrock's metrics. You do not need another AI vendor account or subscription.
- **Requests stay on AWS.** Prompts and code go from your computer to Bedrock in the AWS region you choose. Your AWS account controls access through IAM, quotas, and logging.
- **Your key stays out of config files.** The installer moves your Bedrock API key to the macOS Keychain or the Linux secret store, then blanks it in `.env`.
- **The proxy is local only.** LiteLLM listens on `127.0.0.1` and uses a random local password. Other computers cannot reach it.
- **Your normal setup stays the same.** `claude` and `~/.claude` do not change. Bedrock sessions use a separate `~/.claude-bedrock` profile, so you can run both side by side.
- **Two models, one command.** Kimi K3.1 Pro is the default. Type `/model opus` to switch to GLM 5.3 during a session.
- **Large context window.** Claude Code is set to a 1,000,000-token context before it compacts the conversation. You can change this with `BEDROCK_CONTEXT_WINDOW`.
- **Cursor integration.** One command switches Cursor's Claude Code panel to Bedrock, and another switches it back.
- **Install checks your setup first.** The installer tests your key against each model and reports each check as ✓ or ✗, so you find problems before your first session.
- **Easy to remove.** `./uninstall.sh` removes everything the installer added.

## Who is it for?

- Developers who like Claude Code and want to try Kimi or GLM as coding agents.
- Teams that must keep AI usage inside an AWS account for billing, compliance, or procurement.
- Cursor users who want Bedrock models in the Claude Code panel.
- Developers who want to compare coding models with the same agent and tools.

## Requirements

- Claude Code (`claude` command)
- macOS or Linux (use WSL on Windows)
- A long-term Amazon Bedrock API key (short-term keys expire after 12 hours)
- Access to Kimi K3.1 and GLM 5.3 enabled in your Bedrock account

## Quick start

1. Install `uv`:

   ```bash
   brew install uv
   ```

2. Create your configuration:

   ```bash
   cp .env.example .env
   ```

3. Open `.env` and enter your Bedrock API key and region:

   ```dotenv
   AWS_BEARER_TOKEN_BEDROCK=your_key
   AWS_REGION=us-east-1
   ```

   Keep the other defaults unless you need different models or ports.

4. Run the installer:

   ```bash
   ./install.sh
   ```

   The installer checks model access, moves your key to the macOS Keychain or Linux secret store, installs the local LiteLLM proxy, and creates the `claude-bedrock` command.

5. Open a **new terminal** (in Cursor: **Terminal → New Terminal**) and start:

   ```bash
   claude-bedrock
   ```

## Commands

| Command | Purpose |
|---|---|
| `claude-bedrock` | Start Claude Code on Bedrock. Starts the local proxy automatically. |
| `/model opus` | Switch to the second model inside Claude Code. |
| `bedrock-proxy-stop` | Stop the local proxy. |
| `bedrock-cursor status` | Show whether Cursor's Claude Code panel uses Bedrock. |
| `bedrock-cursor on` | Switch Cursor's panel to Bedrock. Reload Cursor afterward. |
| `bedrock-cursor off` | Restore Cursor's normal Claude Code panel. |

## Use Claude Code on Bedrock in Cursor

Enable Claude Code on Bedrock in Cursor:

```bash
bedrock-cursor on
```

Switch back to your normal Claude Code setup:

```bash
bedrock-cursor off
```

After either command, run **Cmd+Shift+P → Developer: Reload Window** in Cursor.

If Cursor is installed, setup switches its Claude Code panel to Bedrock automatically. To skip this, set `BEDROCK_CURSOR=off` in `.env`.

## Supported models

| Model | Default inference profile |
|---|---|
| Kimi K3.1 Pro (Moonshot AI) | `global.moonshotai.kimi-k3.1` |
| GLM 5.3 (Z.ai) | `global.zai.glm-5.3` |

Change `BEDROCK_MODELS` in `.env` to use different inference profiles. The first model is the default; the second is selected with `/model opus`. GLM 5.3 is available only to eligible AWS accounts.

## FAQ

### Can Claude Code use models other than Claude?

Yes. Claude Code sends requests in the Anthropic Messages format. This repo runs a local LiteLLM proxy that translates those requests for Bedrock's OpenAI-compatible API. Kimi K3.1 and GLM 5.3 then answer through Bedrock.

### Why not set `CLAUDE_CODE_USE_BEDROCK=1`?

That setting works only for Anthropic models on Bedrock. Kimi and GLM need the proxy.

### Does this change my normal Claude Code setup?

No. Your `claude` command and `~/.claude` settings stay the same. `claude-bedrock` uses `~/.claude-bedrock`.

### Where is my API key stored?

In the macOS Keychain or the Linux secret store. The installer blanks it in `.env` after it stores the key.

### Is the proxy exposed to my network?

No. It listens only on `127.0.0.1` and requires a random local password.

## Troubleshooting

If installation reports a failed check, see [MANUAL.md](MANUAL.md).

- **401 or 403:** Check your API key, IAM permissions, and model access.
- **400 or 404:** Check the model profile and AWS region.
- **No answer after setup:** Check `~/.config/bedrock-agents/proxy.log`.
- **Cursor panel unchanged:** Reload the window, then run `bedrock-cursor status`.

## Uninstall

```bash
./uninstall.sh
```

## How it works

```text
claude-bedrock → LiteLLM on 127.0.0.1:4000 → Bedrock → Kimi K3.1 / GLM 5.3
```

The proxy listens only on your computer. Your Bedrock key stays in the secure store, not in a configuration file. For details, see [HOW_IT_WORKS.md](HOW_IT_WORKS.md) and [MANUAL.md](MANUAL.md).

## License

MIT
