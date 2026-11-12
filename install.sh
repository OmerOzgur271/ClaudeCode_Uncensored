#!/usr/bin/env bash
# Runs Claude Code on Amazon Bedrock models (Kimi K3.1, GLM 5.3), e.g. in Cursor's terminal.
# Claude Code speaks the Anthropic API; these models only offer Bedrock's OpenAI-compatible API,
# so a local LiteLLM proxy (127.0.0.1 only) translates between them.
# Usage: ./install.sh           (reads settings from .env, then from your environment)
#        ./install.sh --no-test (skip the final test call)
# The Bedrock API key is never written to a config file: macOS Keychain, Linux secret-tool
# (or a file only you can read) is used instead.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$HOME/.config/bedrock-agents"
SERVICE="bedrock-agents-api-key"
STAMP="$(date +%Y%m%d-%H%M%S)"
ACCOUNT="${USER:-$(id -un)}"
TEST=1
[[ "${1:-}" == "--no-test" ]] && TEST=0

title() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
info()  { printf '    %s\n' "$*"; }

command -v claude >/dev/null || { fail "Claude Code (claude) not found. Install it first."; exit 1; }

# ---------- 1. Settings ----------
title "1. Settings"

env_read() { # read one value from .env without sourcing it
  local name="$1" file="$REPO/.env"
  [[ -f "$file" ]] || return 0
  sed -n "s/^[[:space:]]*$name[[:space:]]*=[[:space:]]*//p" "$file" | tail -1 | sed -e 's/^["'\'']//' -e 's/["'\'']$//' -e 's/[[:space:]]*$//'
}
setting() { # .env first, then the environment, then the default
  local name="$1" default="${2:-}" v
  v="$(env_read "$name")"
  [[ -z "$v" ]] && v="${!name:-}"
  printf '%s' "${v:-$default}"
}

REGION="$(setting AWS_REGION)"
MODELS="$(setting BEDROCK_MODELS global.moonshotai.kimi-k3.1,global.zai.glm-5.3)"
CONTEXT="$(setting BEDROCK_CONTEXT_WINDOW 1000000)"
PROXY_PORT="$(setting BEDROCK_PROXY_PORT 4000)"
LITELLM_SPEC="$(setting LITELLM_SPEC 'litellm[proxy]')"
KEY="$(setting AWS_BEARER_TOKEN_BEDROCK)"

if [[ ! "$REGION" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]+$ ]]; then
  fail "AWS_REGION is missing or invalid (${REGION:-empty}). Set it in .env, e.g. AWS_REGION=us-east-1"; exit 1
fi
[[ "$CONTEXT" =~ ^[0-9]+$ && "$PROXY_PORT" =~ ^[0-9]+$ ]] || { fail "BEDROCK_CONTEXT_WINDOW and BEDROCK_PROXY_PORT must be numbers."; exit 1; }
MODELS="$(printf '%s' "$MODELS" | tr -d '[:space:]')"
[[ -n "$MODELS" ]] || { fail "BEDROCK_MODELS is empty."; exit 1; }
for m in ${MODELS//,/ }; do
  case "$m" in
    moonshotai.*|zai.*) fail "$m is a bare model ID. Use an inference profile: global.$m or us.$m"; exit 1 ;;
  esac
done
BASE_URL="https://bedrock-runtime.$REGION.amazonaws.com/openai/v1"
ok "Region $REGION, endpoint $BASE_URL"

if [[ -z "$KEY" && -t 0 ]]; then
  read -rsp "  Bedrock API key (hidden, Enter to skip): " KEY; echo >&2
fi
if [[ -z "$KEY" && -x "$DIR/key" ]]; then # reinstall: reuse the stored key
  KEY="$("$DIR/key" 2>/dev/null || true)"
  [[ -n "$KEY" ]] && ok "Using the key from the previous install"
fi
[[ -n "$KEY" ]] || { fail "No API key. Copy .env.example to .env and set AWS_BEARER_TOKEN_BEDROCK."; exit 1; }

# ---------- 2. Check key and model access ----------
title "2. Checking key and model access"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
GOOD=()
for m in ${MODELS//,/ }; do
  body="{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":16,\"reasoning_effort\":\"low\"}"
  # The key goes through stdin, never on the command line
  code="$(curl -s -m 90 -o "$TMP" -w '%{http_code}' -H @- -H 'Content-Type: application/json' \
          --data "$body" "$BASE_URL/chat/completions" <<< "Authorization: Bearer $KEY" || true)"
  if [[ "$code" == "200" ]]; then
    ok "$m: reachable"; GOOD+=("$m")
  else
    msg="$(python3 -I -c 'import json,sys
try:
    d=json.load(open(sys.argv[1])); e=d.get("error",d); print((e.get("message") if isinstance(e,dict) else str(e)) or "")
except Exception: print(open(sys.argv[1],errors="replace").read()[:200])' "$TMP" 2>/dev/null | head -c 300)"
    fail "$m: HTTP ${code:-000} ${msg}"
    case "$code" in
      401|403) info "Key rejected or no access. Check the key, its IAM permissions and model access." ;;
      400|404) info "Check the model ID and that this profile exists in $REGION." ;;
      000) info "No connection to $BASE_URL." ;;
    esac
  fi
done
[[ ${#GOOD[@]} -gt 0 ]] || { fail "No usable model. Nothing changed."; exit 1; }
MODELS="$(IFS=,; echo "${GOOD[*]}")"
DEFAULT="${GOOD[0]}"
SECOND="${GOOD[1]:-$DEFAULT}"

# ---------- 3. Secure store ----------
title "3. Moving the key to the secure store"
STORE="${BEDROCK_AGENTS_STORE:-}"
if [[ -z "$STORE" ]]; then
  if [[ "$(uname)" == "Darwin" ]] && command -v security >/dev/null; then STORE=keychain
  elif command -v secret-tool >/dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then STORE=secret-tool
  else STORE=file; fi
fi
mkdir -p "$DIR"; chmod 700 "$DIR"

case "$STORE" in
  keychain) /usr/bin/security add-generic-password -U -s "$SERVICE" -a "$ACCOUNT" -l "Bedrock API key (bedrock-agents)" -w "$KEY" >/dev/null ;;
  secret-tool) printf '%s' "$KEY" | secret-tool store --label="Bedrock API key (bedrock-agents)" app bedrock-agents ;;
  file) ( umask 077; printf '%s\n' "$KEY" > "$DIR/api-key" ) ;;
esac

# The single helper the proxy uses to read the key
cat > "$DIR/key" <<EOF
#!/usr/bin/env bash
# Prints the Bedrock API key to the calling program. Do not run it in a terminal you share.
case "$STORE" in
  keychain) exec /usr/bin/security find-generic-password -s "$SERVICE" -a "\${USER:-\$(id -un)}" -w ;;
  secret-tool) exec secret-tool lookup app bedrock-agents ;;
  file) exec cat "\$HOME/.config/bedrock-agents/api-key" ;;
esac
EOF
chmod 700 "$DIR/key"

if [[ "$("$DIR/key" 2>/dev/null)" == "$KEY" ]]; then
  ok "Key stored ($STORE)"
else
  fail "Could not write the key to $STORE. .env left untouched."
  [[ "$STORE" == "keychain" ]] && info "If a Keychain prompt appeared, click Allow and run the script again."
  exit 1
fi
[[ "$STORE" == "file" ]] && warn "No Keychain/secret-tool: key is in $DIR/api-key (mode 600)."
KEY=""

if [[ -f "$REPO/.env" ]] && grep -qE '^AWS_BEARER_TOKEN_BEDROCK=.+' "$REPO/.env"; then
  sed -i.bak -E 's/^(AWS_BEARER_TOKEN_BEDROCK=).*/\1/' "$REPO/.env" && rm -f "$REPO/.env.bak"
  ok "Key removed from .env (now in the store)"
fi

# ---------- 4. LiteLLM proxy ----------
title "4. LiteLLM proxy"
LITELLM="$(command -v litellm || true)"
if [[ -z "$LITELLM" ]]; then
  command -v uv >/dev/null || { fail "LiteLLM not found and uv is missing. Install uv (brew install uv) or run: pipx install 'litellm[proxy]'"; exit 1; }
  info "Installing LiteLLM with uv: $LITELLM_SPEC"
  uv tool install --quiet "$LITELLM_SPEC" >/dev/null 2>&1 || { fail "uv tool install '$LITELLM_SPEC' failed."; exit 1; }
  LITELLM="$(command -v litellm || echo "$(uv tool dir --bin 2>/dev/null || echo "$HOME/.local/bin")/litellm")"
fi
[[ -x "$LITELLM" ]] || { fail "LiteLLM binary not found at $LITELLM."; exit 1; }
ok "LiteLLM: $LITELLM"

PROXY_URL="http://127.0.0.1:$PROXY_PORT"
# Local proxy password (not the Bedrock key): stops other local programs from using your Bedrock key
[[ -s "$DIR/proxy-key" ]] || ( umask 077; python3 -I -c 'import secrets; print("sk-local-" + secrets.token_urlsafe(32))' > "$DIR/proxy-key" )
PROXY_KEY="$(cat "$DIR/proxy-key")"
python3 -I "$REPO/lib/litellm_write.py" "$DIR/litellm.yaml" "$BASE_URL" "$MODELS"
cat > "$DIR/proxy.sh" <<EOF
#!/usr/bin/env bash
# Starts the local LiteLLM proxy for Claude Code. Listens on 127.0.0.1 only.
set -euo pipefail
export BEDROCK_API_KEY="\$("$DIR/key")"
export LITELLM_MASTER_KEY="\$(cat "$DIR/proxy-key")"
exec "$LITELLM" --config "$DIR/litellm.yaml" --host 127.0.0.1 --port $PROXY_PORT
EOF
chmod 700 "$DIR/proxy.sh"
ok "Proxy config written ($PROXY_URL)"

# ---------- 5. Claude Code command ----------
title "5. Claude Code"
python3 -I - "$DIR/claude-env.sh" <<PY
import os, shlex, sys
env = {
    "ANTHROPIC_BASE_URL": "$PROXY_URL",
    "ANTHROPIC_AUTH_TOKEN": "$PROXY_KEY",
    "ANTHROPIC_MODEL": "$DEFAULT",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$SECOND",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$DEFAULT",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$DEFAULT",
    "CLAUDE_CODE_SUBAGENT_MODEL": "$DEFAULT",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "$CONTEXT",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    # Separate config dir: your normal Claude login, settings and history stay apart
    "CLAUDE_CONFIG_DIR": os.path.expanduser("~/.claude-bedrock"),
}
os.umask(0o077)
with open(sys.argv[1], "w") as f:
    f.writelines(f"export {k}={shlex.quote(v)}\n" for k, v in env.items())
PY

SHELL_FILE="$DIR/shell.sh"
cat > "$SHELL_FILE" <<EOF
# Generated by bedrock-agents ($STAMP). Do not edit; ./install.sh regenerates it.

# Start the local proxy if it is not running yet
bedrock-proxy-up() {
  curl -s -m 1 -o /dev/null "$PROXY_URL/health/liveliness" && return 0
  ( nohup /bin/bash "$DIR/proxy.sh" >> "$DIR/proxy.log" 2>&1 & echo \$! > "$DIR/proxy.pid" )
  local i=0
  while (( i < 60 )); do
    curl -s -m 1 -o /dev/null "$PROXY_URL/health/liveliness" && return 0
    sleep 1; i=\$((i + 1))
  done
  echo "bedrock proxy did not start; see $DIR/proxy.log" >&2; return 1
}
bedrock-proxy-stop() {
  [ -f "$DIR/proxy.pid" ] && kill "\$(cat "$DIR/proxy.pid")" 2>/dev/null
  rm -f "$DIR/proxy.pid"
}

# Claude Code on Bedrock (normal 'claude' is unchanged)
claude-bedrock() {
  bedrock-proxy-up || return 1
  (
    unset ANTHROPIC_API_KEY CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
    . "$DIR/claude-env.sh"
    command claude "\$@"
  )
}
EOF
cp "$REPO/lib/cursor_toggle.py" "$DIR/cursor_toggle.py"
cat >> "$SHELL_FILE" <<EOF

# Claude Code panel in Cursor: bedrock-cursor on | off | status
bedrock-cursor() { python3 -I "$DIR/cursor_toggle.py" "\$@"; }
EOF
ok "claude-bedrock command ready (default $DEFAULT, /model opus = $SECOND)"
ok "bedrock-cursor command ready (switches the Claude Code panel in Cursor)"

# /model picker: only the Bedrock models, with readable names (separate config dir, not ~/.claude)
python3 -I "$REPO/lib/picker_write.py" "$HOME/.claude-bedrock/settings.json" "$MODELS" "$STAMP"
ok "Model picker set: ~/.claude-bedrock/settings.json (built-in Anthropic rows hidden)"

# ---------- 6. Shell ----------
title "6. Shell setup"
START="# >>> bedrock-agents >>>"; END="# <<< bedrock-agents <<<"
rc_write() {
  local rc="$1"
  [[ -f "$rc" ]] || touch "$rc"
  cp -p "$rc" "$rc.bedrock-backup-$STAMP"
  python3 -I - "$rc" "$START" "$END" "$SHELL_FILE" <<'PY'
import sys, re
rc, start, end, shell = sys.argv[1:]
t = open(rc, encoding="utf-8").read()
t = re.sub(re.escape(start) + r".*?" + re.escape(end) + r"\n?", "", t, flags=re.S)
block = f'{start}\n[ -f "{shell}" ] && . "{shell}"\n{end}\n'
open(rc, "w", encoding="utf-8").write(t.rstrip("\n") + "\n\n" + block)
PY
  ok "$rc updated (backup: $(basename "$rc").bedrock-backup-$STAMP)"
}
RCS=()
[[ -f "$HOME/.zshrc" || "${SHELL:-}" == */zsh ]] && RCS+=("$HOME/.zshrc")
[[ -f "$HOME/.bashrc" || "${SHELL:-}" == */bash ]] && RCS+=("$HOME/.bashrc")
for rc in ${RCS[@]+"${RCS[@]}"}; do rc_write "$rc"; done

# ---------- 7. Cursor ----------
CURSOR_SETTINGS_DIR="$HOME/Library/Application Support/Cursor/User"
[[ "$(uname)" == "Darwin" ]] || CURSOR_SETTINGS_DIR="$HOME/.config/Cursor/User"
if [[ "$(setting BEDROCK_CURSOR on)" == "on" && -d "$CURSOR_SETTINGS_DIR" ]]; then
  title "7. Cursor Claude Code panel"
  if python3 -I "$DIR/cursor_toggle.py" on; then ok "Cursor panel uses Bedrock. Cmd+Shift+P > Developer: Reload Window"
  else fail "Could not switch the Cursor panel; run 'bedrock-cursor on' by hand."; fi
fi

# ---------- 8. Test ----------
if [[ $TEST == 1 ]]; then
  title "8. Test (one-word reply)"
  out="$(cd /tmp && perl -e 'alarm shift; exec @ARGV' 240 bash -c ". '$SHELL_FILE'; claude-bedrock -p 'Reply with exactly one word: hello'" < /dev/null 2>/dev/null | tr -d '\r' | grep -v '^\s*$' | tail -1 || true)"
  if printf '%s' "$out" | grep -qi hello; then ok "Claude Code ($DEFAULT): $out"
  else fail "Claude Code: no answer (${out:-empty}). Proxy log: $DIR/proxy.log"; fi
fi

title "Done"
info "Open a new terminal (in Cursor: Terminal > New Terminal), then run:"
info "  claude-bedrock          Claude Code on $DEFAULT"
info "  bedrock-proxy-stop      stop the local proxy (claude-bedrock starts it again)"
info "  bedrock-cursor off      Claude Code panel in Cursor back to Anthropic ('on' to switch again, then reload window)"
info "Models: $MODELS"
info "Uninstall: ./uninstall.sh"
