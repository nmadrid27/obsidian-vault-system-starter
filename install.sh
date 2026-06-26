#!/usr/bin/env bash
#
# install.sh: bootstrap installer for obsidian-vault-system-starter.
#
# The repo is public, so you can pipe this straight from GitHub (no auth needed):
#
#   curl -fsSL https://raw.githubusercontent.com/nmadrid27/obsidian-vault-system-starter/main/install.sh | bash
#
# Pass setup.sh arguments through to clone AND wire in one shot:
#
#   ... | bash -s -- --mcp-dir ~/path/to/vault-system-mcp --vault ~/Obsidian
#
# Or, after cloning, run it directly:
#
#   ./install.sh [setup.sh args]
#
# It clones the repo (when piped) and hands off to setup.sh. It does NOT build the
# MCP server: build it from docs/BUILD-THE-SERVER.md (or point setup.sh --mcp-dir
# at an existing vault-system-mcp checkout).

set -euo pipefail

REPO="nmadrid27/obsidian-vault-system-starter"
CLONE_DIR="${VAULT_STARTER_DIR:-$HOME/obsidian-vault-system-starter}"

have() { command -v "$1" >/dev/null 2>&1; }

# If setup.sh sits next to this script, we are running from a real checkout.
SELF_DIR=""
src="${BASH_SOURCE[0]:-}"
if [[ -n "$src" && -f "$src" ]]; then
  SELF_DIR="$(cd "$(dirname "$src")" && pwd)"
fi

if [[ -n "$SELF_DIR" && -f "$SELF_DIR/setup.sh" ]]; then
  TARGET="$SELF_DIR"
else
  # Piped or standalone: clone the public repo. Plain git needs no auth; fall
  # back to gh if git is unavailable.
  if [[ -d "$CLONE_DIR/.git" ]]; then
    echo "Updating existing checkout at $CLONE_DIR"
    git -C "$CLONE_DIR" pull --ff-only || echo "  (pull skipped; resolve manually if needed)"
  elif have git; then
    echo "Cloning $REPO into $CLONE_DIR"
    git clone "https://github.com/$REPO.git" "$CLONE_DIR"
  elif have gh; then
    echo "Cloning $REPO into $CLONE_DIR (via gh)"
    gh repo clone "$REPO" "$CLONE_DIR"
  else
    echo "ERROR: need git (or gh) to clone $REPO. See https://git-scm.com or https://cli.github.com" >&2
    exit 1
  fi
  TARGET="$CLONE_DIR"
fi

# No setup args: stop after clone and print the wiring step.
if [[ $# -eq 0 ]]; then
  cat <<EOF

Ready at: $TARGET

Next: build the MCP server from the spec, then wire it.

  cd "$TARGET"
  # 1. Edit config/domains.example.py to define your domains.
  # 2. In Claude Code, hand it docs/BUILD-THE-SERVER.md; it builds ./server.
  # 3. ./setup.sh --mcp-dir ./server --vault ~/Obsidian --owner "\$USER"

Already have a vault-system-mcp checkout? Point --mcp-dir at it instead of ./server,
or re-run this installer with those setup.sh args appended to do it in one shot.
EOF
  exit 0
fi

echo "Handing off to setup.sh $*"
exec bash "$TARGET/setup.sh" "$@"
