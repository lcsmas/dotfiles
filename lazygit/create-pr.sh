#!/bin/zsh

gh pr create --title "$(git log -1 --pretty=%s)" --body "" 

DATA=$(gh pr view --json url,title -q '.title + "|" + .url')
echo "$DATA"

TITLE=$(echo "$DATA" | cut -d'|' -f1)
URL=$(echo "$DATA" | cut -d'|' -f2)

echo "[$TITLE]($URL)" | wl-copy

xdg-open $URL

echo "Markdown link copied: [$TITLE]($URL)"

