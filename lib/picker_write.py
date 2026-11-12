"""Make Claude Code's /model picker show only the Bedrock models, with readable names.

Usage: picker_write.py <settings.json> <models-csv> <timestamp>
Writes into the separate Claude Code config dir used by claude-bedrock (~/.claude-bedrock),
never into your normal ~/.claude. Other keys in the file are kept. Needs Claude Code v2.1.242+.
"""
import json
import os
import shutil
import sys

path, models_csv, stamp = sys.argv[1:4]
models = [m.strip() for m in models_csv.split(",") if m.strip()]

KNOWN = {"moonshotai.kimi-k3.1": "Kimi K3.1 Pro", "zai.glm-5.3": "GLM 5.3"}


def label(model_id):
    prefix, _, base = model_id.partition(".")
    return KNOWN.get(base, KNOWN.get(model_id, model_id))


data = {}
if os.path.exists(path):
    data = json.load(open(path, encoding="utf-8"))
    shutil.copy2(path, f"{path}.bedrock-backup-{stamp}")

data["model"] = models[0]
data["modelPicker"] = {
    # Hide the built-in Anthropic rows (Opus, Sonnet, Fable...): the proxy can't serve them
    "replaceBuiltInOptions": True,
    "options": [
        {"model": m, "label": label(m), "description": f"Amazon Bedrock · {m}"}
        for m in models
    ],
}

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
