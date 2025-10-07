#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
TICKETS_FILE="$SCRIPT_DIR/triage-tickets.json"
CONTEXT_FILE="$SCRIPT_DIR/current-ticket-context.md"

# Fetch latest tickets
echo "Fetching latest triage tickets..."
"$SCRIPT_DIR/fetch-linear-tickets.sh"

if [ ! -f "$TICKETS_FILE" ]; then
    echo "Error: No tickets file found. Run fetch-linear-tickets.sh first."
    exit 1
fi

# Check if tickets exist
TICKET_COUNT=$(jq '.data.issues.nodes | length' "$TICKETS_FILE")
if [ "$TICKET_COUNT" -eq 0 ]; then
    echo "No triage tickets found."
    exit 0
fi

echo ""
echo "Available Triage Tickets:"
echo "========================="

# Display tickets with numbers
jq -r '.data.issues.nodes | to_entries[] | "\(.key + 1). [\(.value.identifier)] \(.value.title)\n   Priority: \(.value.priority) | Team: \(.value.team.name)"' "$TICKETS_FILE"

echo ""
read -p "Enter ticket number to analyze (or 'q' to quit): " SELECTION

if [ "$SELECTION" = "q" ]; then
    echo "Exiting..."
    exit 0
fi

# Validate selection
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "$TICKET_COUNT" ]; then
    echo "Invalid selection."
    exit 1
fi

# Get ticket data (array is 0-indexed)
INDEX=$((SELECTION - 1))
TICKET=$(jq ".data.issues.nodes[$INDEX]" "$TICKETS_FILE")

# Extract ticket details
IDENTIFIER=$(echo "$TICKET" | jq -r '.identifier')
TITLE=$(echo "$TICKET" | jq -r '.title')
DESCRIPTION=$(echo "$TICKET" | jq -r '.description // "No description provided"')
URL=$(echo "$TICKET" | jq -r '.url')
PRIORITY=$(echo "$TICKET" | jq -r '.priority')
TEAM=$(echo "$TICKET" | jq -r '.team.name')
STATE=$(echo "$TICKET" | jq -r '.state.name')

# Create context file
cat > "$CONTEXT_FILE" << EOF
# Linear Ticket Analysis

## Ticket: $IDENTIFIER - $TITLE

**URL:** $URL
**Team:** $TEAM
**State:** $STATE
**Priority:** $PRIORITY

---

## Description

$DESCRIPTION

---

## Task

Please analyze this ticket and provide:

1. **Problem Summary**: Brief overview of the issue
2. **Potential Root Causes**: What might be causing this issue
3. **Proposed Solution**: Recommended approach to solve this
4. **Implementation Steps**: High-level steps to implement the solution
5. **Testing Considerations**: What should be tested
6. **Potential Risks**: Any concerns or edge cases

EOF

echo ""
echo "✓ Ticket context saved to: $CONTEXT_FILE"
echo ""
echo "You can now ask Claude Code to analyze this ticket:"
echo "  'Analyze the ticket in $CONTEXT_FILE and provide a solution'"
echo ""
echo "Or open the file directly:"
echo "  cat $CONTEXT_FILE"
