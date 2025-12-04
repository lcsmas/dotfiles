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

# GraphQL query to fetch triage tickets
QUERY='
{
  issues(filter: { state: { name: { in: ["Triage", "In Progress"] }} labels : { name : { in: ["Other", "B2C", "B2B Cleaq", "B2B Mobile Club"] }}}, first: 50) {
    nodes {
      id
      identifier
      title
      assignee {
        name
      }
      description
      url
      priority
      state {
        name
      }
      labels {
        nodes {
          name
        }
      }
    }
  }
}
'

# Make the API request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_KEY" \
  -d "{\"query\": $(echo "$QUERY" | jq -Rs .)}")

# Check if the request was successful
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo "Error fetching tickets from Linear:"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

# Sort by state name client-side (Triage before In Progress)
SORTED_RESPONSE=$(echo "$RESPONSE" | jq '.data.issues.nodes |= sort_by(.state.name) | .data.issues.nodes |= reverse')

# Save to file
OUTPUT_FILE="$(dirname "$0")/helptech-tickets.json"
echo "$SORTED_RESPONSE" | jq '.' > "$OUTPUT_FILE"

# Count tickets
TICKET_COUNT=$(echo "$SORTED_RESPONSE" | jq '.data.issues.nodes | length')

echo "✓ Successfully fetched $TICKET_COUNT helptech tickets"
echo "✓ Saved to: $OUTPUT_FILE"

# Display summary
echo ""
echo "Tickets:"
echo "$SORTED_RESPONSE" | jq -r '.data.issues.nodes[] | "  \(.state.name) - [\(.identifier)] \(.title)"' 
