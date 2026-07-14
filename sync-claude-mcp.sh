#!/bin/bash

# Sync the curated mcpServers block from the dotfiles copy of .claude.json
# into the live ~/.claude.json that Claude Code reads and writes at runtime.
#
# Why this exists: ~/.claude.json is NOT symlinked to the dotfiles copy on
# purpose -- Claude Code writes runtime state (history, projects, oauthAccount,
# approval flags) into it, which would produce noisy diffs and risk committing
# secrets if it were a tracked symlink. So the dotfiles copy is the source of
# truth for mcpServers only; this script merges that one block in and leaves
# all runtime state in the live file untouched.
#
# Usage:
#   ./sync-claude-mcp.sh            apply the merge (backs up the live file first)
#   ./sync-claude-mcp.sh --dry-run  print what would change, write nothing
#   ./sync-claude-mcp.sh --diff     same as --dry-run, shows a per-server diff

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/.claude/.claude.json"
LIVE="$HOME/.claude.json"

DRY_RUN=false
SHOW_DIFF=false
case "${1:-}" in
  --dry-run) DRY_RUN=true ;;
  --diff)    DRY_RUN=true; SHOW_DIFF=true ;;
  "")        ;;
  *) echo "Unknown option: $1" >&2; echo "Usage: $0 [--dry-run|--diff]" >&2; exit 2 ;;
esac

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed." >&2; exit 1; }
[ -f "$SOURCE" ] || { echo "Error: source not found: $SOURCE" >&2; exit 1; }
[ -f "$LIVE" ]   || { echo "Error: live config not found: $LIVE" >&2; exit 1; }

jq empty "$SOURCE" 2>/dev/null || { echo "Error: $SOURCE is not valid JSON." >&2; exit 1; }
jq empty "$LIVE"   2>/dev/null || { echo "Error: $LIVE is not valid JSON." >&2; exit 1; }

if jq -e '.mcpServers' "$SOURCE" >/dev/null 2>&1; then :; else
  echo "Error: $SOURCE has no .mcpServers block." >&2; exit 1
fi

# Report which servers will be added or changed.
added=$(jq -r --slurpfile live "$LIVE" \
  '.mcpServers | keys - ($live[0].mcpServers // {} | keys) | .[]' "$SOURCE")
changed=$(jq -r --slurpfile live "$LIVE" '
  .mcpServers as $src | ($live[0].mcpServers // {}) as $cur
  | $src | keys[] | select(($cur[.] // null) != $src[.])
  | select((($cur[.] // null)) != null)' "$SOURCE")

echo "Source : $SOURCE"
echo "Live   : $LIVE"
echo
if [ -z "$added" ] && [ -z "$changed" ]; then
  echo "mcpServers already in sync -- nothing to do."
  exit 0
fi
[ -n "$added" ]   && { echo "Servers to ADD:";    echo "$added"   | sed 's/^/  + /'; }
[ -n "$changed" ] && { echo "Servers to UPDATE:"; echo "$changed" | sed 's/^/  ~ /'; }

if $SHOW_DIFF; then
  echo
  echo "=== Per-server diff (live -> source) ==="
  for s in $changed; do
    echo "--- $s ---"
    diff <(jq -S ".mcpServers[\"$s\"]" "$LIVE") \
         <(jq -S ".mcpServers[\"$s\"]" "$SOURCE") || true
  done
fi

if $DRY_RUN; then
  echo
  echo "(dry run -- no changes written)"
  exit 0
fi

BACKUP="$LIVE.bak.$(date +%Y%m%d-%H%M%S)"
cp "$LIVE" "$BACKUP"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
jq --slurpfile src "$SOURCE" '.mcpServers = $src[0].mcpServers' "$LIVE" > "$TMP"
jq empty "$TMP"   # validate before swapping in
mv "$TMP" "$LIVE"
trap - EXIT

echo
echo "Merged mcpServers into $LIVE"
echo "Backup written to $BACKUP"
echo "Reconnect MCP servers in Claude Code (/mcp) or restart for changes to take effect."
