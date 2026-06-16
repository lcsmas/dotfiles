#!/usr/bin/env bash
# chrome-devtools-mcp launcher.
#
# This wrapper is used only when debugging an Electron (or any Chromium) app
# exposed over the Chrome DevTools Protocol. It polls localhost:9222 until a
# CDP endpoint appears, then attaches the MCP to it via --browserUrl. There
# is intentionally no headless fallback: when the port is not listening, the
# MCP is simply not started yet — it comes online the moment the app does.
#
# Override the port via CHROME_DEVTOOLS_MCP_PORT.

set -euo pipefail

PORT="${CHROME_DEVTOOLS_MCP_PORT:-9222}"

probe() {
  curl -sSf --max-time 0.5 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1
}

while ! probe; do
  sleep 1
done

exec npx chrome-devtools-mcp@latest \
  --browserUrl "http://127.0.0.1:${PORT}" \
  "$@"
