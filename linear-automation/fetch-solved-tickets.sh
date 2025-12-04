#!/bin/bash

# Load environment variables
if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
fi

# Check if LINEAR_API_KEY is set
if [ -z "$LINEAR_API_KEY" ]; then
    echo "Error: LINEAR_API_KEY not set. Please create a .env file with your Linear API key."
    echo "See .env.example for reference."
    exit 1
fi

SCRIPT_DIR="$(dirname "$0")"
OUTPUT_FILE="$SCRIPT_DIR/solved-tickets-database.json"
METADATA_FILE="$SCRIPT_DIR/.last-sync.json"

# Parse command-line arguments
FULL_SYNC=false
if [ "$1" = "--full" ]; then
    FULL_SYNC=true
    echo "Running FULL sync - fetching all solved tickets..."
else
    echo "Running incremental sync - fetching only new/updated tickets..."
fi

# Get last sync timestamp for incremental updates
LAST_SYNC_DATE=""
if [ "$FULL_SYNC" = false ] && [ -f "$METADATA_FILE" ]; then
    LAST_SYNC_DATE=$(jq -r '.lastSyncDate // ""' "$METADATA_FILE")
    if [ -n "$LAST_SYNC_DATE" ]; then
        echo "Last sync: $LAST_SYNC_DATE"
    fi
fi

# Function to fetch a page of tickets
fetch_page() {
    local AFTER_CURSOR="$1"
    local UPDATED_AT_FILTER=""

    # Add timestamp filter for incremental sync
    if [ -n "$LAST_SYNC_DATE" ]; then
        UPDATED_AT_FILTER=", updatedAt: { gte: \"$LAST_SYNC_DATE\" }"
    fi

    # Build the after cursor argument
    local AFTER_ARG=""
    if [ -n "$AFTER_CURSOR" ]; then
        AFTER_ARG=", after: \"$AFTER_CURSOR\""
    fi

    # GraphQL query with pagination
    local QUERY=$(cat <<EOF
{
  issues(
    filter: {
      state: { name: { in: ["Done", "Completed", "Canceled"] }}
      labels: { name: { in: ["Other", "B2C", "B2B Cleaq", "B2B Mobile Club"] }}
      ${UPDATED_AT_FILTER}
    },
    first: 50${AFTER_ARG},
    orderBy: updatedAt
  ) {
    pageInfo {
      hasNextPage
      endCursor
    }
    nodes {
      id
      identifier
      title
      description
      url
      priority
      createdAt
      updatedAt
      completedAt
      state {
        name
      }
      assignee {
        name
        email
      }
      labels {
        nodes {
          name
        }
      }
      comments {
        nodes {
          id
          body
          createdAt
          updatedAt
          user {
            name
            email
          }
          externalUser {
            name
            email
          }
          botActor {
            name
            type
          }
        }
      }
    }
  }
}
EOF
)

    # Make the API request
    curl -s -X POST https://api.linear.app/graphql \
      -H "Content-Type: application/json" \
      -H "Authorization: $LINEAR_API_KEY" \
      -d "{\"query\": $(echo "$QUERY" | jq -Rs .)}"
}

# Fetch all pages
echo "Fetching solved HelpTech tickets from Linear..."
TEMP_FILE="$SCRIPT_DIR/.tmp-tickets.json"
echo "[]" > "$TEMP_FILE"

PAGE_NUM=1
HAS_NEXT_PAGE=true
END_CURSOR=""

while [ "$HAS_NEXT_PAGE" = true ]; do
    echo "  Fetching page $PAGE_NUM..."

    RESPONSE=$(fetch_page "$END_CURSOR")

    # Check for errors
    if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
        echo "Error fetching tickets from Linear:"
        echo "$RESPONSE" | jq '.errors'
        rm -f "$TEMP_FILE"
        exit 1
    fi

    # Extract page info
    HAS_NEXT_PAGE=$(echo "$RESPONSE" | jq -r '.data.issues.pageInfo.hasNextPage')
    END_CURSOR=$(echo "$RESPONSE" | jq -r '.data.issues.pageInfo.endCursor')

    # Extract tickets from this page and save to temp file
    echo "$RESPONSE" | jq '.data.issues.nodes' > "$SCRIPT_DIR/.tmp-page.json"
    PAGE_COUNT=$(jq 'length' "$SCRIPT_DIR/.tmp-page.json")

    if [ "$PAGE_COUNT" -gt 0 ]; then
        # Append to temp file (avoid argument list too long)
        jq -s '.[0] + .[1]' "$TEMP_FILE" "$SCRIPT_DIR/.tmp-page.json" > "$TEMP_FILE.new" && mv "$TEMP_FILE.new" "$TEMP_FILE"
        echo "    ✓ Fetched $PAGE_COUNT tickets"
    else
        echo "    ✓ No more tickets"
        rm -f "$SCRIPT_DIR/.tmp-page.json"
        break
    fi

    PAGE_NUM=$((PAGE_NUM + 1))

    # Safety check: stop if hasNextPage is false or null
    if [ "$HAS_NEXT_PAGE" != "true" ]; then
        break
    fi

    # Rate limiting: small delay between requests
    sleep 0.5
done

# Clean up temp page file
rm -f "$SCRIPT_DIR/.tmp-page.json"

# Merge with existing database if doing incremental sync
if [ "$FULL_SYNC" = false ] && [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "Merging with existing database..."

    # Merge using temp files to avoid argument list too long
    jq '.data.issues.nodes' "$OUTPUT_FILE" > "$SCRIPT_DIR/.tmp-existing.json"
    jq -s '.[0] + .[1] | unique_by(.id) | sort_by(.updatedAt) | reverse' \
        "$SCRIPT_DIR/.tmp-existing.json" "$TEMP_FILE" > "$SCRIPT_DIR/.tmp-merged.json"
    mv "$SCRIPT_DIR/.tmp-merged.json" "$TEMP_FILE"
    rm -f "$SCRIPT_DIR/.tmp-existing.json"
fi

# Save to file with proper structure
jq '{"data": {"issues": {"nodes": .}}}' "$TEMP_FILE" > "$OUTPUT_FILE"

# Update metadata with current timestamp
CURRENT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
echo "{\"lastSyncDate\": \"$CURRENT_TIMESTAMP\"}" > "$METADATA_FILE"

# Count tickets and comments (from file, not variable)
TOTAL_TICKETS=$(jq '.data.issues.nodes | length' "$OUTPUT_FILE")
TOTAL_COMMENTS=$(jq '[.data.issues.nodes[].comments.nodes | length] | add // 0' "$OUTPUT_FILE")

echo ""
echo "════════════════════════════════════════"
echo "✓ Successfully fetched $TOTAL_TICKETS solved HelpTech tickets"
echo "✓ Total comments captured: $TOTAL_COMMENTS"
echo "✓ Saved to: $OUTPUT_FILE"
echo "✓ Last sync timestamp: $CURRENT_TIMESTAMP"
echo "════════════════════════════════════════"

# Display summary by label
echo ""
echo "Tickets by label:"
jq -r '.data.issues.nodes | group_by(.labels.nodes[0].name)
  | map({label: .[0].labels.nodes[0].name, count: length})
  | .[]
  | "  \(.label): \(.count)"' "$OUTPUT_FILE"

# Display most recently updated tickets
echo ""
echo "Most recently updated tickets:"
jq -r '.data.issues.nodes | sort_by(.updatedAt)
  | reverse
  | .[:5]
  | .[]
  | "  [\(.identifier)] \(.title) - \(.state.name) (\(.updatedAt | split("T")[0]))"' "$OUTPUT_FILE"

# Clean up temp file
rm -f "$TEMP_FILE"

echo ""
echo "💡 Tip: Use './fetch-solved-tickets.sh --full' to fetch all tickets from scratch"
