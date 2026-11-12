#!/usr/bin/env bash
# Undoes everything install.sh did: stops the proxy, removes the shell block,
# the stored key and ~/.config/bedrock-agents. Backup files are left in place.
set -euo pipefail

DIR="$HOME/.config/bedrock-agents"
SERVICE="bedrock-agents-api-key"
ACCOUNT="${USER:-$(id -un)}"
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }

# Cursor panel: restore settings and remove the login service (needs the saved state in $DIR)
if [[ -f "$DIR/cursor_toggle.py" ]]; then
  python3 -I "$DIR/cursor_toggle.py" off && ok "Cursor: Claude Code panel restored (reload the window)"
fi

# Proxy
if [[ -f "$DIR/proxy.pid" ]]; then
  kill "$(cat "$DIR/proxy.pid")" 2>/dev/null && ok "LiteLLM proxy stopped" || true
fi

# Shell block
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && grep -q '# >>> bedrock-agents >>>' "$rc"; then
    python3 -I - "$rc" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = re.sub(r"\n*# >>> bedrock-agents >>>.*?# <<< bedrock-agents <<<\n?", "\n", t, flags=re.S)
open(p, "w", encoding="utf-8").write(t)
PY
    ok "$rc: bedrock-agents block removed"
  fi
done

# Key
if [[ "$(uname)" == "Darwin" ]] && /usr/bin/security delete-generic-password -s "$SERVICE" -a "$ACCOUNT" >/dev/null 2>&1; then
  ok "Keychain: key removed"
elif command -v secret-tool >/dev/null && secret-tool clear app bedrock-agents 2>/dev/null; then
  ok "secret-tool: key removed"
fi

rm -rf "$DIR" && ok "$DIR removed"
info "Claude Code's separate dir (~/.claude-bedrock) keeps session history; delete it by hand if you want."
info "LiteLLM stays installed; remove it with: uv tool uninstall litellm"
info "The Bedrock API key itself is still valid. Revoke it in the Bedrock console if you no longer need it."
info "Open a new terminal."
