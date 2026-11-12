"""Write the LiteLLM proxy config that lets Claude Code talk to Bedrock.

Claude Code speaks the Anthropic Messages API. LiteLLM accepts that on /v1/messages and
forwards each request to Bedrock's OpenAI-compatible Chat Completions endpoint.
The `openai/` route is used on purpose: Kimi K3.1 has known multi-turn problems on Converse.

Usage: litellm_write.py <target.yaml> <base-url> <models-csv>
Keys are not written: the proxy reads BEDROCK_API_KEY and LITELLM_MASTER_KEY from its environment.
JSON is valid YAML, so the file is written as JSON.
"""
import json
import os
import sys

target, base_url, models_csv = sys.argv[1:4]
models = [m.strip() for m in models_csv.split(",") if m.strip()]

config = {
    "model_list": [
        {
            "model_name": m,
            "litellm_params": {
                "model": f"openai/{m}",
                "api_base": base_url,
                "api_key": "os.environ/BEDROCK_API_KEY",
            },
        }
        for m in models
    ],
    # Drop Anthropic-only parameters the OpenAI endpoint would reject
    "litellm_settings": {"drop_params": True},
    "general_settings": {"master_key": "os.environ/LITELLM_MASTER_KEY"},
}

mask = os.umask(0o077)
with open(target, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
os.umask(mask)
