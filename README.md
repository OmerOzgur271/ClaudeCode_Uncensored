# Claude Code on Bedrock

Use Claude Code with **Kimi K3.1 Pro** and **GLM 5.3** through Amazon Bedrock. Works in any terminal, including Cursor.

## Requirements

- Claude Code (`claude` command)
- macOS or Linux (use WSL on Windows)
- A long-term Bedrock API key
- Kimi K3.1 and GLM 5.3 enabled in your Bedrock account

## Setup

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

### Cursor panel

Enable Claude Code on Bedrock in Cursor:

```bash
bedrock-cursor on
```

Switch back to your normal Claude Code setup:

```bash
bedrock-cursor off
```

After either command, run **Cmd+Shift+P → Developer: Reload Window** in Cursor.

With Cursor installed, setup enables its Claude Code panel for Bedrock automatically. To skip this during setup, set `BEDROCK_CURSOR=off` in `.env`.

Your normal `claude` command and `~/.claude` settings remain unchanged. Bedrock uses `~/.claude-bedrock` instead.

## Models

| Model | Default profile |
|---|---|
| Kimi K3.1 Pro | `global.moonshotai.kimi-k3.1` |
| GLM 5.3 | `global.zai.glm-5.3` |

Change `BEDROCK_MODELS` in `.env` to use different inference profiles. The first model is the default; the second is selected with `/model opus`. GLM 5.3 is available only to eligible AWS accounts.

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

The proxy listens only on your computer. Your Bedrock key stays in the secure store, not in a configuration file.

License: MIT
