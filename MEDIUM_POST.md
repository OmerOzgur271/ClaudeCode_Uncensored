# Running Kimi K3.1 and GLM 5.3 inside Claude Code — on Amazon Bedrock

*How I got two non-Anthropic models to run inside the Claude Code CLI and the Cursor chat panel, without leaking an API key.*

---

## The problem

Claude Code is great, but it only speaks one API: the **Anthropic Messages API**.

Amazon Bedrock now hosts other strong coding models — **Kimi K3.1 Pro** and **GLM 5.3**. The catch: on Bedrock these two only expose the **OpenAI-compatible API** (`/openai/v1`). They do not accept Anthropic-format requests.

So the obvious move fails. Setting `CLAUDE_CODE_USE_BEDROCK=1` does **not** route Claude Code to Kimi or GLM — that flag only works for Anthropic's own models on Bedrock. Point Claude Code straight at the Bedrock OpenAI endpoint and every request gets rejected, because the request bodies are in the wrong format.

Two APIs that don't understand each other. That's the whole problem.

## My solution: a translator on localhost

Put a small translator between Claude Code and Bedrock. I use **LiteLLM**, running as a tiny proxy on `127.0.0.1` only.

```
Claude Code  ──(Anthropic format)──▶  LiteLLM proxy  ──(OpenAI format)──▶  Bedrock /openai/v1  ──▶  Kimi K3.1 / GLM 5.3
127.0.0.1:4000
```

Claude Code believes it is talking to Anthropic. It is really talking to the local proxy, which rewrites every request into OpenAI format, forwards it to Bedrock, and translates the answer back.

One design choice worth noting: the proxy uses Bedrock's **Chat Completions** route (`openai/<model>`), not Converse. Kimi K3.1 breaks on Converse in multi-turn chats that carry reasoning blocks, so Chat Completions is the safe path.

It works. Here is Kimi K3.1 answering inside the Claude Code panel in Cursor:

![Kimi K3.1 running inside Claude Code for VS Code](content/Ekran%20Resmi%202026-11-12%2013.18.18.png)

And the normal `claude` command is untouched — it still runs Anthropic's own model, with its own login and history:

![The normal claude command still runs Anthropic's Opus](content/Ekran%20Resmi%202026-11-12%2013.18.55.png)

The two live side by side: `claude` for Anthropic, `claude-bedrock` for Kimi/GLM.

## The AWS side

On Bedrock you need three things:

1. **Model access** enabled in the Bedrock console. GLM 5.3 is limited to eligible accounts — ask your AWS account team if it isn't listed.
2. A **long-term Bedrock API key** (Bedrock console → API keys). Short-term keys expire after 12 hours.
3. The right **inference profile IDs**. Bare IDs like `zai.glm-5.3` do not work; in-Region inference isn't supported for these. You must use a cross-Region profile:

| Model | Profile ID |
|---|---|
| Kimi K3.1 Pro | `global.moonshotai.kimi-k3.1` (or `us.` / `in.`) |
| GLM 5.3 | `global.zai.glm-5.3` (or `us.`, eligible accounts only) |

The endpoint the proxy calls is `https://bedrock-runtime.<region>.amazonaws.com/openai/v1`. One billing warning: both models count **output tokens 10× against your quotas**, so watch throttling.

## How it works, end to end

An installer (`install.sh`) wires the whole thing up:

1. **Read and validate settings** from `.env` — region, model IDs, port. It rejects bare model IDs on the spot.
2. **Probe each model** with a tiny request. Models that fail (wrong key, no access) are dropped; if none pass, it stops and changes nothing.
3. **Hide the key.** The Bedrock key goes into the macOS Keychain (or Linux `secret-tool`, or a `600` file as a last resort), then it is blanked out of `.env`. The key never lives in a config file.
4. **Start the proxy.** LiteLLM is installed with `uv` if missing. A random **local** proxy password is generated — separate from the Bedrock key — so other programs on your machine can't ride your proxy.
5. **Create `claude-bedrock`,** a wrapper that points Claude Code at `http://127.0.0.1:4000`, maps the models (default model + `/model opus` for the second), and uses a **separate config dir** (`~/.claude-bedrock`) so your normal Claude setup stays apart.
6. **Optional Cursor switch.** It can flip the Claude Code chat panel in Cursor over to Bedrock too, and restore it exactly on `off`.

When you run `claude-bedrock`, it starts the proxy if needed, the proxy reads the key from the secure store at launch, and Claude Code talks to Bedrock through it.

## Security notes

- The API key lives in the OS secure store, never in `.env` or any config file after install.
- The proxy binds to `127.0.0.1` only — nothing on your network can reach it.
- A random local password guards it against other local processes.
- Your normal `~/.claude` login, settings, and history are never modified; Bedrock mode uses `~/.claude-bedrock`.

## Caveats

Claude Code is tuned for Claude models. Tool use and long agent tasks can be less reliable on Kimi or GLM. Keep tool-call approval on. And plugins are per-config-dir: anything installed under `~/.claude` won't appear in Bedrock mode until you install it again under `~/.claude-bedrock`.

---

*Uninstall with `./uninstall.sh`. On Windows, use WSL. License: MIT.*
