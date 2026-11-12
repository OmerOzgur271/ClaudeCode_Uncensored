"""Switch the Claude Code panel in Cursor between Bedrock (via the local proxy) and your normal setup.

Usage: cursor_toggle.py on | off | status [--settings PATH]
  on      back up Cursor settings, save your current claudeCode.environmentVariables,
          replace them with the Bedrock proxy variables, and run the proxy as a login service (macOS)
  off     restore exactly what was there before `on` and remove the login service
  status  show which mode is active
  --settings PATH  use another settings.json, e.g. a Cursor profile's, instead of the default one

Reads the variables from ~/.config/bedrock-agents/claude-env.sh (written by install.sh).
Reload the Cursor window afterwards (Cmd+Shift+P > Developer: Reload Window).
"""
import json
import os
import shlex
import shutil
import subprocess
import sys
import time

DIR = os.path.expanduser("~/.config/bedrock-agents")
ENV_FILE = os.path.join(DIR, "claude-env.sh")
STATE = os.path.join(DIR, "cursor-state.json")
PLIST = os.path.expanduser("~/Library/LaunchAgents/com.bedrock-agents.proxy.plist")
LABEL = "com.bedrock-agents.proxy"
EV, LOGIN = "claudeCode.environmentVariables", "claudeCode.disableLoginPrompt"
# Variables that would send requests elsewhere or conflict with the proxy token
CONFLICTS = {"ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
             "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"}


def read_env():
    """Parse the `export NAME=value` lines of claude-env.sh."""
    env = {}
    for line in open(ENV_FILE, encoding="utf-8"):
        parts = shlex.split(line, comments=True)
        if len(parts) == 2 and parts[0] == "export" and "=" in parts[1]:
            k, v = parts[1].split("=", 1)
            env[k] = v
    return env


def default_settings():
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/Cursor/User/settings.json")
    return os.path.expanduser("~/.config/Cursor/User/settings.json")


def strip_jsonc(text):
    """Remove // and /* */ comments and trailing commas, leaving string contents alone."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        elif c in "}]":
            j = len(out) - 1
            while j >= 0 and out[j] in " \t\r\n":
                j -= 1
            if j >= 0 and out[j] == ",":
                del out[j]
            out.append(c)
        else:
            out.append(c)
        i += 1
    return "".join(out)


def load(path):
    if not os.path.exists(path):
        return {}, False
    text = open(path, encoding="utf-8").read()
    if not text.strip():
        return {}, False
    try:
        return json.loads(text), False
    except json.JSONDecodeError:
        return json.loads(strip_jsonc(text)), True


def save(path, data, had_comments):
    if os.path.exists(path):
        backup = f"{path}.bedrock-backup-{time.strftime('%Y%m%d-%H%M%S')}"
        shutil.copy2(path, backup)
        print(f"  backup: {backup}")
        if had_comments:
            print("  note: comments in settings.json were removed; the backup keeps them")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)
        f.write("\n")


def write_private(path, data):
    mask = os.umask(0o077)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.umask(mask)
    os.chmod(path, 0o600)


def service_on():
    """Keep the proxy running in the background so the Cursor panel always finds it."""
    if sys.platform != "darwin":
        print("  Linux: start the proxy before opening Cursor with: bedrock-proxy-up")
        return
    # Stop a proxy started by claude-bedrock, or the service could not bind the port
    pid_file = os.path.join(DIR, "proxy.pid")
    if os.path.exists(pid_file):
        try:
            os.kill(int(open(pid_file).read().strip()), 15)
        except (ValueError, ProcessLookupError, PermissionError):
            pass
        os.remove(pid_file)
        time.sleep(1)
    os.makedirs(os.path.dirname(PLIST), exist_ok=True)
    log = os.path.join(DIR, "proxy.log")
    with open(PLIST, "w", encoding="utf-8") as f:
        f.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>{LABEL}</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>{DIR}/proxy.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>{log}</string>
  <key>StandardErrorPath</key><string>{log}</string>
</dict></plist>
""")
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", domain, PLIST], capture_output=True)
    r = subprocess.run(["launchctl", "bootstrap", domain, PLIST], capture_output=True, text=True)
    if r.returncode == 0:
        print("  proxy runs as a login service (com.bedrock-agents.proxy)")
    else:
        print(f"  could not start the login service: {r.stderr.strip()}. Run bedrock-proxy-up instead.")


def service_off():
    if os.path.exists(PLIST):
        subprocess.run(["launchctl", "bootout", f"gui/{os.getuid()}", PLIST], capture_output=True)
        os.remove(PLIST)
        print("  login service removed")


def main():
    args = sys.argv[1:]
    path = default_settings()
    if "--settings" in args:
        i = args.index("--settings")
        path = os.path.expanduser(args[i + 1])
        del args[i:i + 2]
    cmd = args[0] if args else "status"
    active = os.path.exists(STATE)

    if cmd == "status":
        if active:
            where = json.load(open(STATE, encoding="utf-8")).get("path", path)
            print(f"Cursor Claude Code panel: Bedrock (settings: {where})")
        else:
            print("Cursor Claude Code panel: normal setup")
        return 0

    if cmd == "on":
        ours = read_env()  # {name: value}
        if active:
            path = json.load(open(STATE, encoding="utf-8")).get("path", path)
        data, had_comments = load(path)
        current = data.get(EV, [])
        if not isinstance(current, list):
            print(f"  {EV} is not a list; fix it by hand"); return 1
        if not active:
            # Saved so `off` can put it back exactly. May contain your Anthropic key, so mode 600.
            write_private(STATE, {"path": path, "env": current,
                                  "login_present": LOGIN in data, "login": data.get(LOGIN)})
            prev = current
        else:
            prev = json.load(open(STATE, encoding="utf-8"))["env"]
        keep = [e for e in prev if isinstance(e, dict) and e.get("name") not in CONFLICTS | set(ours)]
        data[EV] = keep + [{"name": k, "value": v} for k, v in ours.items()]
        data[LOGIN] = True
        save(path, data, had_comments)
        service_on()
        print("  Claude Code panel now uses Bedrock. Cmd+Shift+P > Developer: Reload Window, then open a new Claude chat.")
        return 0

    if cmd == "off":
        if not active:
            service_off()
            print("  Already on the normal setup."); return 0
        state = json.load(open(STATE, encoding="utf-8"))
        path = state.get("path", path)
        data, had_comments = load(path)
        data[EV] = state["env"]
        if state["login_present"]:
            data[LOGIN] = state["login"]
        else:
            data.pop(LOGIN, None)
        save(path, data, had_comments)
        os.remove(STATE)
        service_off()
        print("  Claude Code panel restored to your normal setup. Cmd+Shift+P > Developer: Reload Window.")
        return 0

    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main())
