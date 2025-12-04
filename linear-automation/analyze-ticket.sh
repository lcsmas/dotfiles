#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
TICKETS_FILE="$SCRIPT_DIR/helptech-tickets.json"

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
    echo "No helptech tickets found."
    exit 0
fi

echo ""
echo "Available HelpTech Tickets:"
echo "========================="

# Display tickets with numbers
jq -r '.data.issues.nodes | to_entries[] |
  (if .value.priority >= 4 then "\u001b[41mPriority: \(.value.priority)\u001b[0m" else "Priority: \(.value.priority)" end) as $priority |
  (if .value.state.name == "In Progress" then "\u001b[48;5;28m\(.value.state.name)\u001b[0m" elif .value.state.name == "Triage" then "\u001b[43m\u001b[30m\(.value.state.name)\u001b[0m" else "\(.value.state.name)" end) as $state |
  (.value.labels.nodes | map(
    if .name == "B2C" then "\u001b[44m\u001b[30m\(.name)\u001b[0m"
    elif .name == "B2B Cleaq" then "\u001b[45m\u001b[30m\(.name)\u001b[0m"
    elif .name == "B2B Mobile Club" then "\u001b[46m\u001b[30m\(.name)\u001b[0m"
    elif .name == "Other" then "\u001b[47m\u001b[30m\(.name)\u001b[0m"
    elif .name == "Bug" then "\u001b[100m\(.name)\u001b[0m"
    else .name
    end
  ) | join(" ")) as $labels |
  (if .value.assignee.name then "\u001b[36m\(.value.assignee.name)\u001b[0m" else "\u001b[33mNo assignee\u001b[0m" end) as $assignee |
  "\(.key + 1) | [\(.value.identifier)] \(.value.title) | \($priority) | \($state) | \($labels) | \($assignee)"
' "$TICKETS_FILE" | column -t -s '|'

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

# Create context prompt
PROMPT="Solve this HelpTech ticket: 

[$IDENTIFIER] $TITLE

**URL:** $URL
**Priority:** $PRIORITY
**State:** $STATE

## Description

$DESCRIPTION

---

**IMPORTANT:** Follow the HelpTech guidelines in ~/.claude/CLAUDE.md. Always try to replicate the bug before attempting a fix."

echo ""
echo "✓ Starting Claude Code to solve ticket $IDENTIFIER..."
echo ""

# Change to workspace directory and launch Claude Code with the prompt in planning mode
cd /home/lmas/dev/workspace
claude --permission-mode plan "$PROMPT"
