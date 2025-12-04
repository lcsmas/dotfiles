#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
DB_FILE="$SCRIPT_DIR/solved-tickets-database.json"

if [ ! -f "$DB_FILE" ]; then
    echo "Error: Solutions database not found at $DB_FILE"
    echo "Run ./fetch-solved-tickets.sh first to build the database."
    exit 1
fi

get_tickets_list() {
    jq -r '
        .data.issues.nodes
        | to_entries[]
        | "\(.key):::[\(.value.identifier)] \(.value.title)"
    ' "$DB_FILE"
}

show_ticket() {
    local INDEX=$1
    local TICKET=$(jq ".data.issues.nodes[$INDEX]" "$DB_FILE")

    if [ "$TICKET" = "null" ]; then
        echo "Error: Invalid ticket index"
        return 1
    fi

    local IDENTIFIER=$(echo "$TICKET" | jq -r '.identifier')
    local TITLE=$(echo "$TICKET" | jq -r '.title')
    local DESCRIPTION=$(echo "$TICKET" | jq -r '.description // "No description"')
    local URL=$(echo "$TICKET" | jq -r '.url')
    local STATE=$(echo "$TICKET" | jq -r '.state.name')
    local COMPLETED=$(echo "$TICKET" | jq -r '.completedAt // "N/A" | split("T")[0]')
    local LABELS=$(echo "$TICKET" | jq -r '.labels.nodes | map(.name) | join(", ")')
    local ASSIGNEE=$(echo "$TICKET" | jq -r '.assignee.name // "Unassigned"')
    local COMMENT_COUNT=$(echo "$TICKET" | jq '.comments.nodes | length')

    echo "════════════════════════════════════════════════════════════════"
    echo -e "\033[1m[$IDENTIFIER] $TITLE\033[0m"
    echo "════════════════════════════════════════════════════════════════"
    echo "URL:        $URL"
    echo "State:      $STATE"
    echo "Completed:  $COMPLETED"
    echo "Labels:     $LABELS"
    echo "Assignee:   $ASSIGNEE"
    echo "Comments:   $COMMENT_COUNT"
    echo ""
    echo "─── Description ───"
    echo "$DESCRIPTION"
    echo ""

    if [ "$COMMENT_COUNT" -gt 0 ]; then
        echo "─── Comments & Solution ───"
        echo "$TICKET" | jq -r '
            .comments.nodes[]
            | (.user.name // .externalUser.name // .botActor.name // "Unknown User") as $author
            | "[\(.createdAt | split("T")[0])] \($author):\n\(.body)\n"
        '
    else
        echo "No comments found."
    fi

    echo "════════════════════════════════════════════════════════════════"
}

search_tickets() {
    local QUERY="$1"

    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is not installed. Please install fzf for fuzzy finding."
        exit 1
    fi

    local TICKETS=$(get_tickets_list)

    local SELECTED=$(echo "$TICKETS" | fzf \
        --reverse \
        --delimiter=":::" \
        --with-nth=2 \
        --preview="$0 --preview {1}" \
        --preview-window=right:60%:wrap \
        --query="$QUERY" \
        --height=100% \
        --border \
        --prompt="Search solved HelpTech: " \
        --pointer="▶" \
        --marker="✓" \
        --color="header:italic:underline")

    if [ -n "$SELECTED" ]; then
        local INDEX=$(echo "$SELECTED" | cut -d':' -f1)
        echo ""
        show_ticket "$INDEX"
    fi
}

if [ "$1" = "--preview" ]; then
    # Internal option used by fzf preview window
    if [ -z "$2" ]; then
        exit 1
    fi
    show_ticket "$2"

elif [ "$1" = "--filter-json" ]; then
    if [ -z "$2" ]; then
        echo "Error: --filter-json requires a search query"
        exit 1
    fi

    FILTERED=$(get_tickets_list | fzf --filter="$2" --delimiter=":::" --with-nth=2)

    if [ -z "$FILTERED" ]; then
        echo "[]"
        exit 0
    fi

    echo "$FILTERED" | while IFS= read -r line; do
        INDEX=$(echo "$line" | cut -d':' -f1)
        jq ".data.issues.nodes[$INDEX] | {
            identifier: .identifier,
            title: .title,
            description: .description,
            comments: [.comments.nodes[] | select(.user != null or .externalUser != null) | {
                author: (.user.name // .externalUser.name // \"Unknown User\"),
                body: .body
            }]
        }" "$DB_FILE"
    done | jq -s '.';

elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [options] [search_query]"
    echo ""
    echo "Search and view solved HelpTech tickets."
    echo ""
    echo "Options:"
    echo "  (no args)              Browse all tickets interactively"
    echo "  <query>                Search tickets interactively with initial query"
    echo "  --filter-json <query>  Non-interactive fuzzy search (returns JSON)"
    echo "  --help, -h             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                          # Browse all tickets"
    echo "  $0 invoice                  # Interactive search with query"
    echo "  $0 --filter-json invoice    # Get matching tickets as JSON"
else
    search_tickets "$1"
fi
