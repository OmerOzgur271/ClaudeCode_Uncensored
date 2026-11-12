# Claude Code on Bedrock: Kimi K3.1 and GLM 5.3

Runs **Claude Code** on **Kimi K3.1 Pro** and **GLM 5.3** from Amazon Bedrock. It works in any terminal, including Cursor's integrated terminal.

Claude Code speaks the Anthropic Messages API. On Bedrock, Kimi K3.1 and GLM 5.3 only offer the OpenAI-compatible API (`https://bedrock-runtime.<region>.amazonaws.com/openai/v1`). So `CLAUDE_CODE_USE_BEDROCK=1` does not work for them; it only works for Anthropic's own models. This repo runs a small local [LiteLLM](https://github.com/BerriAI/litellm) proxy on `127.0.0.1` that translates between the two formats.

```
claude-bedrock  ->  LiteLLM on 127.0.0.1:4000  ->  Bedrock /openai/v1  ->  Kimi K3.1 / GLM 5.3
```

The Bedrock API key is never written to a config file. It lives in the macOS Keychain or the Linux secret store (secret-tool), and the proxy reads it from there.

## Before you start

1. Enable model access in the Bedrock console. GLM 5.3 is limited to eligible accounts; ask your AWS account team if it is not listed.
2. Create a **long-term** Bedrock API key: Bedrock console > API keys. Short-term keys expire after 12 hours.
3. Install Claude Code, and `uv` (`brew install uv`). The installer uses uv to install LiteLLM.

## Install (macOS and Linux)

```bash
cp .env.example .env
```

Open `.env` and fill it in:

| Variable | Required | Meaning |
|---|---|---|
| `AWS_BEARER_TOKEN_BEDROCK` | yes | Bedrock API key. Moved to the secure store, then blanked in `.env`. |
| `AWS_REGION` | yes | Region you send requests to, e.g. `us-east-1`. |
| `BEDROCK_MODELS` | no | Inference profile IDs, comma-separated. First = default model, second = `/model opus`. Default: `global.moonshotai.kimi-k3.1,global.zai.glm-5.3` |
| `BEDROCK_CONTEXT_WINDOW` | no | Context size Claude Code assumes. Default `1000000`. |
| `BEDROCK_PROXY_PORT` | no | Local proxy port. Default `4000`. |
| `LITELLM_SPEC` | no | Package spec for `uv tool install`. Pin a version you trust. |

Empty values in `.env` are read from your shell environment instead. Then:

```bash
./install.sh
```

The script runs these steps in order:

1. Reads the settings and rejects bare model IDs. Both models need a `global.` or `us.` profile.
2. Sends a tiny request to each model, so a wrong key or missing model access shows up now. Models that fail are left out.
3. Stores the key, reads it back to check, and blanks it in `.env`.
4. Installs LiteLLM if needed and writes the proxy config.
5. Creates the `claude-bedrock` command and adds a one-line block to `~/.zshrc` / `~/.bashrc`.
6. Sends a one-word test prompt through Claude Code.

## Use

Open a new terminal. In Cursor, use Terminal > New Terminal.

| Command | What it does |
|---|---|
| `claude-bedrock` | Claude Code on the first model. It starts the proxy if it is not running. |
| `/model opus` (inside) | Switches to the second model. |
| `bedrock-proxy-stop` | Stops the local proxy. |
| `bedrock-cursor on` | Makes the Claude Code **chat panel** in Cursor use Bedrock and keeps the proxy running at login (macOS). `install.sh` runs this automatically when Cursor is installed (set `BEDROCK_CURSOR=off` in `.env` to skip). Then Cmd+Shift+P > Developer: Reload Window. |
| `bedrock-cursor off` | Restores your normal Claude Code panel settings exactly (a backup is made on every switch). |
| `bedrock-cursor status` | Shows which mode the panel uses. |

`bedrock-cursor` changes Cursor's user settings, so it affects every Claude Code panel in every Cursor window. To keep one window on Anthropic, create a Cursor profile for Bedrock and run `bedrock-cursor on --settings "<that profile's settings.json>"`.

The `/model` picker lists only your Bedrock models, with readable names. The installer sets `modelPicker` in `~/.claude-bedrock/settings.json` and hides the built-in Anthropic rows, because the proxy can't serve them. This needs Claude Code v2.1.242 or later.

Your normal `claude` command does not change. `claude-bedrock` uses a separate config dir (`~/.claude-bedrock`), so your normal Claude login, settings and history stay apart.

Uninstall: `./uninstall.sh`

## Model IDs

| Model | Global profile | Geo profiles |
|---|---|---|
| Kimi K3.1 Pro (Highspeed) | `global.moonshotai.kimi-k3.1` | `us.moonshotai.kimi-k3.1`, `in.moonshotai.kimi-k3.1` |
| GLM 5.3 | `global.zai.glm-5.3` | `us.zai.glm-5.3` |

Confirm them for your account with `aws bedrock list-inference-profiles --region <region>`. Both models count output tokens 10x against your quotas.

## Notes

- Claude Code is tuned for Claude models. Tool use and long tasks may be less reliable with Kimi or GLM.
- The proxy only listens on `127.0.0.1` and needs a random local password (`~/.config/bedrock-agents/proxy-key`). Do not expose it on your network.
- Keep tool-call approval on.

Troubleshooting and manual setup: [MANUAL.md](MANUAL.md). Agent instructions: [AGENTS.md](AGENTS.md).

On Windows, use WSL.

License: MIT
