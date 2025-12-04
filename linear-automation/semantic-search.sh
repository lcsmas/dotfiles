#!/bin/bash
# Semantic search wrapper for HelpTech tickets

SCRIPT_DIR="$(dirname "$0")"
INDEX_FILE="$SCRIPT_DIR/solved-tickets.index"
BUILD_SCRIPT="$SCRIPT_DIR/build-semantic-index.py"
SEARCH_SCRIPT="$SCRIPT_DIR/semantic-search.py"

# Check if index exists
if [ ! -f "$INDEX_FILE" ]; then
    echo "Building semantic index (first time only, ~30 seconds)..." >&2
    python3 "$BUILD_SCRIPT" || exit 1
fi

# Run search
python3 "$SEARCH_SCRIPT" "$@"
