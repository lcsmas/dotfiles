#!/usr/bin/env bash

cd ~/dev/workspace/
git fetch
SINCE="$(date +'%Y-%m-%d') 00:00:00"
RELEASE_TODAY_COUNT="$(git rev-list --count --grep 'Release' --since="$SINCE" origin/master)"
TITLE="🚀 Release $(date +'%d/%m/%Y') #$((RELEASE_TODAY_COUNT+1))"
BODY="$(git rev-list --cherry-pick --oneline --merges origin/master..origin/develop)"

if [[ $BODY == "" ]]; then
  printf "Nothing to release. Aborting. \n"
  exit 0;
fi


URL=$(gh pr create -a "@me" -B "master" -H "develop" -r "mobile-club/devs" --title "$TITLE" --body "$BODY")

xdg-open $URL

printf "%b" "PR created: $URL\n"

printf "%b" "[$TITLE]($URL)\n$BODY" | wl-copy
