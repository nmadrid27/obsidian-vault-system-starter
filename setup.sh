#!/usr/bin/env bash
#
# setup.sh: wire this starter vault to a vault-system-mcp install.
#
# What it does (all safe, idempotent, non-destructive):
#   1. Copies the vault/ skeleton into your chosen vault root (skips files that
#      already exist; never overwrites your content).
#   2. Generates three API keys and writes them to ~/.claude_vault_*key (0600).
#   3. Renders config/api-keys.yaml into your vault-system-mcp checkout (0600),
#      with the real keys and your owner username.
#   4. Renders <vault-root>/.mcp.json with the owner key inline (0600).
#   5. Prints the manual steps it will NOT do for you (editing global settings,
#      running the server install), because those touch files outside this repo.
#
# It does NOT build or start the server. Build it first from
# docs/BUILD-THE-SERVER.md (into ./server), or point --mcp-dir at an existing
# vault-system-mcp checkout. Run this after the server exists.
#
# Usage:
#   ./setup.sh --mcp-dir ~/Developer/vault-system-mcp [--vault ~/Obsidian] [--owner $USER] [--force]

set -euo pipefail

VAULT_ROOT="$HOME/Obsidian"
OWNER="$USER"
MCP_DIR=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)   VAULT_ROOT="$2"; shift 2 ;;
    --owner)   OWNER="$2"; shift 2 ;;
    --mcp-dir) MCP_DIR="$2"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[31mABORT\033[0m %s\n' "$*" >&2; exit 1; }

[[ -n "$MCP_DIR" ]] || die "pass --mcp-dir pointing at your vault-system-mcp checkout"
[[ -d "$MCP_DIR" ]] || die "--mcp-dir does not exist: $MCP_DIR"
[[ -f "$MCP_DIR/server.py" ]] || warn "no server.py in $MCP_DIR; is that really the vault-system-mcp checkout?"

command -v openssl >/dev/null || die "openssl is required to generate keys"

echo "Wiring starter vault"
say "vault root : $VAULT_ROOT"
say "owner      : $OWNER"
say "mcp dir    : $MCP_DIR"
echo

# 1. Copy the skeleton into the vault root, never clobbering existing files.
mkdir -p "$VAULT_ROOT"
# -R recurse, -n no-clobber (BSD/macOS and GNU both accept -n). No clobbering
# fallback: if -n is somehow unsupported, fail loudly rather than overwrite files.
cp -Rn "$HERE/vault/." "$VAULT_ROOT/"
ok "skeleton copied into $VAULT_ROOT (existing files left untouched)"

# 2. Generate keys (only if missing, unless --force).
gen_key() {
  local path="$1"
  if [[ -f "$path" && "$FORCE" -eq 0 ]]; then
    warn "$(basename "$path") exists; keeping it (use --force to regenerate)"
  else
    openssl rand -hex 32 > "$path"
    chmod 600 "$path"
    ok "generated $(basename "$path")"
  fi
}
gen_key "$HOME/.claude_vault_key"
gen_key "$HOME/.claude_vault_cron_key"
gen_key "$HOME/.claude_vault_weekly_key"

OWNER_KEY="$(cat "$HOME/.claude_vault_key")"
CRON_KEY="$(cat "$HOME/.claude_vault_cron_key")"
WEEKLY_KEY="$(cat "$HOME/.claude_vault_weekly_key")"

# 3. Render api-keys.yaml into the mcp checkout.
API_KEYS_OUT="$MCP_DIR/config/api-keys.yaml"
mkdir -p "$MCP_DIR/config"
if [[ -f "$API_KEYS_OUT" && "$FORCE" -eq 0 ]]; then
  warn "config/api-keys.yaml exists in mcp dir; not overwriting (use --force)"
else
  sed -e "s|<owner-username>|$OWNER|g" \
      -e "s|REPLACE_WITH_OWNER_KEY|$OWNER_KEY|g" \
      -e "s|REPLACE_WITH_CRON_KEY|$CRON_KEY|g" \
      -e "s|REPLACE_WITH_WEEKLY_KEY|$WEEKLY_KEY|g" \
      "$HERE/config/api-keys.example.yaml" > "$API_KEYS_OUT"
  chmod 600 "$API_KEYS_OUT"
  ok "rendered $API_KEYS_OUT (0600)"
fi

# 4. Render the project-scoped .mcp.json into the vault root.
MCP_JSON_OUT="$VAULT_ROOT/.mcp.json"
if [[ -f "$MCP_JSON_OUT" && "$FORCE" -eq 0 ]]; then
  warn ".mcp.json exists in vault root; not overwriting (use --force)"
else
  sed -e "s|REPLACE_WITH_OWNER_KEY|$OWNER_KEY|g" \
      "$HERE/mcp/mcp.json.template" > "$MCP_JSON_OUT"
  chmod 600 "$MCP_JSON_OUT"
  ok "rendered $MCP_JSON_OUT (0600)"
fi

# 5. Manual steps we deliberately do not automate.
cat <<EOF

Next, do these by hand (they touch files outside this repo):

  a. Edit your domain ontology:
     copy the three structures from $HERE/config/domains.example.py
     into $MCP_DIR/config.py, replacing DOMAIN_PREFIXES, PROSE_DOMAINS, CODE_DOMAINS.

  b. Add the deny rules from $HERE/mcp/settings.local.json.snippet
     into ~/.claude/settings.local.json (merge the "permissions.deny" list).
     Adjust the globs to match your prose domains.

  c. Start the server on 127.0.0.1:8765.
     Built from docs/BUILD-THE-SERVER.md:   python "$MCP_DIR/server.py"
     A vault-system-mcp checkout instead:   cd "$MCP_DIR" && bash install.sh --vault "$VAULT_ROOT"
     Confirm it is up:                       curl -s http://127.0.0.1:8765/health

  d. Open $VAULT_ROOT in Obsidian, then start a session:
     cd "$VAULT_ROOT" && claude

Keys live at ~/.claude_vault_key, ~/.claude_vault_cron_key, ~/.claude_vault_weekly_key.
They are mode 0600 and must never be synced or committed.
EOF
echo
ok "wiring complete"
