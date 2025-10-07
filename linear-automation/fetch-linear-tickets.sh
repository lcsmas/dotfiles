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
  issues(filter: { state: { name: { eq: "Triage" }}}, first: 50) {
    nodes {
      id
      identifier
      title
      description
      url
      priority
      createdAt
      updatedAt
      state {
        name
      }
      team {
        name
      }
      assignee {
        name
        email
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

# Save to file
OUTPUT_FILE="$(dirname "$0")/triage-tickets.json"
echo "$RESPONSE" | jq '.' > "$OUTPUT_FILE"

# Count tickets
TICKET_COUNT=$(echo "$RESPONSE" | jq '.data.issues.nodes | length')

echo "✓ Successfully fetched $TICKET_COUNT triage tickets"
echo "✓ Saved to: $OUTPUT_FILE"

# Display summary
echo ""
echo "Tickets:"
echo "$RESPONSE" | jq -r '.data.issues.nodes[] | "  [\(.identifier)] \(.title)"'
