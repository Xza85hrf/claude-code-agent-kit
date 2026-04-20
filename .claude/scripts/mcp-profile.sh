#!/bin/bash
# mcp-profile.sh — Switch MCP server profiles to manage context budget
# Usage: bash .claude/scripts/mcp-profile.sh [profile|+server|-server|status]
#
# Profiles: minimal | code | design | full
# Toggle:   +gemini (enable), -gemini (disable)
#
# Always-on core: openai, sequential-thinking, groq (3 MCP servers)
# CLI-backed (removed from ~/.claude.json, use mcp-cli.sh): ollama, deepseek, firecrawl
# Redundant (removed from ~/.claude.json): github, memory, cclsp, vscode-mcp
# On-demand: claude-ide-bridge, gemini, free-models, stitch, 21st-dev-magic, animate-ui, vscode-debug, openspace, reactbits, pinchtab, browser-use, windows-mcp

set -euo pipefail

CONFIG_FILE="$HOME/.claude.json"
ARG="${1:-status}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found"
  exit 1
fi

# Server tiers (only servers present in ~/.claude.json)
ALWAYS_ON='["openai","sequential-thinking","groq"]'
ON_DEMAND='["claude-ide-bridge","gemini","free-models","stitch","21st-dev-magic","animate-ui","vscode-debug","openspace","reactbits","pinchtab","browser-use","windows-mcp","code-review-graph"]'
# CLI-backed (ollama, deepseek, firecrawl) and redundant (github, memory, cclsp, vscode-mcp)
# are REMOVED from ~/.claude.json entirely — not just disabled. Backup: ~/.claude-mcp-removed.json

show_status() {
  echo "=== MCP Profile Status ==="
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
import os
servers = data.get('mcpServers', {})
core = ['openai','sequential-thinking','groq']
on_demand = ['claude-ide-bridge','gemini','free-models','stitch','21st-dev-magic','animate-ui','vscode-debug','openspace','reactbits','pinchtab','browser-use','windows-mcp','code-review-graph']
backup_path = os.path.expanduser('~/.claude-mcp-ondemand-backup.json')
backup_names = []
if os.path.exists(backup_path):
    with open(backup_path) as bf:
        backup_names = list(json.load(bf).get('mcpServers', {}).keys())
print('Core MCP (always-on):')
for n in core:
    s = 'ON' if n in servers and not servers[n].get('disabled',False) else 'OFF'
    print(f'  {s:3s}  {n}')
active_od = [n for n in on_demand if n in servers and not servers[n].get('disabled',False)]
backed_up = [n for n in on_demand if n not in servers and n in backup_names]
if active_od:
    print('On-demand (loaded):')
    for n in active_od:
        print(f'  ON   {n}')
if backed_up:
    print(f'On-demand (removed, restorable via +name): {len(backed_up)}')
    for n in backed_up:
        print(f'  ---  {n}')
print('CLI-backed (zero context tokens):')
for n in ['ollama','deepseek','firecrawl']:
    print(f'  CLI  {n}')
total = sum(1 for v in servers.values() if not v.get('disabled',False))
print(f'\nIn config: {len(servers)} | Enabled: {total} | Backed up: {len(backed_up)} | CLI: 3')
print('External: Docker Gateway (github, playwright, memory), plugins (context7)')
"
  echo ""
  echo "Profiles: minimal | code | design | full"
  echo "Toggle:   +server | -server  (e.g. +gemini, -free-models)"
}

set_servers() {
  local enabled_json="$1"
  local disabled_json="$2"
  python3 -c "
import json, os, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
enabled = json.loads('$enabled_json')
disabled = json.loads('$disabled_json')
servers = data.get('mcpServers', {})
backup_path = os.path.expanduser('~/.claude-mcp-ondemand-backup.json')
backup = {}
if os.path.exists(backup_path):
    with open(backup_path) as bf:
        backup = json.load(bf).get('mcpServers', {})
for name in enabled:
    if name in servers:
        servers[name].pop('disabled', None)
    elif name in backup:
        servers[name] = backup[name]
        servers[name].pop('disabled', None)
for name in disabled:
    if name in servers:
        # Save to backup and remove (not just disable)
        backup[name] = servers.pop(name)
if backup:
    with open(backup_path, 'w') as bf:
        json.dump({'mcpServers': backup}, bf, indent=2)
        bf.write('\n')
with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
added = sum(1 for n in enabled if n in servers)
print(f'{added} enabled, {len(disabled)} removed')
"
}

# Toggle single server: +name or -name
BACKUP_FILE="$HOME/.claude-mcp-ondemand-backup.json"

if [[ "$ARG" == +* ]]; then
  SERVER="${ARG#+}"
  python3 -c "
import json, os, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
s = data.get('mcpServers', {})
if '$SERVER' in s:
    s['$SERVER'].pop('disabled', None)
    print('Enabled: $SERVER')
elif os.path.exists('$BACKUP_FILE'):
    with open('$BACKUP_FILE') as bf:
        backup = json.load(bf)
    if '$SERVER' in backup.get('mcpServers', {}):
        s['$SERVER'] = backup['mcpServers']['$SERVER']
        s['$SERVER'].pop('disabled', None)
        print('Restored and enabled: $SERVER (from backup)')
    else:
        print('ERROR: Unknown server: $SERVER')
        sys.exit(1)
else:
    print('ERROR: Unknown server: $SERVER (no backup file)')
    sys.exit(1)
with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
  echo "Run /mcp to reconnect."
  exit 0
fi

AUTO_MANAGED='ollama deepseek github memory'

if [[ "$ARG" == -* ]] && [[ "$ARG" != "-h" ]] && [[ "$ARG" != "--help" ]]; then
  SERVER="${ARG#-}"
  # Auto-managed servers can only be disabled, not removed
  if echo " $AUTO_MANAGED " | grep -q " $SERVER "; then
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
s = data.get('mcpServers', {})
if '$SERVER' in s:
    s['$SERVER']['disabled'] = True
with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('Disabled: $SERVER (auto-managed, cannot remove)')
"
  else
    python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    data = json.load(f)
s = data.get('mcpServers', {})
if '$SERVER' not in s:
    print('Already removed: $SERVER')
else:
    # Save to backup before removing
    backup_path = '$BACKUP_FILE'
    backup = {}
    if os.path.exists(backup_path):
        with open(backup_path) as bf:
            backup = json.load(bf)
    backup.setdefault('mcpServers', {})['$SERVER'] = s.pop('$SERVER')
    with open(backup_path, 'w') as bf:
        json.dump(backup, bf, indent=2)
        bf.write('\n')
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print('Removed: $SERVER (backed up for +$SERVER restore)')
"
  fi
  echo "Run /mcp to reconnect."
  exit 0
fi

case "$ARG" in
  minimal)
    set_servers '["openai","sequential-thinking","groq"]' '["claude-ide-bridge","gemini","free-models","stitch","21st-dev-magic","animate-ui","vscode-debug","openspace","reactbits","pinchtab","browser-use","windows-mcp"]'
    echo "Profile: MINIMAL — core only (3 MCP servers, lowest context)"
    ;;
  code)
    set_servers '["openai","sequential-thinking","groq","claude-ide-bridge","free-models"]' '["gemini","stitch","21st-dev-magic","animate-ui","vscode-debug","openspace","reactbits","pinchtab","browser-use","windows-mcp"]'
    echo "Profile: CODE — core + ide-bridge + free workers (5 servers)"
    ;;
  design)
    set_servers '["openai","sequential-thinking","groq","gemini","stitch","21st-dev-magic","animate-ui","reactbits"]' '["claude-ide-bridge","free-models","vscode-debug","openspace","pinchtab","browser-use","windows-mcp"]'
    echo "Profile: DESIGN — core + design pipeline (8 servers)"
    ;;
  full)
    set_servers '["openai","sequential-thinking","groq","claude-ide-bridge","gemini","free-models","stitch","21st-dev-magic","animate-ui","vscode-debug","openspace","reactbits","pinchtab","browser-use"]' '["windows-mcp"]'
    echo "Profile: FULL — all on-demand restored and enabled (14 servers)"
    ;;
  status)
    show_status
    exit 0
    ;;
  *)
    echo "Unknown: $ARG"
    echo "Profiles: minimal | code | design | full | status"
    echo "Toggle:   +server | -server"
    exit 1
    ;;
esac

echo ""
echo "Run /mcp to reconnect, or restart Claude Code for changes to take effect."
