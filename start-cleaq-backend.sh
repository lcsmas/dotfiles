#!/bin/bash

if tmux list-windows -F "#W" | grep -q "api-run"; then
  tmux kill-window -t api-run
fi

tmux neww -n api-run -c ~/dev/cleaq/backend-dev-env/ "docker compose up"

echo -n "Waiting for mongo1 to accept connection."
until docker exec -t mongo1 mongosh --quiet --eval "db.serverStatus()" > /dev/null 2>&1; do
    sleep 1; echo -n "." 
done
echo

tmux splitw -c ~/dev/cleaq/backend-api/ -v "./gradlew :management:bootRun --args='--spring.profiles.active=local,custom' --continuous; zsh -i"
tmux splitw -c ~/dev/cleaq/backend-api/ -h "./gradlew :order:bootRun --args='--spring.profiles.active=local,custom' --continuous; zsh -i"
