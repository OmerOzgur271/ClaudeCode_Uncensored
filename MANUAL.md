# Manual setup and troubleshooting

`install.sh` does all of this for you. This page shows what it creates, or how to set it up by hand.

## Files

All of these are in `~/.config/bedrock-agents/` (folder mode 700):

| File | Content |
|---|---|
| `key` | Helper that prints the Bedrock key from Keychain / secret-tool. Never run it in a shared terminal. |
| `proxy-key` | Random local proxy password. This is not the Bedrock key. |
| `litellm.yaml` | Proxy config (no keys inside) |
| `proxy.sh` | Starts LiteLLM on `127.0.0.1:<port>` |
| `claude-env.sh` | Environment variables for `claude-bedrock` |
| `shell.sh` | `claude-bedrock`, `bedrock-proxy-up`, `bedrock-proxy-stop` |
| `proxy.log`, `proxy.pid` | Proxy log and process ID |

## By hand

1. Store the key (macOS):

   ```bash
   security add-generic-password -U -s bedrock-agents-api-key -a "$USER" -w
   ```

2. Proxy config, `litellm.yaml`:

   ```yaml
   model_list:
     - model_name: global.moonshotai.kimi-k3.1
       litellm_params:
         model: openai/global.moonshotai.kimi-k3.1
         api_base: https://bedrock-runtime.us-east-1.amazonaws.com/openai/v1
         api_key: os.environ/BEDROCK_API_KEY
     - model_name: global.zai.glm-5.3
       litellm_params:
         model: openai/global.zai.glm-5.3
         api_base: https://bedrock-runtime.us-east-1.amazonaws.com/openai/v1
         api_key: os.environ/BEDROCK_API_KEY
   litellm_settings:
     drop_params: true
   general_settings:
     master_key: os.environ/LITELLM_MASTER_KEY
   ```

   The `openai/` prefix sends requests to Bedrock's Chat Completions API, not Converse. On Converse, Kimi K3.1 fails in multi-turn chats that carry reasoning blocks.

3. Start the proxy:

   ```bash
   BEDROCK_API_KEY="$(security find-generic-password -s bedrock-agents-api-key -a "$USER" -w)" \
   LITELLM_MASTER_KEY=sk-local-something-random \
   litellm --config litellm.yaml --host 127.0.0.1 --port 4000
   ```

4. Run Claude Code against it:

   ```bash
   ANTHROPIC_BASE_URL=http://127.0.0.1:4000 \
   ANTHROPIC_AUTH_TOKEN=sk-local-something-random \
   ANTHROPIC_MODEL=global.moonshotai.kimi-k3.1 \
   ANTHROPIC_DEFAULT_OPUS_MODEL=global.zai.glm-5.3 \
   ANTHROPIC_DEFAULT_SONNET_MODEL=global.moonshotai.kimi-k3.1 \
   ANTHROPIC_DEFAULT_HAIKU_MODEL=global.moonshotai.kimi-k3.1 \
   CLAUDE_CODE_SUBAGENT_MODEL=global.moonshotai.kimi-k3.1 \
   CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 \
   CLAUDE_CONFIG_DIR="$HOME/.claude-bedrock" \
   claude
   ```

   Do not set `CLAUDE_CODE_USE_BEDROCK=1` here. That makes Claude Code send Anthropic-format requests straight to Bedrock, and these models reject them.

## Anthropic models on Bedrock (no proxy)

For Claude models on Bedrock you do not need this repo. Add this to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1"
  }
}
```

Authentication uses your AWS credentials or `AWS_BEARER_TOKEN_BEDROCK`. This route works only for `*.anthropic.*` model IDs, not for Kimi or GLM.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `bedrock proxy did not start` | LiteLLM crashed or the port is busy | Read `~/.config/bedrock-agents/proxy.log`; change `BEDROCK_PROXY_PORT` and rerun `./install.sh` |
| Claude Code shows a login prompt | Ran `claude` instead of `claude-bedrock` | Use `claude-bedrock` in a new terminal |
| `401` from the proxy | Proxy password mismatch | Run `bedrock-proxy-stop`, then `claude-bedrock` again |
| HTTP 400, on-demand throughput / invalid model | Bare model ID (`zai.glm-5.3`) | Use the `global.` or `us.` profile ID |
| HTTP 403 | No model access, or the key lacks Bedrock IAM permissions | Enable model access; check the key's IAM policy |
| HTTP 403 on GLM 5.3 only | GLM 5.3 is limited to eligible accounts | Ask your AWS account team, or remove it from `BEDROCK_MODELS` |
| HTTP 401 from Bedrock | Key wrong or expired (short-term keys last 12 hours) | Put a long-term key in `.env` and rerun `./install.sh` |
| HTTP 404 | Profile not offered from this Region | Use the `global.` profile or a supported Region |
| HTTP 429 / throttling | Quota hit; output tokens count 10x | Wait, or request a quota increase |
| `claude-bedrock: command not found` | Old terminal | Open a new terminal, or `source ~/.zshrc` |
