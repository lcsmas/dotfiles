#!/usr/bin/env bash
# chrome-devtools-mcp launcher for a real, visible Chrome window with a
# persistent dedicated profile (so it can run in parallel with the user's
# main Chrome).
#
# Note on extensions: Puppeteer-launched Chrome silently drops
# --load-extension under --enable-automation, so we don't try to inject the
# user's extensions via flags. Install once via the Chrome Web Store inside
# the persistent profile at $HOME/.config/chrome-devtools-mcp-profile and
# they'll be available across sessions.
#
# Override the user-data-dir via CHROME_DEVTOOLS_MCP_USER_DATA_DIR.

set -euo pipefail

USER_DATA_DIR="${CHROME_DEVTOOLS_MCP_USER_DATA_DIR:-$HOME/.config/chrome-devtools-mcp-profile}"

mkdir -p "$USER_DATA_DIR"

exec npx chrome-devtools-mcp@latest \
  --headless=false \
  --userDataDir="$USER_DATA_DIR" \
  --ignoreDefaultChromeArg=--enable-automation \
  --ignoreDefaultChromeArg=--disable-extensions \
  "$@"
