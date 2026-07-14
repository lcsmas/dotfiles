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

# Path to the Chrome/Chromium binary. chrome-devtools-mcp otherwise looks for
# Google Chrome at /opt/google/chrome/chrome, which isn't installed here; point
# it at the system Chromium. Override via CHROME_DEVTOOLS_MCP_EXECUTABLE.
EXECUTABLE_PATH="${CHROME_DEVTOOLS_MCP_EXECUTABLE:-/usr/lib64/chromium-browser/chromium-browser}"

mkdir -p "$USER_DATA_DIR"

exec npx chrome-devtools-mcp@latest \
  --headless=false \
  --executablePath="$EXECUTABLE_PATH" \
  --userDataDir="$USER_DATA_DIR" \
  --ignoreDefaultChromeArg=--enable-automation \
  --ignoreDefaultChromeArg=--disable-extensions \
  "$@"
