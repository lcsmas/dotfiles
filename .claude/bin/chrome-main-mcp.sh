#!/usr/bin/env bash
# chrome-devtools-mcp attached to the user's MAIN Chromium (default profile, real logins).
# Prereq, once per browser session: chrome://inspect/#remote-debugging → enable (Chromium 144+),
# which writes DevToolsActivePort. Use only when the user asks; E2E stays on `chrome-devtools`.
set -euo pipefail

PROFILE="${CHROME_MAIN_USER_DATA_DIR:-$HOME/.config/chromium}"

if [ "${1:-}" = "--serve" ]; then
  f="$PROFILE/DevToolsActivePort"
  if [ ! -r "$f" ]; then
    echo "chrome-main: $f missing — enable chrome://inspect/#remote-debugging in your main Chromium" >&2
    exit 1
  fi
  port=$(sed -n 1p "$f"); path=$(sed -n 2p "$f")
  exec npx -y --prefer-offline chrome-devtools-mcp@1.10.1 --no-usage-statistics --no-performance-crux --wsEndpoint "ws://127.0.0.1:${port}${path}"
fi

# Lazy: the endpoint is read at first tool call, not at agent start.
exec /usr/bin/node "$(dirname "$(readlink -f "$0")")/lazy-mcp.mjs" -- "$(readlink -f "$0")" --serve
